#include "Lower.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <set>

namespace Shadertoy::Glsl
{
namespace
{
// A loop long enough to hit either of these is one the EDSL should be growing
// real control flow for, not one to paper over with a million statements.
constexpr auto maxIterationsPerLoop = 512;
constexpr auto maxIterationsPerShader = 8192;
constexpr auto maxInlineDepth = 16;

// What a source name currently stands for. The node is in the *output* arena:
// a declared local resolves to an identifier, while a loop counter or an
// integer constant resolves straight to the number, which is what lets the rest
// of the pass fold it away.
struct Binding
{
    int node = -1;
    bool isConstant = false;
    double value = 0.0;
};

using Scope = std::map<std::string, Binding>;

// Names the port cannot hand out to a local, because the runtime already has
// something of that name in scope.
constexpr const char* reservedNames[] = {
    "iResolution",
    "iTime",
    "iTimeDelta",
    "iFrame",
    "iMouse",
    "iChannel0",
    "iChannel1",
    "iChannel2",
    "iChannel3",
};

bool isIntegerType(const std::string& type)
{
    return type == "int" || type == "uint";
}

class Lowerer
{
public:
    explicit Lowerer(const Shader& toLower)
        : source(toLower)
    {
    }

    LowerResult run()
    {
        output.fragColor = source.fragColor;
        output.fragCoord = source.fragCoord;
        output.hasMainImage = source.hasMainImage;

        for (auto reserved: reservedNames)
            namesUsed[reserved] = 1;

        namesUsed[source.fragCoord] = 1;

        scopes.add(Scope {});
        lowerInto(source.globals, output.statements);

        scopes.add(Scope {});
        lowerInto(source.statements, output.statements);

        auto result = LowerResult {};
        result.shader = std::move(output);
        result.diagnostics = std::move(diagnostics);
        return result;
    }

private:
    void report(DiagnosticKind kind, std::string detail)
    {
        diagnostics.add({kind, std::move(detail), line});
    }

    // --- names and scopes -------------------------------------------------

    std::string unique(const std::string& base)
    {
        auto& count = namesUsed[base];

        if (++count == 1)
            return base;

        auto candidate = base + "_" + std::to_string(count);

        while (namesUsed.count(candidate) != 0)
            candidate = base + "_" + std::to_string(++count);

        namesUsed[candidate] = 1;
        return candidate;
    }

    Binding* find(const std::string& name)
    {
        for (auto index = scopes.size() - 1; index >= 0; --index)
        {
            auto found = scopes[index].find(name);

            if (found != scopes[index].end())
                return &found->second;
        }

        return nullptr;
    }

    const Binding* find(const std::string& name) const
    {
        return const_cast<Lowerer*>(this)->find(name);
    }

    void bind(const std::string& name, Binding binding)
    {
        scopes.back()[name] = binding;
    }

    // --- output nodes -----------------------------------------------------

    int number(double value)
    {
        auto node = Expr {ExprKind::Number};
        node.value = value;
        return output.add(std::move(node));
    }

    int identifier(std::string name)
    {
        return output.add(Expr {ExprKind::Identifier, std::move(name)});
    }

    int binary(const std::string& op, int left, int right)
    {
        auto node = Expr {ExprKind::Binary, op};
        node.args.add(left);
        node.args.add(right);
        return output.add(std::move(node));
    }

    // --- constant folding -------------------------------------------------

    // Two questions share this walk. Substitution folding - `named` off - only
    // resolves a name that already stands for a number, which is what turns an
    // unrolled counter into a literal while leaving `PI` spelled as PI. Trip
    // counts turn `named` on, so a `const float STEPS = 8.0` bounds a loop too.
    bool fold(int node, double& out, bool named) const
    {
        if (node < 0)
            return false;

        const auto& expr = source.expr(node);

        switch (expr.kind)
        {
            case ExprKind::Number:
                out = expr.value;
                return true;

            case ExprKind::Identifier:
                return foldIdentifier(expr.text, out, named);

            case ExprKind::Unary:
                return foldUnary(expr, out, named);

            case ExprKind::Binary:
                return foldBinary(expr, out, named);

            case ExprKind::Ternary:
            {
                auto condition = 0.0;

                if (!fold(expr.args[0], condition, named))
                    return false;

                return fold(expr.args[condition != 0.0 ? 1 : 2], out, named);
            }

            case ExprKind::Call:
                return foldCall(expr, out, named);

            case ExprKind::Member:
            case ExprKind::Index:
                return false;
        }

        return false;
    }

    bool foldIdentifier(const std::string& name, double& out, bool named) const
    {
        auto substituted = overrides.find(name);

        if (substituted != overrides.end())
        {
            out = substituted->second;
            return true;
        }

        const auto* binding = find(name);

        if (binding == nullptr || binding->node < 0)
            return false;

        if (output.expr(binding->node).kind == ExprKind::Number)
        {
            out = output.expr(binding->node).value;
            return true;
        }

        if (!named || !binding->isConstant)
            return false;

        out = binding->value;
        return true;
    }

    bool foldUnary(const Expr& expr, double& out, bool named) const
    {
        auto operand = 0.0;

        if (!fold(expr.args[0], operand, named))
            return false;

        if (expr.text == "-")
            out = -operand;
        else if (expr.text == "+")
            out = operand;
        else if (expr.text == "!")
            out = operand == 0.0 ? 1.0 : 0.0;
        else
            return false;

        return true;
    }

    bool foldBinary(const Expr& expr, double& out, bool named) const
    {
        auto left = 0.0;
        auto right = 0.0;

        if (!fold(expr.args[0], left, named) || !fold(expr.args[1], right, named))
            return false;

        const auto& op = expr.text;

        if (op == "+")
            out = left + right;
        else if (op == "-")
            out = left - right;
        else if (op == "*")
            out = left * right;
        else if (op == "/" || op == "%")
        {
            if (right == 0.0)
                return false;

            out = op == "/" ? left / right : std::fmod(left, right);
        }
        else if (op == "<")
            out = left < right ? 1.0 : 0.0;
        else if (op == ">")
            out = left > right ? 1.0 : 0.0;
        else if (op == "<=")
            out = left <= right ? 1.0 : 0.0;
        else if (op == ">=")
            out = left >= right ? 1.0 : 0.0;
        else if (op == "==")
            out = left == right ? 1.0 : 0.0;
        else if (op == "!=")
            out = left != right ? 1.0 : 0.0;
        else if (op == "&&")
            out = (left != 0.0 && right != 0.0) ? 1.0 : 0.0;
        else if (op == "||")
            out = (left != 0.0 || right != 0.0) ? 1.0 : 0.0;
        else
            return false;

        return true;
    }

    bool foldCall(const Expr& expr, double& out, bool named) const
    {
        auto arguments = Vector<double> {};

        for (auto arg: expr.args)
        {
            auto value = 0.0;

            if (!fold(arg, value, named))
                return false;

            arguments.add(value);
        }

        const auto& callee = expr.text;

        if (arguments.size() == 1)
        {
            if (callee == "float")
                out = arguments[0];
            else if (callee == "int")
                out = std::trunc(arguments[0]);
            else if (callee == "abs")
                out = std::abs(arguments[0]);
            else if (callee == "floor")
                out = std::floor(arguments[0]);
            else if (callee == "ceil")
                out = std::ceil(arguments[0]);
            else if (callee == "sqrt" && arguments[0] >= 0.0)
                out = std::sqrt(arguments[0]);
            else
                return false;

            return true;
        }

        if (arguments.size() == 2)
        {
            if (callee == "min")
                out = std::min(arguments[0], arguments[1]);
            else if (callee == "max")
                out = std::max(arguments[0], arguments[1]);
            else if (callee == "mod" && arguments[1] != 0.0)
                out = arguments[0]
                      - arguments[1] * std::floor(arguments[0] / arguments[1]);
            else
                return false;

            return true;
        }

        return false;
    }

    // --- expressions ------------------------------------------------------

    int lowerExpression(int node, Vector<Statement>& into)
    {
        if (node < 0)
            return -1;

        const auto& expr = source.expr(node);
        auto folded = 0.0;

        if (expr.kind != ExprKind::Number && fold(node, folded, false))
            return number(folded);

        switch (expr.kind)
        {
            case ExprKind::Number:
                return number(expr.value);

            case ExprKind::Identifier:
            {
                if (const auto* binding = find(expr.text))
                    return binding->node;

                return identifier(expr.text);
            }

            case ExprKind::Call:
                return lowerCall(node, into);

            default:
                break;
        }

        auto copy = Expr {expr.kind, expr.text};
        copy.value = expr.value;

        for (auto arg: expr.args)
            copy.args.add(lowerExpression(arg, into));

        return output.add(std::move(copy));
    }

    int lowerCall(int node, Vector<Statement>& into)
    {
        const auto& expr = source.expr(node);
        const auto* function = source.function(expr.text);

        if (function != nullptr && canInline(*function, expr))
            return expandCall(*function, expr, into, true);

        auto call = Expr {ExprKind::Call, expr.text};

        for (auto arg: expr.args)
            call.args.add(lowerExpression(arg, into));

        auto lowered = output.add(std::move(call));

        if (function != nullptr)
            measureBody(*function, expr);

        return lowered;
    }

    // A helper that will not inline is still a helper, and everything its body
    // needs is a gap the report should know about. Expanding it once into the
    // dropped list is what keeps the table from promising that inlining alone
    // would turn a shader green when its helper marches a loop as well.
    void measureBody(const Function& function, const Expr& call)
    {
        if (function.body < 0 || function.parameters.size() != call.args.size())
            return;

        if (inlining.contains(function.name) || inlining.size() >= maxInlineDepth)
            return;

        if (!measured.insert(function.name).second)
            return;

        expandCall(function, call, output.dropped, false);
    }

    // --- inlining ---------------------------------------------------------

    // Whether a statement stands between a helper and being inlined, or a loop
    // and being unrolled. Nested bodies count: a loop whose body holds a jump
    // cannot be unrolled either, and refusing the whole nest at once is what
    // keeps one gap from being reported once per copy.
    bool blocksFlattening(const Statement& statement) const
    {
        switch (statement.kind)
        {
            case StatementKind::Unsupported:
            case StatementKind::Break:
            case StatementKind::Continue:
            case StatementKind::Return:
                return true;

            case StatementKind::For:
                return blocksFlattening(statement.init)
                       || blocksFlattening(statement.step)
                       || blocksFlattening(statement.body);

            default:
                return false;
        }
    }

    bool blocksFlattening(int block) const
    {
        if (block < 0)
            return false;

        for (const auto& statement: source.block(block).statements)
            if (blocksFlattening(statement))
                return true;

        return false;
    }

    bool assignsTo(int block, const std::string& name) const
    {
        if (block < 0)
            return false;

        for (const auto& statement: source.block(block).statements)
        {
            auto writes = statement.kind == StatementKind::Assign
                          || statement.kind == StatementKind::Declare;

            if (writes && statement.name == name)
                return true;

            if (statement.kind == StatementKind::For
                && (assignsTo(statement.init, name)
                    || assignsTo(statement.step, name)
                    || assignsTo(statement.body, name)))
                return true;
        }

        return false;
    }

    bool canInline(const Function& function, const Expr& call) const
    {
        if (function.body < 0 || function.parameters.size() != call.args.size())
            return false;

        if (inlining.contains(function.name) || inlining.size() >= maxInlineDepth)
            return false;

        for (auto index = 0; index < function.parameters.size(); ++index)
        {
            if (!function.parameters[index].writesBack)
                continue;

            // Writing back through an out parameter means assigning to what the
            // caller passed, so it has to be something assignable.
            const auto& argument = source.expr(call.args[index]);

            if (argument.kind != ExprKind::Identifier)
                return false;

            const auto* target = find(argument.text);

            if (target == nullptr || target->node < 0
                || output.expr(target->node).kind != ExprKind::Identifier)
                return false;
        }

        const auto& statements = source.block(function.body).statements;
        auto terminator = terminatorOf(function);

        if (function.returnType != "void" && terminator < 0)
            return false;

        for (auto index = 0; index < statements.size(); ++index)
            if (index != terminator && blocksFlattening(statements[index]))
                return false;

        return true;
    }

    // The trailing `return`, which is the only place one can stand and still be
    // inlinable: anything earlier is a branch the EDSL cannot take yet.
    int terminatorOf(const Function& function) const
    {
        const auto& statements = source.block(function.body).statements;

        if (statements.empty() || statements.back().kind != StatementKind::Return)
            return -1;

        return statements.size() - 1;
    }

    int expandCall(const Function& function,
                   const Expr& call,
                   Vector<Statement>& into,
                   bool keepResults)
    {
        auto incoming = Vector<Binding> {};

        for (auto index = 0; index < call.args.size(); ++index)
            incoming.add(argumentBinding(call.args[index], into));

        // The body sees the globals and its own parameters, and nothing the
        // caller happens to have in scope.
        auto callerScopes = std::move(scopes);
        scopes = Vector<Scope> {};
        scopes.add(callerScopes[0]);
        scopes.add(Scope {});

        for (auto index = 0; index < function.parameters.size(); ++index)
            bindParameter(function, index, incoming[index], into);

        const auto& statements = source.block(function.body).statements;
        auto terminator = terminatorOf(function);

        inlining.add(function.name);

        for (auto index = 0; index < statements.size(); ++index)
            if (index != terminator)
                lowerStatement(statements[index], into);

        auto result = -1;

        if (terminator >= 0)
            result = lowerExpression(statements[terminator].value, into);

        // Nothing consumes the result of a body expanded only to be measured,
        // so it is kept as a statement of its own: what a helper returns is
        // usually where its gaps are.
        if (!keepResults && result >= 0)
        {
            auto measurement = Statement {StatementKind::Return};
            measurement.value = result;
            measurement.line = line;
            into.add(std::move(measurement));
        }

        inlining.pop_back();

        auto finals = Vector<Binding> {};

        for (const auto& parameter: function.parameters)
            finals.add(*find(parameter.name));

        scopes = std::move(callerScopes);

        if (keepResults)
            writeBack(function, call, finals, into);

        return result;
    }

    Binding argumentBinding(int node, Vector<Statement>& into)
    {
        auto binding = Binding {};
        binding.node = lowerExpression(node, into);

        if (binding.node >= 0 && output.expr(binding.node).kind == ExprKind::Number)
        {
            binding.isConstant = true;
            binding.value = output.expr(binding.node).value;
            return binding;
        }

        const auto& expr = source.expr(node);

        if (expr.kind == ExprKind::Identifier)
            if (const auto* existing = find(expr.text))
            {
                binding.isConstant = existing->isConstant;
                binding.value = existing->value;
            }

        return binding;
    }

    // A parameter is substituted where that changes nothing - a literal or a
    // name the body only reads - and bound to a local of its own otherwise, so
    // an argument is never evaluated twice and never written through by
    // accident.
    void bindParameter(const Function& function,
                       int index,
                       const Binding& incoming,
                       Vector<Statement>& into)
    {
        const auto& parameter = function.parameters[index];
        auto kind =
            incoming.node >= 0 ? output.expr(incoming.node).kind : ExprKind::Number;

        auto substitutable =
            !parameter.writesBack
            && (kind == ExprKind::Number || kind == ExprKind::Identifier)
            && !assignsTo(function.body, parameter.name);

        if (substitutable)
        {
            scopes.back()[parameter.name] = incoming;
            return;
        }

        auto emitted = unique(parameter.name);
        auto declaration =
            Statement {StatementKind::Declare, emitted, parameter.type};
        declaration.value = incoming.node;
        declaration.line = line;
        into.add(std::move(declaration));

        auto binding = incoming;
        binding.node = identifier(emitted);
        scopes.back()[parameter.name] = binding;
    }

    void writeBack(const Function& function,
                   const Expr& call,
                   const Vector<Binding>& finals,
                   Vector<Statement>& into)
    {
        for (auto index = 0; index < function.parameters.size(); ++index)
        {
            const auto& parameter = function.parameters[index];

            if (!parameter.writesBack || !assignsTo(function.body, parameter.name))
                continue;

            auto* target = find(source.expr(call.args[index]).text);
            auto assignment = Statement {StatementKind::Assign};
            assignment.name = output.expr(target->node).text;
            assignment.value = finals[index].node;
            assignment.line = line;
            into.add(std::move(assignment));

            target->isConstant = finals[index].isConstant;
            target->value = finals[index].value;
        }
    }

    // --- statements -------------------------------------------------------

    void lowerInto(const Vector<Statement>& statements, Vector<Statement>& into)
    {
        for (const auto& statement: statements)
            lowerStatement(statement, into);
    }

    void lowerStatement(const Statement& statement, Vector<Statement>& into)
    {
        line = statement.line;

        switch (statement.kind)
        {
            case StatementKind::Declare:
                lowerDeclare(statement, into);
                return;

            case StatementKind::Assign:
                lowerAssign(statement, into);
                return;

            case StatementKind::Return:
                lowerReturn(statement, into);
                return;

            case StatementKind::For:
                lowerFor(statement, into);
                return;

            case StatementKind::Call:
                lowerCallStatement(statement, into);
                return;

            case StatementKind::Break:
                report(DiagnosticKind::ControlFlow, "break");
                return;

            case StatementKind::Continue:
                report(DiagnosticKind::ControlFlow, "continue");
                return;

            case StatementKind::Unsupported:
                return;
        }
    }

    void lowerDeclare(const Statement& statement, Vector<Statement>& into)
    {
        auto binding = Binding {};
        binding.isConstant = fold(statement.value, binding.value, true);

        // An integer local that is a constant has no reason to exist in the
        // port: substituting its value is what keeps `int` off the gap list,
        // since the EDSL has no integer type to lower it to.
        if (isIntegerType(statement.type) && binding.isConstant)
        {
            binding.node = number(binding.value);
            bind(statement.name, binding);
            return;
        }

        if (isIntegerType(statement.type))
            report(DiagnosticKind::UnsupportedType, statement.type);

        auto value = lowerExpression(statement.value, into);
        auto emitted = unique(statement.name);

        auto declaration =
            Statement {StatementKind::Declare, emitted, statement.type};
        declaration.value = value;
        declaration.line = statement.line;
        into.add(std::move(declaration));

        binding.node = identifier(emitted);
        bind(statement.name, binding);
    }

    void lowerAssign(const Statement& statement, Vector<Statement>& into)
    {
        auto value = lowerExpression(statement.value, into);

        auto* existing = find(statement.name);
        auto isVariable =
            existing != nullptr && existing->node >= 0
            && output.expr(existing->node).kind == ExprKind::Identifier;

        auto updated = constantAfter(statement, existing);

        if (existing == nullptr)
        {
            // The first write to the out parameter, or to a name whose
            // declaration the parser could not keep: it becomes the declaration.
            auto emitted = unique(statement.name);
            auto assignment = Statement {StatementKind::Assign, emitted};
            assignment.op = statement.op;
            assignment.value = value;
            assignment.line = statement.line;
            into.add(std::move(assignment));

            updated.node = identifier(emitted);
            bind(statement.name, updated);
            return;
        }

        if (isVariable)
        {
            auto assignment =
                Statement {StatementKind::Assign, output.expr(existing->node).text};
            assignment.op = statement.op;
            assignment.value = value;
            assignment.line = statement.line;
            into.add(std::move(assignment));

            updated.node = existing->node;
            *existing = updated;
            return;
        }

        // Writing to a name that stands for a literal - a loop counter, or a
        // substituted parameter - needs somewhere to put the result.
        auto emitted = unique(statement.name);
        auto declaration = Statement {StatementKind::Declare, emitted};
        declaration.value = statement.op.empty()
                                ? value
                                : binary(statement.op, existing->node, value);
        declaration.line = statement.line;
        into.add(std::move(declaration));

        updated.node = identifier(emitted);
        *existing = updated;
    }

    Binding constantAfter(const Statement& statement, const Binding* existing) const
    {
        auto binding = Binding {};
        auto value = 0.0;

        if (!fold(statement.value, value, true))
            return binding;

        if (statement.op.empty())
        {
            binding.isConstant = true;
            binding.value = value;
            return binding;
        }

        if (existing == nullptr || !existing->isConstant)
            return binding;

        binding.isConstant = true;

        if (statement.op == "+")
            binding.value = existing->value + value;
        else if (statement.op == "-")
            binding.value = existing->value - value;
        else if (statement.op == "*")
            binding.value = existing->value * value;
        else if (statement.op == "/" && value != 0.0)
            binding.value = existing->value / value;
        else
            binding.isConstant = false;

        return binding;
    }

    void lowerReturn(const Statement& statement, Vector<Statement>& into)
    {
        auto result = Statement {StatementKind::Return};
        result.value = lowerExpression(statement.value, into);
        result.line = statement.line;
        into.add(std::move(result));
    }

    void lowerCallStatement(const Statement& statement, Vector<Statement>& into)
    {
        auto lowered = lowerExpression(statement.value, into);

        // Nothing consumed the result, so a call that survived inlining would
        // vanish without the emitter ever seeing it. Name it here instead.
        if (lowered >= 0 && output.expr(lowered).kind == ExprKind::Call)
            report(DiagnosticKind::UserFunction, output.expr(lowered).text);
    }

    // --- loops ------------------------------------------------------------

    void lowerFor(const Statement& statement, Vector<Statement>& into)
    {
        if (statement.body < 0 || statement.init < 0 || statement.step < 0)
            return;

        auto counter = std::string {};
        auto values = Vector<double> {};

        if (!blocksFlattening(statement) && iterationsOf(statement, counter, values)
            && iterations + values.size() <= maxIterationsPerShader)
        {
            iterations += values.size();

            for (auto value: values)
            {
                scopes.add(Scope {});

                auto binding = Binding {};
                binding.node = number(value);
                binding.isConstant = true;
                binding.value = value;
                bind(counter, binding);

                lowerInto(source.block(statement.body).statements, into);
                scopes.pop_back();
            }

            return;
        }

        report(DiagnosticKind::ControlFlow, "for");
        measure(statement);
    }

    // A loop that will not unroll still has a body, and everything that body
    // needs is a gap the report should know about. Lowering it once into the
    // dropped list is what stops one unreachable loop from hiding a dozen
    // missing intrinsics.
    void measure(const Statement& statement)
    {
        scopes.add(Scope {});
        lowerInto(source.block(statement.init).statements, output.dropped);
        lowerInto(source.block(statement.body).statements, output.dropped);
        scopes.pop_back();
    }

    // Runs the loop header on paper. Anything that cannot be worked out from
    // literals - a bound that moves, a counter the body writes to - leaves the
    // loop for stage 5.
    bool iterationsOf(const Statement& statement,
                      std::string& counter,
                      Vector<double>& values)
    {
        if (statement.init < 0 || statement.step < 0 || statement.condition < 0)
            return false;

        const auto& init = source.block(statement.init).statements;
        const auto& step = source.block(statement.step).statements;

        if (init.size() != 1 || step.size() != 1)
            return false;

        auto declares = init[0].kind == StatementKind::Declare
                        || init[0].kind == StatementKind::Assign;

        counter = init[0].name;

        if (!declares || counter.empty() || step[0].name != counter
            || step[0].kind != StatementKind::Assign
            || assignsTo(statement.body, counter))
            return false;

        auto value = 0.0;

        if (!fold(init[0].value, value, true))
            return false;

        while (values.size() < maxIterationsPerLoop)
        {
            auto keepGoing = 0.0;

            if (!foldWithCounter(statement.condition, counter, value, keepGoing))
                return false;

            if (keepGoing == 0.0)
                return true;

            values.add(value);

            if (!applyStep(step[0], counter, value))
                return false;
        }

        return false;
    }

    bool applyStep(const Statement& step, const std::string& counter, double& value)
    {
        auto operand = 0.0;

        if (!foldWithCounter(step.value, counter, value, operand))
            return false;

        auto next = operand;

        if (step.op == "+")
            next = value + operand;
        else if (step.op == "-")
            next = value - operand;
        else if (step.op == "*")
            next = value * operand;
        else if (step.op == "/" && operand != 0.0)
            next = value / operand;
        else if (!step.op.empty())
            return false;

        if (next == value)
            return false;

        value = next;
        return true;
    }

    bool foldWithCounter(int node,
                         const std::string& counter,
                         double value,
                         double& out)
    {
        overrides[counter] = value;
        auto folded = fold(node, out, true);
        overrides.erase(counter);
        return folded;
    }

    const Shader& source;
    Shader output;

    Vector<Scope> scopes;
    Vector<std::string> inlining;
    std::set<std::string> measured;
    std::map<std::string, int> namesUsed;
    std::map<std::string, double> overrides;

    Vector<Diagnostic> diagnostics;
    int iterations = 0;
    int line = 0;
};
} // namespace

LowerResult lower(const Shader& parsed)
{
    return Lowerer {parsed}.run();
}
} // namespace Shadertoy::Glsl
