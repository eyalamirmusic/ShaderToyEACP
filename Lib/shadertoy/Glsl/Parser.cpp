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

bool isControlFlowKeyword(std::string_view text)
{
    return text == "if" || text == "for" || text == "while" || text == "do"
           || text == "switch";
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

        for (const auto& statement: body)
            result.shader.statements.add(statement);

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

    // --- statements ------------------------------------------------------

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

            advance();
        }

        match(";");
    }

    // Skips a function body while still noting what is inside it.
    //
    // A helper cannot be lowered yet, so it is reported as a user function - but
    // what it *contains* decides how much inlining will actually unlock. A
    // helper full of loops needs real control flow too, and a report that
    // stopped at "inline this" would flatter the roadmap: it would promise that
    // stage 2 turns the shader green when stage 5 is also required.
    void skipBodyNotingControlFlow()
    {
        if (!match("{"))
            return;

        auto depth = 1;
        auto reported = Vector<std::string> {};

        while (depth > 0 && !peek().isEnd())
        {
            if (check("{"))
            {
                ++depth;
            }
            else if (check("}"))
            {
                --depth;
            }
            else if (isControlFlowKeyword(peek().text) || check("break")
                     || check("continue") || check("discard"))
            {
                auto keyword = peek().text;
                auto alreadySeen = false;

                for (const auto& seen: reported)
                    if (seen == keyword)
                        alreadySeen = true;

                if (!alreadySeen)
                {
                    reported.add(keyword);
                    report(DiagnosticKind::ControlFlow, keyword);
                }
            }

            advance();
        }
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

    void parseDeclaration(Vector<Statement>& into)
    {
        match("const");

        auto type = advance().text;

        if (type == "int" || type == "bool" || type == "uint"
            || type.rfind("ivec", 0) == 0 || type.rfind("bvec", 0) == 0)
            report(DiagnosticKind::UnsupportedType, type);

        if (type == "mat2" || type == "mat3")
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

    void parseStatement()
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
                parseStatement();

            expect("}");
            return;
        }

        if (isControlFlowKeyword(peek().text))
        {
            report(DiagnosticKind::ControlFlow, peek().text);
            skipControlFlow();
            return;
        }

        for (auto keyword: {"discard", "break", "continue"})
        {
            if (!check(keyword))
                continue;

            report(DiagnosticKind::ControlFlow, keyword);
            skipToSemicolon();
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
            body.add(std::move(statement));
            return;
        }

        if (check("const") || (isTypeName(peek().text) && peek(1).isIdentifier()))
        {
            parseDeclaration(body);
            return;
        }

        parseAssignment();
    }

    void parseAssignment()
    {
        auto line = peek().line;
        auto target = parsePostfix();

        if (!isAssignmentOperator(peek().text))
        {
            report(DiagnosticKind::ParseError,
                   "expression statement '" + peek().text + "'",
                   line);
            skipToSemicolon();
            return;
        }

        auto op = compoundOperator(advance().text);
        auto value = parseExpression();
        expect(";");

        const auto& targetNode = shader.expr(target);

        if (targetNode.kind != ExprKind::Identifier)
        {
            report(DiagnosticKind::ComponentAssignment,
                   targetNode.kind == ExprKind::Member ? "." + targetNode.text
                                                       : "indexed target",
                   line);
            return;
        }

        auto statement = Statement {StatementKind::Assign};
        statement.name = targetNode.text;
        statement.op = op;
        statement.value = value;
        statement.line = line;
        body.add(std::move(statement));
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
            parseStatement();

        expect("}");
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
                advance(); // return type
                auto name = advance().text;

                if (name == "mainImage")
                {
                    parseMainImage();
                    continue;
                }

                report(DiagnosticKind::UserFunction, name);
                skipBalanced("(", ")");

                if (check("{"))
                    skipBodyNotingControlFlow();
                else
                    match(";");

                continue;
            }

            if (check("const")
                || (isTypeName(peek().text) && peek(1).isIdentifier()))
            {
                parseDeclaration(globals);
                continue;
            }

            report(DiagnosticKind::ParseError, "unexpected '" + peek().text + "'");
            skipToSemicolon();
        }

        if (!shader.hasMainImage)
            report(DiagnosticKind::ParseError, "no mainImage function", 0);

        // Globals lead, whatever order they appeared in relative to mainImage:
        // a const the body reads has to be in scope by the time it is read.
        for (const auto& global: globals)
            shader.statements.add(global);
    }

    Vector<Token> tokens;
    Vector<Diagnostic> diagnostics;
    Shader shader;
    Vector<Statement> globals;
    Vector<Statement> body;
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
