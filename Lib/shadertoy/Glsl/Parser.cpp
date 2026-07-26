#include "Parser.h"

#include "Lexer.h"

#include <cstdlib>

namespace Shadertoy::Glsl
{
namespace
{
bool isTypeName(std::string_view text)
{
    return text == "void" || text == "float" || text == "vec2" || text == "vec3"
           || text == "vec4" || text == "int" || text == "uint" || text == "bool"
           || text == "ivec2" || text == "ivec3" || text == "ivec4"
           || text == "bvec2" || text == "bvec3" || text == "bvec4" || text == "mat2"
           || text == "mat3" || text == "mat4" || text == "sampler2D"
           || text == "samplerCube";
}

// The keywords that open a construct with a body. `for` is parsed properly now
// that it can be unrolled; the rest are still skipped and reported.
bool isControlFlowKeyword(std::string_view text)
{
    return text == "if" || text == "while" || text == "do" || text == "switch";
}

// The assignment operators, with the arithmetic ones carrying the operator the
// emitter rewrites them into: `col += x` becomes `col = col + (x)`.
std::string compoundOperator(std::string_view text)
{
    if (text == "+=")
        return "+";
    if (text == "-=")
        return "-";
    if (text == "*=")
        return "*";
    if (text == "/=")
        return "/";

    return {};
}

bool isAssignmentOperator(std::string_view text)
{
    return text == "=" || !compoundOperator(text).empty();
}

class Parser
{
public:
    Parser(Vector<Token> tokensToUse, Vector<Diagnostic> lexerDiagnostics)
        : tokens(std::move(tokensToUse))
        , diagnostics(std::move(lexerDiagnostics))
    {
    }

    ParseResult run()
    {
        parseTranslationUnit();

        auto result = ParseResult {};
        result.shader = std::move(shader);
        result.diagnostics = std::move(diagnostics);
        return result;
    }

private:
    const Token& peek(int ahead = 0) const
    {
        auto wanted = position + ahead;
        return wanted < tokens.size() ? tokens[wanted] : tokens[tokens.size() - 1];
    }

    const Token& advance()
    {
        const auto& token = peek();

        if (position < tokens.size() - 1)
            ++position;

        return token;
    }

    bool check(std::string_view text) const { return peek().is(text); }

    bool match(std::string_view text)
    {
        if (!check(text))
            return false;

        advance();
        return true;
    }

    void expect(std::string_view text)
    {
        if (!match(text))
            report(DiagnosticKind::ParseError,
                   "expected '" + std::string(text) + "', found '" + peek().text
                       + "'");
    }

    void report(DiagnosticKind kind, std::string detail)
    {
        report(kind, std::move(detail), peek().line);
    }

    void report(DiagnosticKind kind, std::string detail, int line)
    {
        diagnostics.add({kind, std::move(detail), line});
    }

    // --- expressions -----------------------------------------------------

    int parseExpression() { return parseTernary(); }

    int parseTernary()
    {
        auto condition = parseBinary(0);

        if (!match("?"))
            return condition;

        auto whenTrue = parseTernary();
        expect(":");
        auto whenFalse = parseTernary();

        auto node = Expr {ExprKind::Ternary, "?:"};
        node.args.add(condition);
        node.args.add(whenTrue);
        node.args.add(whenFalse);
        return shader.add(std::move(node));
    }

    // GLSL's binary levels, loosest first. One table drives the whole climb, so
    // adding an operator is a table entry rather than another function.
    static const Vector<Vector<std::string>>& binaryLevels()
    {
        static const auto levels = Vector<Vector<std::string>> {
            {"||"},
            {"&&"},
            {"^^"},
            {"|"},
            {"^"},
            {"&"},
            {"==", "!="},
            {"<", ">", "<=", ">="},
            {"+", "-"},
            {"*", "/", "%"},
        };

        return levels;
    }

    int parseBinary(int level)
    {
        const auto& levels = binaryLevels();

        if (level >= levels.size())
            return parseUnary();

        auto left = parseBinary(level + 1);

        while (true)
        {
            auto matched = std::string {};

            for (const auto& candidate: levels[level])
                if (check(candidate))
                    matched = candidate;

            if (matched.empty())
                return left;

            advance();
            auto right = parseBinary(level + 1);

            auto node = Expr {ExprKind::Binary, matched};
            node.args.add(left);
            node.args.add(right);
            left = shader.add(std::move(node));
        }
    }

    int parseUnary()
    {
        for (auto op: {"-", "+", "!", "~"})
        {
            if (!check(op))
                continue;

            advance();
            auto operand = parseUnary();

            auto node = Expr {ExprKind::Unary, op};
            node.args.add(operand);
            return shader.add(std::move(node));
        }

        return parsePostfix();
    }

    int parsePostfix()
    {
        auto value = parsePrimary();

        while (true)
        {
            if (match("."))
            {
                auto node = Expr {ExprKind::Member, advance().text};
                node.args.add(value);
                value = shader.add(std::move(node));
                continue;
            }

            if (match("["))
            {
                auto index = parseExpression();
                expect("]");

                auto node = Expr {ExprKind::Index, "[]"};
                node.args.add(value);
                node.args.add(index);
                value = shader.add(std::move(node));
                continue;
            }

            return value;
        }
    }

    int parsePrimary()
    {
        auto token = peek();

        if (token.type == TokenType::Number)
        {
            advance();

            auto node = Expr {ExprKind::Number, token.text};
            node.value = std::strtod(token.text.c_str(), nullptr);
            return shader.add(std::move(node));
        }

        if (token.isIdentifier())
        {
            advance();

            if (!match("("))
                return shader.add(Expr {ExprKind::Identifier, token.text});

            auto node = Expr {ExprKind::Call, token.text};

            if (!check(")"))
            {
                do
                {
                    node.args.add(parseExpression());
                } while (match(","));
            }

            expect(")");
            return shader.add(std::move(node));
        }

        if (match("("))
        {
            auto inner = parseExpression();
            expect(")");
            return inner;
        }

        report(DiagnosticKind::ParseError, "unexpected '" + token.text + "'");
        advance();
        return shader.add(Expr {ExprKind::Number, "0.0"});
    }

    int literalOne()
    {
        auto node = Expr {ExprKind::Number, "1"};
        node.value = 1.0;
        return shader.add(std::move(node));
    }

    // --- recovery --------------------------------------------------------

    // What is skipped still counts. A `break` inside an `if` is a second thing
    // the EDSL is missing rather than a detail of the first, and the report
    // ranks stage 5's work by how many shaders need each of them.
    void noteJump()
    {
        if (check("break") || check("continue") || check("discard"))
            report(DiagnosticKind::ControlFlow, peek().text);
    }

    void skipBalanced(std::string_view open, std::string_view close)
    {
        if (!match(open))
            return;

        auto depth = 1;

        while (depth > 0 && !peek().isEnd())
        {
            if (check(open))
                ++depth;
            else if (check(close))
                --depth;
            else
                noteJump();

            advance();
        }
    }

    void skipToSemicolon()
    {
        while (!peek().isEnd() && !check(";") && !check("}"))
        {
            if (check("("))
            {
                skipBalanced("(", ")");
                continue;
            }

            noteJump();
            advance();
        }

        match(";");
    }

    // Steps over one whole statement without recording it, so parsing resumes
    // cleanly after a construct that cannot be lowered yet.
    void skipStatement()
    {
        if (check("{"))
        {
            skipBalanced("{", "}");
            return;
        }

        skipToSemicolon();
    }

    void skipControlFlow()
    {
        auto keyword = advance().text;

        if (check("("))
            skipBalanced("(", ")");

        skipStatement();

        if (keyword == "do")
        {
            if (match("while"))
                skipBalanced("(", ")");

            match(";");
            return;
        }

        while (match("else"))
        {
            if (check("if"))
            {
                advance();

                if (check("("))
                    skipBalanced("(", ")");
            }

            skipStatement();
        }
    }

    // --- statements ------------------------------------------------------

    // `int` and `uint` are deliberately silent here. A loop counter is the
    // overwhelming majority of them and it becomes a literal the moment the loop
    // unrolls, so reporting the type at the parse would fill the coverage table
    // with gaps that lowering closes on its own; the ones that survive are
    // reported there instead.
    void parseDeclaration(Vector<Statement>& into)
    {
        match("const");

        auto type = advance().text;

        if (type == "bool" || type.rfind("ivec", 0) == 0
            || type.rfind("bvec", 0) == 0)
            report(DiagnosticKind::UnsupportedType, type);

        do
        {
            if (!peek().isIdentifier())
            {
                report(DiagnosticKind::ParseError,
                       "expected a name after '" + type + "'");
                skipToSemicolon();
                return;
            }

            auto statement = Statement {StatementKind::Declare};
            statement.type = type;
            statement.line = peek().line;
            statement.name = advance().text;

            if (check("["))
            {
                report(DiagnosticKind::UnsupportedType, "array");
                skipToSemicolon();
                return;
            }

            if (match("="))
                statement.value = parseExpression();

            into.add(std::move(statement));
        } while (match(","));

        expect(";");
    }

    bool startsDeclaration() const
    {
        return check("const") || (isTypeName(peek().text) && peek(1).isIdentifier());
    }

    // An assignment, an increment, or a call standing on its own. Shared with
    // the clauses of a `for` header, which are the same statements without the
    // trailing semicolon.
    void parseSimpleStatement(Vector<Statement>& into, bool expectSemicolon)
    {
        auto line = peek().line;

        for (auto prefix: {"++", "--"})
        {
            if (!check(prefix))
                continue;

            advance();
            auto target = parsePostfix();
            addIncrement(into, target, prefix[0] == '+' ? "+" : "-", line);

            if (expectSemicolon)
                expect(";");

            return;
        }

        auto target = parsePostfix();

        for (auto postfix: {"++", "--"})
        {
            if (!check(postfix))
                continue;

            advance();
            addIncrement(into, target, postfix[0] == '+' ? "+" : "-", line);

            if (expectSemicolon)
                expect(";");

            return;
        }

        if (isAssignmentOperator(peek().text))
        {
            auto op = compoundOperator(advance().text);
            auto value = parseExpression();

            if (expectSemicolon)
                expect(";");

            addAssignment(into, target, op, value, line);
            return;
        }

        // A call with its result discarded: a helper that writes through an out
        // parameter, which lowering inlines the same way as any other.
        if (shader.expr(target).kind == ExprKind::Call)
        {
            auto statement = Statement {StatementKind::Call};
            statement.name = shader.expr(target).text;
            statement.value = target;
            statement.line = line;
            into.add(std::move(statement));

            if (expectSemicolon)
                expect(";");

            return;
        }

        report(DiagnosticKind::ParseError,
               "expression statement '" + peek().text + "'",
               line);
        skipToSemicolon();
    }

    void addIncrement(Vector<Statement>& into,
                      int target,
                      const std::string& op,
                      int line)
    {
        addAssignment(into, target, op, literalOne(), line);
    }

    void addAssignment(Vector<Statement>& into,
                       int target,
                       const std::string& op,
                       int value,
                       int line)
    {
        const auto& targetNode = shader.expr(target);

        if (targetNode.kind != ExprKind::Identifier)
        {
            report(DiagnosticKind::ComponentAssignment,
                   targetNode.kind == ExprKind::Member ? "." + targetNode.text
                                                       : "indexed target",
                   line);

            auto dropped = Statement {StatementKind::Unsupported, "component"};
            dropped.line = line;
            into.add(std::move(dropped));
            return;
        }

        auto statement = Statement {StatementKind::Assign};
        statement.name = targetNode.text;
        statement.op = op;
        statement.value = value;
        statement.line = line;
        into.add(std::move(statement));
    }

    void parseFor(Vector<Statement>& into)
    {
        auto statement = Statement {StatementKind::For};
        statement.line = peek().line;

        advance(); // 'for'
        expect("(");

        auto init = Block {};

        if (!match(";"))
        {
            if (startsDeclaration())
                parseDeclaration(init.statements);
            else
                parseSimpleStatement(init.statements, true);
        }

        statement.init = shader.add(std::move(init));

        if (!check(";"))
            statement.condition = parseExpression();

        expect(";");

        auto step = Block {};

        if (!check(")"))
        {
            do
            {
                parseSimpleStatement(step.statements, false);
            } while (match(","));
        }

        statement.step = shader.add(std::move(step));
        expect(")");

        statement.body = parseBody();
        into.add(std::move(statement));
    }

    // A brace-delimited block, or the single statement a loop header is allowed
    // to stand in for.
    int parseBody()
    {
        auto block = Block {};

        if (match("{"))
        {
            while (!check("}") && !peek().isEnd())
                parseStatement(block.statements);

            expect("}");
        }
        else
        {
            parseStatement(block.statements);
        }

        return shader.add(std::move(block));
    }

    void parseStatement(Vector<Statement>& into)
    {
        if (peek().isEnd())
            return;

        if (match(";"))
            return;

        if (check("{"))
        {
            // A bare block introduces a scope GLSL uses for shadowing; for
            // straight-line code its statements belong to the enclosing body.
            advance();

            while (!check("}") && !peek().isEnd())
                parseStatement(into);

            expect("}");
            return;
        }

        if (check("for"))
        {
            parseFor(into);
            return;
        }

        if (isControlFlowKeyword(peek().text) || check("discard"))
        {
            auto statement = Statement {StatementKind::Unsupported, peek().text};
            statement.line = peek().line;
            report(DiagnosticKind::ControlFlow, statement.name);

            if (statement.name == "discard")
            {
                advance();
                skipToSemicolon();
            }
            else
            {
                skipControlFlow();
            }

            into.add(std::move(statement));
            return;
        }

        // Kept rather than reported: whether a jump is a gap depends on the loop
        // around it, which only lowering knows.
        if (check("break") || check("continue"))
        {
            auto statement = Statement {check("break") ? StatementKind::Break
                                                       : StatementKind::Continue};
            statement.line = peek().line;
            advance();
            skipToSemicolon();
            into.add(std::move(statement));
            return;
        }

        if (check("return"))
        {
            auto line = advance().line;
            auto statement = Statement {StatementKind::Return};
            statement.line = line;

            if (!check(";"))
                statement.value = parseExpression();

            expect(";");
            into.add(std::move(statement));
            return;
        }

        if (startsDeclaration())
        {
            parseDeclaration(into);
            return;
        }

        parseSimpleStatement(into, true);
    }

    // --- top level -------------------------------------------------------

    void parseMainImage()
    {
        shader.hasMainImage = true;
        expect("(");

        auto parameterNames = Vector<std::string> {};

        while (!check(")") && !peek().isEnd())
        {
            match("in");
            match("out");
            match("inout");
            match("const");

            advance(); // the parameter's type

            if (peek().isIdentifier())
                parameterNames.add(advance().text);

            if (!match(","))
                break;
        }

        expect(")");

        if (parameterNames.size() >= 1)
            shader.fragColor = parameterNames[0];

        if (parameterNames.size() >= 2)
            shader.fragCoord = parameterNames[1];

        expect("{");

        while (!check("}") && !peek().isEnd())
            parseStatement(shader.statements);

        expect("}");
    }

    // A helper, kept whole. Lowering inlines it at every call site; what it
    // reports if it cannot is the function's name, which is what the coverage
    // table groups on.
    void parseFunction(std::string returnType, std::string name)
    {
        auto function = Function {};
        function.line = peek().line;
        function.returnType = std::move(returnType);
        function.name = std::move(name);

        expect("(");

        while (!check(")") && !peek().isEnd())
        {
            auto parameter = Parameter {};

            match("const");

            if (check("out") || check("inout"))
            {
                parameter.writesBack = true;
                advance();
            }
            else
            {
                match("in");
            }

            parameter.type = advance().text;

            if (peek().isIdentifier())
                parameter.name = advance().text;

            if (!parameter.name.empty())
                function.parameters.add(std::move(parameter));

            if (!match(","))
                break;
        }

        expect(")");

        if (match(";"))
            return; // a forward declaration says nothing the body will not

        function.body = parseBody();
        shader.functions.add(std::move(function));
    }

    void parseTranslationUnit()
    {
        while (!peek().isEnd())
        {
            if (match(";"))
                continue;

            // A precision qualifier says nothing the generated C++ can act on.
            if (check("precision"))
            {
                skipToSemicolon();
                continue;
            }

            auto isFunction =
                peek().isIdentifier() && peek(1).isIdentifier() && peek(2).is("(");

            if (isFunction)
            {
                auto returnType = advance().text;
                auto name = advance().text;

                if (name == "mainImage")
                    parseMainImage();
                else
                    parseFunction(std::move(returnType), std::move(name));

                continue;
            }

            if (startsDeclaration())
            {
                parseDeclaration(shader.globals);
                continue;
            }

            report(DiagnosticKind::ParseError, "unexpected '" + peek().text + "'");
            skipToSemicolon();
        }

        if (!shader.hasMainImage)
            report(DiagnosticKind::ParseError, "no mainImage function", 0);
    }

    Vector<Token> tokens;
    Vector<Diagnostic> diagnostics;
    Shader shader;
    int position = 0;
};
} // namespace

ParseResult parse(const std::string& source)
{
    auto diagnostics = Vector<Diagnostic> {};
    auto tokens = tokenize(source, diagnostics);

    return Parser {std::move(tokens), std::move(diagnostics)}.run();
}
} // namespace Shadertoy::Glsl
