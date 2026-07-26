#include "CppEmitter.h"

#include <cstdio>
#include <map>

namespace Shadertoy::Cpp
{
using namespace Glsl;

namespace
{
// The shapes a value can have. Enough to drive constructor widths, swizzle
// widths and broadcast decisions; the EDSL's own type system catches whatever
// this misses when the generated file is compiled.
enum class Type
{
    Unknown,
    Float,
    Vec2,
    Vec3,
    Vec4,
    Matrix
};

int componentsOf(Type type)
{
    switch (type)
    {
        case Type::Float:
            return 1;
        case Type::Vec2:
            return 2;
        case Type::Vec3:
            return 3;
        case Type::Vec4:
            return 4;
        case Type::Matrix:
        case Type::Unknown:
            return 0;
    }

    return 0;
}

Type typeOfWidth(int components)
{
    switch (components)
    {
        case 1:
            return Type::Float;
        case 2:
            return Type::Vec2;
        case 3:
            return Type::Vec3;
        case 4:
            return Type::Vec4;
        default:
            return Type::Unknown;
    }
}

Type typeFromGlslName(std::string_view name)
{
    if (name == "float")
        return Type::Float;
    if (name == "vec2")
        return Type::Vec2;
    if (name == "vec3")
        return Type::Vec3;
    if (name == "vec4")
        return Type::Vec4;
    if (name == "mat2" || name == "mat3" || name == "mat4")
        return Type::Matrix;

    return Type::Unknown;
}

// Where a builtin's result shape comes from. GLSL's rules are per-function -
// step() is shaped like its second argument, smoothstep() like its third - and
// getting this wrong would emit constructors of the wrong width.
enum class ResultShape
{
    LikeArg0,
    LikeArg1,
    LikeArg2,
    Scalar,
    Vec3,
    Vec4
};

struct Builtin
{
    const char* glsl;
    const char* edsl; // null where the EDSL has no spelling for it
    ResultShape shape;
};

constexpr Builtin builtins[] = {
    {"sin", "sin", ResultShape::LikeArg0},
    {"cos", "cos", ResultShape::LikeArg0},
    {"abs", "abs", ResultShape::LikeArg0},
    {"floor", "floor", ResultShape::LikeArg0},
    {"fract", "fract", ResultShape::LikeArg0},
    {"sqrt", "sqrt", ResultShape::LikeArg0},
    {"normalize", "normalize", ResultShape::LikeArg0},
    {"min", "min", ResultShape::LikeArg0},
    {"max", "max", ResultShape::LikeArg0},
    {"pow", "pow", ResultShape::LikeArg0},
    {"clamp", "clamp", ResultShape::LikeArg0},
    {"mix", "mix", ResultShape::LikeArg0},
    {"step", "step", ResultShape::LikeArg1},
    {"smoothstep", "smoothstep", ResultShape::LikeArg2},
    {"length", "length", ResultShape::Scalar},
    {"dot", "dot", ResultShape::Scalar},
    {"cross", "cross", ResultShape::Vec3},

    // Everything below is a gap: GLSL has it, the EDSL does not.
    {"atan", nullptr, ResultShape::LikeArg0},
    {"tan", nullptr, ResultShape::LikeArg0},
    {"asin", nullptr, ResultShape::LikeArg0},
    {"acos", nullptr, ResultShape::LikeArg0},
    {"exp", nullptr, ResultShape::LikeArg0},
    {"exp2", nullptr, ResultShape::LikeArg0},
    {"log", nullptr, ResultShape::LikeArg0},
    {"log2", nullptr, ResultShape::LikeArg0},
    {"mod", nullptr, ResultShape::LikeArg0},
    {"sign", nullptr, ResultShape::LikeArg0},
    {"ceil", nullptr, ResultShape::LikeArg0},
    {"round", nullptr, ResultShape::LikeArg0},
    {"trunc", nullptr, ResultShape::LikeArg0},
    {"inversesqrt", nullptr, ResultShape::LikeArg0},
    {"reflect", nullptr, ResultShape::LikeArg0},
    {"refract", nullptr, ResultShape::LikeArg0},
    {"faceforward", nullptr, ResultShape::LikeArg0},
    {"distance", nullptr, ResultShape::Scalar},
    {"dFdx", nullptr, ResultShape::LikeArg0},
    {"dFdy", nullptr, ResultShape::LikeArg0},
    {"fwidth", nullptr, ResultShape::LikeArg0},
    {"transpose", nullptr, ResultShape::LikeArg0},
    {"inverse", nullptr, ResultShape::LikeArg0},
    {"determinant", nullptr, ResultShape::Scalar},
};

const Builtin* findBuiltin(const std::string& name)
{
    for (const auto& builtin: builtins)
        if (name == builtin.glsl)
            return &builtin;

    return nullptr;
}

bool isTextureCall(const std::string& name)
{
    return name == "texture" || name == "texture2D" || name == "textureLod"
           || name == "texelFetch" || name == "textureGrad";
}

// vec2/vec3/vec4 and their EDSL counterparts. mat2/mat3/mat4 deliberately fall
// through to the unsupported path: the EDSL has only float4x4.
int vectorConstructorWidth(const std::string& name)
{
    if (name == "vec2")
        return 2;
    if (name == "vec3")
        return 3;
    if (name == "vec4")
        return 4;

    return 0;
}

// The x/y/z/w spelling of one component from any of GLSL's three sets.
char canonicalComponent(char component)
{
    switch (component)
    {
        case 'x':
        case 'r':
        case 's':
            return 'x';
        case 'y':
        case 'g':
        case 't':
            return 'y';
        case 'z':
        case 'b':
        case 'p':
            return 'z';
        case 'w':
        case 'a':
        case 'q':
            return 'w';
        default:
            return 0;
    }
}

// C++ and GLSL agree on the precedence of the four arithmetic operators, so an
// expression that needed no parentheses in the source needs none in the port.
// Emitting them anyway is what turned a readable sum into a thicket.
// eacp's own column limit, so a generated header sits in the project without
// clang-format wanting to reflow it.
constexpr auto columnLimit = 85;

int precedenceOf(const std::string& op)
{
    if (op == "*" || op == "/" || op == "%")
        return 2;

    if (op == "+" || op == "-")
        return 1;

    return 0;
}

std::string floatLiteral(double value)
{
    char buffer[64] = {};
    std::snprintf(buffer, sizeof(buffer), "%.9g", value);

    auto text = std::string(buffer);

    if (text.find('.') == std::string::npos && text.find('e') == std::string::npos
        && text.find("inf") == std::string::npos
        && text.find("nan") == std::string::npos)
        text += ".0";

    return text + "f";
}

class Emitter
{
public:
    Emitter(const Shader& shaderToEmit, std::string structNameToUse)
        : shader(shaderToEmit)
        , structName(std::move(structNameToUse))
    {
        types[shader.fragCoord] = Type::Vec2;
        types["iResolution"] = Type::Vec3;
        types["iTime"] = Type::Float;
        types["iTimeDelta"] = Type::Float;
        types["iFrame"] = Type::Float;
        types["iMouse"] = Type::Vec4;
    }

    EmitResult run()
    {
        auto body = std::string {};

        for (const auto& statement: shader.statements)
            body += emitStatement(statement);

        body += emitResult();

        auto result = EmitResult {};
        result.code = preamble() + body + epilogue();
        result.diagnostics = std::move(diagnostics);
        return result;
    }

private:
    // Expression nodes carry no line of their own, so a diagnostic raised while
    // lowering one is attributed to the statement it belongs to. For the
    // straight-line code this stage accepts, that is the same line.
    void report(DiagnosticKind kind, std::string detail)
    {
        diagnostics.add({kind, std::move(detail), currentLine});
    }

    std::string preamble() const
    {
        return "#pragma once\n\n#include <shadertoy/Shadertoy.h>\n\n"
               "// Generated by the ShaderToyEACP transpiler. Edit the GLSL this\n"
               "// came from, not this file.\n\n"
               "namespace Shadertoy::Ports\n{\n"
               "struct "
               + structName + " final : Program\n{\n    " + structName
               + "() { compile(); }\n\n"
                 "    GPU::Float4 mainImage(const GPU::Float2& "
               + shader.fragCoord + ") override\n    {\n";
    }

    std::string epilogue() const
    {
        return "    }\n};\n} // namespace Shadertoy::Ports\n";
    }

    // The out parameter is an ordinary local as far as the port is concerned:
    // C++ locals rebind their handle on assignment, so every write GLSL makes to
    // fragColor is just another `=`, and the last value it holds is returned.
    std::string emitResult()
    {
        if (types.count(shader.fragColor) != 0)
            return "        return " + shader.fragColor + ";\n";

        if (wroteReturn)
            return {};

        report(DiagnosticKind::ParseError, "mainImage never writes fragColor");
        return "        return float4(constant(0.0f), 0.0f, 0.0f, 1.0f);\n";
    }

    std::string emitStatement(const Statement& statement)
    {
        currentLine = statement.line;

        if (statement.kind == StatementKind::Return)
        {
            if (statement.value < 0)
            {
                report(DiagnosticKind::ControlFlow, "early return");
                return {};
            }

            wroteReturn = true;
            return layout("        return ", statement.value, ";");
        }

        if (statement.kind == StatementKind::Declare)
        {
            auto declared = typeFromGlslName(statement.type);

            if (statement.value < 0)
            {
                // A declaration with no initialiser has nothing to bind an
                // `auto` to; the assignment that follows becomes the
                // declaration instead.
                pending[statement.name] = declared;
                return {};
            }

            types[statement.name] =
                declared != Type::Unknown ? declared : typeOf(statement.value);

            return layout(
                "        auto " + statement.name + " = ", statement.value, ";");
        }

        auto found = pending.find(statement.name);

        if (found != pending.end())
        {
            types[statement.name] = found->second != Type::Unknown
                                        ? found->second
                                        : typeOf(statement.value);
            pending.erase(found);

            return layout(
                "        auto " + statement.name + " = ", statement.value, ";");
        }

        if (types.count(statement.name) == 0)
        {
            // The first write to the out parameter, or to a name whose
            // declaration was skipped: introduce it here.
            types[statement.name] = statement.name == shader.fragColor
                                        ? Type::Vec4
                                        : typeOf(statement.value);

            return layout(
                "        auto " + statement.name + " = ", statement.value, ";");
        }

        // `col += x` becomes `col = col + x`, with the right-hand side
        // parenthesised only where the compound operator would otherwise
        // rebind it: `col -= a + b` must not become `col = col - a + b`.
        if (!statement.op.empty())
        {
            auto operand =
                emitOperand(statement.value, precedenceOf(statement.op), true);

            auto head = "        " + statement.name + " = " + statement.name;
            auto single = head + " " + statement.op + " " + operand + ";";

            if (single.size() <= columnLimit)
                return single + "\n";

            return head + "\n            " + statement.op + " " + operand + ";\n";
        }

        return layout("        " + statement.name + " = ", statement.value, ";");
    }

    // --- layout ----------------------------------------------------------

    // One statement, wrapped when it will not fit. Only a top-level sum is
    // broken up, because that is the shape that runs long in practice - a
    // shader accumulating terms - and breaking it at the operators is how the
    // GLSL was written in the first place.
    std::string
        layout(const std::string& prefix, int node, const std::string& suffix)
    {
        auto single = prefix + emitExpression(node) + suffix;

        if (single.size() <= columnLimit || node < 0)
            return single + "\n";

        auto terms = Vector<std::pair<std::string, int>> {};
        flattenSum(node, terms);

        if (terms.size() < 2)
            return single + "\n";

        auto text = prefix + emitOperand(terms[0].second, 1, false);

        for (auto index = 1; index < terms.size(); ++index)
            text += "\n            " + terms[index].first + " "
                    + emitOperand(terms[index].second, 1, true);

        return text + suffix + "\n";
    }

    // Walks the left spine of a + / - chain. Only the spine: a right operand
    // that is itself a sum keeps its grouping, since floating-point addition
    // does not re-associate.
    void flattenSum(int node, Vector<std::pair<std::string, int>>& terms) const
    {
        const auto& expr = shader.expr(node);

        if (expr.kind == ExprKind::Binary && precedenceOf(expr.text) == 1)
        {
            flattenSum(expr.args[0], terms);
            terms.add({expr.text, expr.args[1]});
            return;
        }

        terms.add({std::string {}, node});
    }

    // --- types -----------------------------------------------------------

    Type typeOf(int node)
    {
        if (node < 0)
            return Type::Unknown;

        const auto& expr = shader.expr(node);

        switch (expr.kind)
        {
            case ExprKind::Number:
                return Type::Float;

            case ExprKind::Identifier:
            {
                auto found = types.find(expr.text);
                return found != types.end() ? found->second : Type::Unknown;
            }

            case ExprKind::Unary:
                return typeOf(expr.args[0]);

            case ExprKind::Binary:
            {
                // A vector next to a scalar broadcasts, so the wider operand
                // wins - which is also what the EDSL's operators do.
                auto left = typeOf(expr.args[0]);
                auto right = typeOf(expr.args[1]);
                return componentsOf(left) >= componentsOf(right) ? left : right;
            }

            case ExprKind::Ternary:
                return typeOf(expr.args[1]);

            case ExprKind::Member:
                return typeOfWidth((int) expr.text.size());

            case ExprKind::Index:
                return Type::Unknown;

            case ExprKind::Call:
                return typeOfCall(expr);
        }

        return Type::Unknown;
    }

    Type typeOfCall(const Expr& expr)
    {
        auto width = vectorConstructorWidth(expr.text);

        if (width > 0)
            return typeOfWidth(width);

        auto declared = typeFromGlslName(expr.text);

        if (declared != Type::Unknown)
            return declared;

        const auto* builtin = findBuiltin(expr.text);

        if (builtin == nullptr)
            return Type::Unknown;

        switch (builtin->shape)
        {
            case ResultShape::Scalar:
                return Type::Float;
            case ResultShape::Vec3:
                return Type::Vec3;
            case ResultShape::Vec4:
                return Type::Vec4;
            case ResultShape::LikeArg0:
                return expr.args.size() > 0 ? typeOf(expr.args[0]) : Type::Unknown;
            case ResultShape::LikeArg1:
                return expr.args.size() > 1 ? typeOf(expr.args[1]) : Type::Unknown;
            case ResultShape::LikeArg2:
                return expr.args.size() > 2 ? typeOf(expr.args[2]) : Type::Unknown;
        }

        return Type::Unknown;
    }

    // Whether a subtree mentions any name at all. An expression built only from
    // literals has no graph to record itself into, so the EDSL's vector
    // constructors reject it - see emitVectorConstructor.
    bool mentionsAName(int node) const
    {
        if (node < 0)
            return false;

        const auto& expr = shader.expr(node);

        if (expr.kind == ExprKind::Identifier)
            return true;

        for (auto arg: expr.args)
            if (mentionsAName(arg))
                return true;

        return false;
    }

    // --- expressions -----------------------------------------------------

    // An operand of a binary expression, wrapped only where the surrounding
    // operator binds tighter than the one inside it - or equally tightly on the
    // right, where `a - (b - c)` must keep its grouping.
    std::string emitOperand(int node, int parentPrecedence, bool onTheRight)
    {
        auto text = emitExpression(node);

        if (node < 0)
            return text;

        const auto& child = shader.expr(node);

        if (child.kind != ExprKind::Binary)
            return text;

        auto precedence = precedenceOf(child.text);

        if (precedence == 0)
            return text;

        auto needsParentheses = precedence < parentPrecedence
                                || (onTheRight && precedence == parentPrecedence);

        return needsParentheses ? "(" + text + ")" : text;
    }

    std::string emitExpression(int node)
    {
        if (node < 0)
            return "0.0f";

        const auto& expr = shader.expr(node);

        switch (expr.kind)
        {
            case ExprKind::Number:
                return floatLiteral(expr.value);

            case ExprKind::Identifier:
                return emitIdentifier(expr);

            case ExprKind::Unary:
                return emitUnary(expr);

            case ExprKind::Binary:
                return emitBinary(expr);

            case ExprKind::Member:
                return emitMember(expr);

            case ExprKind::Ternary:
                report(DiagnosticKind::ControlFlow, "?:");
                return "/* unsupported: ?: */ (" + emitExpression(expr.args[1])
                       + ")";

            case ExprKind::Index:
                report(DiagnosticKind::UnsupportedType, "indexing");
                return "/* unsupported: [] */ (" + emitExpression(expr.args[0])
                       + ")";

            case ExprKind::Call:
                return emitCall(node, expr);
        }

        return "0.0f";
    }

    std::string emitIdentifier(const Expr& expr)
    {
        if (types.count(expr.text) != 0 || pending.count(expr.text) != 0)
            return expr.text;

        if (expr.text.rfind("iChannel", 0) == 0)
            report(DiagnosticKind::UnsupportedTexture, expr.text);
        else
            report(DiagnosticKind::UnknownIdentifier, expr.text);

        return "/* unresolved: " + expr.text + " */ " + expr.text;
    }

    std::string emitUnary(const Expr& expr)
    {
        auto operand = emitExpression(expr.args[0]);
        auto compound = shader.expr(expr.args[0]).kind == ExprKind::Binary;

        if (expr.text == "-")
            return compound ? "-(" + operand + ")" : "-" + operand;

        if (expr.text == "+")
            return operand;

        report(DiagnosticKind::ControlFlow, expr.text);
        return "/* unsupported: " + expr.text + " */ (" + operand + ")";
    }

    std::string emitBinary(const Expr& expr)
    {
        auto precedence = precedenceOf(expr.text);
        auto left = emitOperand(expr.args[0], precedence, false);
        auto right = emitOperand(expr.args[1], precedence, true);

        if (precedenceOf(expr.text) > 0 && expr.text != "%")
            return left + " " + expr.text + " " + right;

        if (expr.text == "%")
            report(DiagnosticKind::UnsupportedIntrinsic, "mod");
        else
            report(DiagnosticKind::ControlFlow, expr.text);

        return "/* unsupported: " + expr.text + " */ (" + left + ")";
    }

    std::string emitMember(const Expr& expr)
    {
        auto object = emitExpression(expr.args[0]);
        auto canonical = std::string {};

        for (auto component: expr.text)
        {
            auto mapped = canonicalComponent(component);

            if (mapped == 0)
            {
                canonical.clear();
                break;
            }

            canonical += mapped;
        }

        // The EDSL exposes the single components plus the two leading runs;
        // anything reordered or narrower, like .zw or .yx, has no accessor.
        if (canonical == "x" || canonical == "y" || canonical == "z"
            || canonical == "w" || canonical == "xy" || canonical == "xyz")
            return object + "." + canonical + "()";

        report(DiagnosticKind::UnsupportedSwizzle, "." + expr.text);
        return "/* unsupported swizzle */ " + object + "." + expr.text + "()";
    }

    std::string emitCall(int node, const Expr& expr)
    {
        auto width = vectorConstructorWidth(expr.text);

        if (width > 0)
            return emitVectorConstructor(node, expr, width);

        if (isTextureCall(expr.text))
        {
            report(DiagnosticKind::UnsupportedTexture, expr.text);
            return "/* unsupported: " + expr.text + " */ float4(constant(0.0f), "
                   + "0.0f, 0.0f, 1.0f)";
        }

        if (expr.text == "mat2" || expr.text == "mat3" || expr.text == "mat4")
        {
            report(DiagnosticKind::UnsupportedType, expr.text);
            return "/* unsupported: " + expr.text + " */ " + emitArguments(expr);
        }

        const auto* builtin = findBuiltin(expr.text);

        if (builtin == nullptr)
        {
            report(DiagnosticKind::UserFunction, expr.text);
            return "/* unresolved call */ " + expr.text + "(" + emitArguments(expr)
                   + ")";
        }

        if (builtin->edsl == nullptr)
        {
            report(DiagnosticKind::UnsupportedIntrinsic, expr.text);
            return "/* unsupported: " + expr.text + " */ " + expr.text + "("
                   + emitArguments(expr) + ")";
        }

        return std::string(builtin->edsl) + "(" + emitArguments(expr) + ")";
    }

    std::string emitArguments(const Expr& expr)
    {
        auto text = std::string {};

        for (auto index = 0; index < expr.args.size(); ++index)
        {
            if (index > 0)
                text += ", ";

            text += emitExpression(expr.args[index]);
        }

        return text;
    }

    std::string emitVectorConstructor(int node, const Expr& expr, int width)
    {
        auto name = "float" + std::to_string(width);
        auto parts = Vector<std::string> {};

        // GLSL broadcasts a lone scalar across the whole vector; the EDSL's
        // constructors take one argument per component, so the scalar is
        // repeated. It is emitted rather than bound to a temporary, so a
        // complex argument is recorded once per component - correct, but worth
        // knowing when reading the generated graph.
        if (expr.args.size() == 1 && typeOf(expr.args[0]) == Type::Float
            && width > 1)
        {
            auto scalar = emitExpression(expr.args[0]);

            for (auto index = 0; index < width; ++index)
                parts.add(scalar);
        }
        else
        {
            for (auto arg: expr.args)
                parts.add(emitExpression(arg));
        }

        // A constructor built purely from literals has no value handle to take
        // a graph from, and the EDSL rejects it. Anchoring the first component
        // with constant() gives it one without changing what it evaluates to.
        if (!mentionsAName(node) && !parts.empty())
            parts[0] = "constant(" + parts[0] + ")";

        auto text = name + "(";

        for (auto index = 0; index < parts.size(); ++index)
        {
            if (index > 0)
                text += ", ";

            text += parts[index];
        }

        return text + ")";
    }

    const Shader& shader;
    std::string structName;

    std::map<std::string, Type> types;
    std::map<std::string, Type> pending;
    Vector<Diagnostic> diagnostics;
    int currentLine = 0;
    bool wroteReturn = false;
};
} // namespace

EmitResult emit(const Glsl::Shader& shader, const std::string& structName)
{
    return Emitter {shader, structName}.run();
}
} // namespace Shadertoy::Cpp
