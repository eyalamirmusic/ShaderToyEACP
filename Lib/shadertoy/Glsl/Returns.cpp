#include "Returns.h"

#include <set>

namespace Shadertoy::Glsl
{
namespace
{
// The two locals a rewritten body runs on: what it is leaving with, and whether
// it has left. The second is only ever declared where something reads it, which
// for a guard clause is nowhere.
struct Exit
{
    std::string result; // empty for a body that returns nothing
    std::string returned;
};

// What the rewrite has to know about where a statement sits. A `break` reaches
// the end of the enclosing loop, which is where a return inside one wants to
// go; and a return whose flag nothing tests need not set it.
struct Place
{
    bool inLoop = false;
    bool flagRead = false;
};

class Rewriter
{
public:
    explicit Rewriter(Shader& toRewrite)
        : shader(toRewrite)
    {
        collectNames();
    }

    void run()
    {
        for (auto& function: shader.functions)
        {
            if (function.body < 0)
                continue;

            auto body = shader.block(function.body).statements;
            auto isVoid = function.returnType == "void";

            if (!needsRewrite(body, isVoid))
                continue;

            auto rewritten = rewriteBody(body, function.returnType, function.name);
            shader.blocks[function.body].statements = std::move(rewritten);
        }

        if (needsRewrite(shader.statements, true))
            shader.statements = rewriteBody(shader.statements, "void", {});
    }

private:
    // --- what a body does ---------------------------------------------------

    bool exits(const Statement& statement) const
    {
        return statement.kind == StatementKind::Return || exits(statement.init)
               || exits(statement.step) || exits(statement.body)
               || exits(statement.elseBody);
    }

    bool exits(int block) const
    {
        if (block < 0)
            return false;

        for (const auto& statement: shader.block(block).statements)
            if (exits(statement))
                return true;

        return false;
    }

    // Whether every path through a block leaves the body. This is what lets a
    // guard clause keep its shape: the code after one runs precisely when the
    // guard did not fire, which is an `else`.
    //
    // A loop never answers yes, however it is written. What it takes to know
    // that one always runs its body is what it takes to know how long it runs
    // for, and nothing here works that out.
    bool alwaysExits(const Vector<Statement>& statements) const
    {
        for (const auto& statement: statements)
        {
            if (statement.kind == StatementKind::Return)
                return true;

            if (statement.kind == StatementKind::If && statement.elseBody >= 0
                && alwaysExits(statement.body) && alwaysExits(statement.elseBody))
                return true;
        }

        return false;
    }

    bool alwaysExits(int block) const
    {
        return block >= 0 && alwaysExits(shader.block(block).statements);
    }

    // A return inside a loop becomes a `break`, which leaves that loop and no
    // more - so a loop with one nested inside it has to be told separately.
    bool exitsInNestedLoop(const Vector<Statement>& statements) const
    {
        for (const auto& statement: statements)
        {
            auto isLoop = statement.kind == StatementKind::For
                          || statement.kind == StatementKind::While;

            if (isLoop && exits(statement))
                return true;

            if (statement.kind != StatementKind::If)
                continue;

            if (exitsInNestedLoop(statement.body)
                || exitsInNestedLoop(statement.elseBody))
                return true;
        }

        return false;
    }

    bool exitsInNestedLoop(int block) const
    {
        return block >= 0 && exitsInNestedLoop(shader.block(block).statements);
    }

    // A body already in the shape the port wants is left alone: one return, as
    // its last statement. A body returning nothing has no use for even that.
    bool needsRewrite(const Vector<Statement>& statements, bool isVoid) const
    {
        for (auto index = 0; index < statements.size(); ++index)
        {
            const auto& statement = statements[index];

            if (statement.kind == StatementKind::Return)
            {
                if (isVoid || index + 1 != statements.size())
                    return true;

                continue;
            }

            if (exits(statement))
                return true;
        }

        return false;
    }

    // --- the rewrite --------------------------------------------------------

    Vector<Statement> rewriteBody(const Vector<Statement>& body,
                                  const std::string& returnType,
                                  const std::string& name)
    {
        auto line = body.empty() ? 0 : body.front().line;

        exit.result =
            returnType == "void" ? std::string {} : unique(name + "Result");
        exit.returned = unique(name.empty() ? "returned" : name + "Returned");
        usesFlag = false;

        auto rewritten = rewrite(body, Place {});
        auto out = Vector<Statement> {};

        if (!exit.result.empty())
        {
            auto declaration =
                Statement {StatementKind::Declare, exit.result, returnType};
            declaration.line = line;
            out.add(std::move(declaration));
        }

        if (usesFlag)
        {
            auto declaration =
                Statement {StatementKind::Declare, exit.returned, "bool"};
            declaration.value = identifier("false");
            declaration.line = line;
            out.add(std::move(declaration));
        }

        for (auto& statement: rewritten)
            out.add(std::move(statement));

        if (!exit.result.empty())
        {
            auto result = Statement {StatementKind::Return};
            result.value = identifier(exit.result);
            result.line = line;
            out.add(std::move(result));
        }

        return out;
    }

    Vector<Statement> rewrite(const Vector<Statement>& statements, Place place)
    {
        auto out = Vector<Statement> {};

        for (auto index = 0; index < statements.size(); ++index)
        {
            const auto& statement = statements[index];

            // Whatever followed a return never ran, so the rewrite keeps none
            // of it: dropping it here is what stops it needing a guard.
            if (statement.kind == StatementKind::Return)
            {
                addExit(statement, place, out);
                return out;
            }

            if (!exits(statement))
            {
                out.add(statement);
                continue;
            }

            auto rest = after(statements, index + 1);

            if (statement.kind == StatementKind::If
                && hoisted(statement, rest, place, out))
                return out;

            auto inside = place;
            inside.flagRead = place.flagRead || !rest.empty();

            out.add(rewritten(statement, inside));

            if (rest.empty())
                return out;

            usesFlag = true;
            out.add(guard(rewrite(rest, place), statement.line));
            return out;
        }

        return out;
    }

    // A branch one side of which always leaves takes the rest of the block into
    // the other side, which is the `else` a guard clause was written as before
    // GLSL let it be left out. Nothing after the branch can then run unasked,
    // so the flag the general form needs is not needed at all.
    bool hoisted(const Statement& statement,
                 const Vector<Statement>& rest,
                 Place place,
                 Vector<Statement>& out)
    {
        auto thenExits = alwaysExits(statement.body);
        auto elseExits = statement.elseBody >= 0 && alwaysExits(statement.elseBody);

        if (rest.empty() || (thenExits && elseExits))
        {
            out.add(rewritten(statement, place));
            return true;
        }

        if (!thenExits && !elseExits)
            return false;

        auto branch = statement;

        if (thenExits)
        {
            branch.body = rewriteBlock(statement.body, place);
            branch.elseBody = rewriteBlock(statement.elseBody, rest, place);
        }
        else
        {
            branch.body = rewriteBlock(statement.body, rest, place);
            branch.elseBody = rewriteBlock(statement.elseBody, place);
        }

        out.add(std::move(branch));
        return true;
    }

    Statement rewritten(const Statement& statement, Place place)
    {
        auto copy = statement;

        if (statement.kind == StatementKind::If)
        {
            copy.body = rewriteBlock(statement.body, place);
            copy.elseBody = rewriteBlock(statement.elseBody, place);
            return copy;
        }

        if (statement.kind == StatementKind::For
            || statement.kind == StatementKind::While)
            copy.body = rewriteLoopBody(statement.body, place, statement.line);

        return copy;
    }

    int rewriteLoopBody(int block, Place place, int line)
    {
        if (block < 0)
            return -1;

        auto statements = shader.block(block).statements;
        auto nested = exitsInNestedLoop(statements);

        auto inside = Place {true, place.flagRead || nested};
        auto body = rewrite(statements, inside);

        if (nested)
        {
            usesFlag = true;
            body.add(breakWhenReturned(line));
        }

        return shader.add(Block {std::move(body)});
    }

    int rewriteBlock(int block, Place place)
    {
        if (block < 0)
            return -1;

        auto statements = shader.block(block).statements;
        return shader.add(Block {rewrite(statements, place)});
    }

    int rewriteBlock(int block, const Vector<Statement>& rest, Place place)
    {
        auto statements =
            block >= 0 ? shader.block(block).statements : Vector<Statement> {};

        for (const auto& statement: rest)
            statements.add(statement);

        return shader.add(Block {rewrite(statements, place)});
    }

    void addExit(const Statement& statement, Place place, Vector<Statement>& out)
    {
        if (!exit.result.empty() && statement.value >= 0)
        {
            auto write = Statement {StatementKind::Assign, exit.result};
            write.value = statement.value;
            write.line = statement.line;
            out.add(std::move(write));
        }

        if (place.flagRead)
        {
            usesFlag = true;

            auto flag = Statement {StatementKind::Assign, exit.returned};
            flag.value = identifier("true");
            flag.line = statement.line;
            out.add(std::move(flag));
        }

        if (place.inLoop)
        {
            auto jump = Statement {StatementKind::Break};
            jump.line = statement.line;
            out.add(std::move(jump));
        }
    }

    Statement guard(Vector<Statement> statements, int line)
    {
        auto negated = Expr {ExprKind::Unary, "!"};
        negated.args.add(identifier(exit.returned));

        auto branch = Statement {StatementKind::If};
        branch.line = line;
        branch.condition = shader.add(std::move(negated));
        branch.body = shader.add(Block {std::move(statements)});
        return branch;
    }

    Statement breakWhenReturned(int line)
    {
        auto jump = Statement {StatementKind::Break};
        jump.line = line;

        auto body = Vector<Statement> {};
        body.add(std::move(jump));

        auto branch = Statement {StatementKind::If};
        branch.line = line;
        branch.condition = identifier(exit.returned);
        branch.body = shader.add(Block {std::move(body)});
        return branch;
    }

    // --- names and nodes ----------------------------------------------------

    static Vector<Statement> after(const Vector<Statement>& statements, int start)
    {
        auto rest = Vector<Statement> {};

        for (auto index = start; index < statements.size(); ++index)
            rest.add(statements[index]);

        return rest;
    }

    int identifier(const std::string& name)
    {
        return shader.add(Expr {ExprKind::Identifier, name});
    }

    // A name the shader cannot also be using. Lowering renames a local it has
    // seen before, but a second declaration of the same name in the same scope
    // rebinds it - so a shader with a local called `result` would have the
    // rewrite writing to that one from the point it appears.
    void collectNames()
    {
        for (const auto& node: shader.nodes)
            used.insert(node.text);

        for (const auto& block: shader.blocks)
            for (const auto& statement: block.statements)
                used.insert(statement.name);

        for (const auto& statement: shader.globals)
            used.insert(statement.name);

        for (const auto& statement: shader.statements)
            used.insert(statement.name);

        for (const auto& function: shader.functions)
        {
            used.insert(function.name);

            for (const auto& parameter: function.parameters)
                used.insert(parameter.name);
        }
    }

    std::string unique(const std::string& base)
    {
        auto candidate = base;
        auto suffix = 1;

        while (!used.insert(candidate).second)
            candidate = base + std::to_string(++suffix);

        return candidate;
    }

    Shader& shader;
    std::set<std::string> used;

    Exit exit;
    bool usesFlag = false;
};
} // namespace

void rewriteEarlyReturns(Shader& shader)
{
    Rewriter {shader}.run();
}
} // namespace Shadertoy::Glsl
