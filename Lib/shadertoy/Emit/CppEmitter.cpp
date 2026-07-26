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
    Mat2,
    Mat3,
    Mat4
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
        case Type::Mat2:
        case Type::Mat3:
        case Type::Mat4:
        case Type::Unknown:
            return 0;
    }

    return 0;
}

// The width of a square matrix's columns, and the number of them; zero for
// anything that is not one.
int matrixOrder(Type type)
{
    switch (type)
    {
        case Type::Mat2:
            return 2;
        case Type::Mat3:
            return 3;
        case Type::Mat4:
            return 4;
        default:
            return 0;
    }
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
    if (name == "mat2")
        return Type::Mat2;
    if (name == "mat3")
        return Type::Mat3;
    if (name == "mat4")
        return Type::Mat4;

    return Type::Unknown;
}

// The EDSL's spelling of a matrix type, which follows the shading languages
// rather than GLSL: float2x2 for a mat2.
const char* edslMatrixName(Type type)
{
    switch (type)
    {
        case Type::Mat2:
            return "float2x2";
        case Type::Mat3:
            return "float3x3";
        case Type::Mat4:
            return "float4x4";
        default:
            return nullptr;
    }
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

    // Where GLSL overloads one name on argument count and the EDSL spells the
    // two forms apart: atan(y, x) is atan2. Null when there is no second form.
    const char* edslBinary = nullptr;
};

constexpr Builtin builtins[] = {
    {"sin", "sin", ResultShape::LikeArg0},
    {"cos", "cos", ResultShape::LikeArg0},
    {"tan", "tan", ResultShape::LikeArg0},
    {"asin", "asin", ResultShape::LikeArg0},
    {"acos", "acos", ResultShape::LikeArg0},
    {"atan", "atan", ResultShape::LikeArg0, "atan2"},
    {"abs", "abs", ResultShape::LikeArg0},
    {"floor", "floor", ResultShape::LikeArg0},
    {"ceil", "ceil", ResultShape::LikeArg0},
    {"round", "round", ResultShape::LikeArg0},
    {"trunc", "trunc", ResultShape::LikeArg0},
    {"sign", "sign", ResultShape::LikeArg0},
    {"fract", "fract", ResultShape::LikeArg0},
    {"mod", "mod", ResultShape::LikeArg0},
    {"sqrt", "sqrt", ResultShape::LikeArg0},
    {"inversesqrt", "rsqrt", ResultShape::LikeArg0},
    {"exp", "exp", ResultShape::LikeArg0},
    {"exp2", "exp2", ResultShape::LikeArg0},
    {"log", "log", ResultShape::LikeArg0},
    {"log2", "log2", ResultShape::LikeArg0},
    {"normalize", "normalize", ResultShape::LikeArg0},
    {"min", "min", ResultShape::LikeArg0},
    {"max", "max", ResultShape::LikeArg0},
    {"pow", "pow", ResultShape::LikeArg0},
    {"clamp", "clamp", ResultShape::LikeArg0},
    {"mix", "mix", ResultShape::LikeArg0},
    {"step", "step", ResultShape::LikeArg1},
    {"smoothstep", "smoothstep", ResultShape::LikeArg2},
    {"reflect", "reflect", ResultShape::LikeArg0},
    {"refract", "refract", ResultShape::LikeArg0},
    {"faceforward", "faceforward", ResultShape::LikeArg0},
    {"dFdx", "dfdx", ResultShape::LikeArg0},
    {"dFdy", "dfdy", ResultShape::LikeArg0},
    {"fwidth", "fwidth", ResultShape::LikeArg0},
    {"length", "length", ResultShape::Scalar},
    {"distance", "distance", ResultShape::Scalar},
    {"dot", "dot", ResultShape::Scalar},
    {"cross", "cross", ResultShape::Vec3},

    // Everything below is a gap: GLSL has it, the EDSL does not. The matrix
    // three need an operation on Float2x2/Float3x3 beyond construction and
    // multiplication, which is where those types stop today.
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

        // Statements lowering could not keep are walked for what they need and
        // their text thrown away, so an unreachable loop still contributes every
        // intrinsic, swizzle and channel inside it to the coverage report.
        for (const auto& statement: shader.dropped)
            emitStatement(statement);

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

            return layoutValue(
                "        auto " + statement.name + " = ", statement.value, ";");
        }

        auto found = pending.find(statement.name);

        if (found != pending.end())
        {
            types[statement.name] = found->second != Type::Unknown
                                        ? found->second
                                        : typeOf(statement.value);
            pending.erase(found);

            return layoutValue(
                "        auto " + statement.name + " = ", statement.value, ";");
        }

        if (types.count(statement.name) == 0)
        {
            // The first write to the out parameter, or to a name whose
            // declaration was skipped: introduce it here.
            types[statement.name] = statement.name == shader.fragColor
                                        ? Type::Vec4
                                        : typeOf(statement.value);

            return layoutValue(
                "        auto " + statement.name + " = ", statement.value, ";");
        }

        // `col += x` becomes `col = col + x`, with the right-hand side
        // parenthesised only where the compound operator would otherwise
        // rebind it: `col -= a + b` must not become `col = col - a + b`.
        if (!statement.op.empty())
        {
            auto head = "        " + statement.name + " = " + statement.name;
            auto single =
                head + " " + statement.op + " "
                + emitOperand(statement.value, precedenceOf(statement.op), true)
                + ";";

            if ((int) single.size() <= columnLimit)
                return single + "\n";

            auto start = 12 + (int) statement.op.size() + 1;

            return head + "\n            " + statement.op + " "
                   + layoutOperand(statement.value,
                                   start,
                                   "                ",
                                   precedenceOf(statement.op),
                                   true)
                   + ";\n";
        }

        return layoutValue(
            "        " + statement.name + " = ", statement.value, ";");
    }

    // --- layout ----------------------------------------------------------

    // Everything below exists because an unrolled, inlined body arrives as one
    // expression however long it started out, and a generated header sits in a
    // project held to eacp's column limit.

    std::string
        layoutValue(const std::string& prefix, int node, const std::string& suffix)
    {
        if (!needsAnchor(node))
            return layout(prefix, node, suffix);

        return layout(prefix + "constant(", node, ")" + suffix);
    }

    std::string
        layout(const std::string& prefix, int node, const std::string& suffix)
    {
        auto column = (int) prefix.size();
        auto body =
            layoutExpression(node, column, (int) suffix.size(), "            ");
        return prefix + body + suffix + "\n";
    }

    // One expression, broken where it will not fit on the line it starts on. A
    // run of operators at one precedence breaks at the operators, the way the
    // GLSL was written; a call breaks between its arguments; and what lands on
    // a continuation line is laid out the same way again.
    std::string layoutExpression(int node,
                                 int column,
                                 int trailing,
                                 const std::string& indent)
    {
        auto single = emitExpression(node);

        if (node < 0 || column + (int) single.size() + trailing <= columnLimit)
            return single;

        const auto& expr = shader.expr(node);
        auto precedence =
            expr.kind == ExprKind::Binary ? precedenceOf(expr.text) : 0;

        if (precedence > 0)
        {
            auto terms = Vector<std::pair<std::string, int>> {};
            flattenChain(node, precedence, terms);

            if (terms.size() >= 2)
                return layoutChain(terms, column, trailing, indent, precedence);
        }

        if (expr.kind == ExprKind::Call && !expr.args.empty())
        {
            auto callee = wrappableCallName(node, expr);

            if (!callee.empty())
                return layoutCall(callee, expr, column, trailing, indent);
        }

        return single;
    }

    // The name a call emits under, when it emits as name(args...) over exactly
    // the arguments it was parsed with - the only shape the wrapping layout can
    // rebuild, since it re-walks the argument nodes rather than the text
    // emitCall produced. A constructor that regroups its arguments into columns,
    // repeats a broadcast scalar or anchors one with constant() has no such
    // form, and stays on one line.
    std::string wrappableCallName(int node, const Expr& expr)
    {
        auto width = vectorConstructorWidth(expr.text);

        if (width > 0)
        {
            auto broadcasts = expr.args.size() == 1
                              && typeOf(expr.args[0]) == Type::Float && width > 1;

            if (broadcasts || !mentionsAName(node))
                return {};

            return "float" + std::to_string(width);
        }

        const auto* builtin = findBuiltin(expr.text);

        if (builtin == nullptr || builtin->edsl == nullptr)
            return {};

        return builtin->edslBinary != nullptr && expr.args.size() == 2
                   ? builtin->edslBinary
                   : builtin->edsl;
    }

    std::string layoutChain(const Vector<std::pair<std::string, int>>& terms,
                            int column,
                            int trailing,
                            const std::string& indent,
                            int precedence)
    {
        auto inner = indent + "    ";
        auto text = layoutOperand(terms[0].second, column, inner, precedence, false);

        for (auto index = 1; index < terms.size(); ++index)
        {
            const auto& op = terms[index].first;
            auto last = index + 1 == terms.size();
            auto start = (int) indent.size() + (int) op.size() + 1;

            text += "\n";
            text += indent;
            text += op;
            text += " ";
            text += layoutOperand(terms[index].second,
                                  start,
                                  inner,
                                  precedence,
                                  true,
                                  last ? trailing : 0);
        }

        return text;
    }

    // The argument list filled greedily, so a call that runs long breaks where
    // it has to rather than once per argument.
    std::string layoutCall(const std::string& callee,
                           const Expr& expr,
                           int column,
                           int trailing,
                           const std::string& indent)
    {
        auto inner = indent + "    ";
        auto text = callee + "(";
        auto at = column + (int) text.size();

        for (auto index = 0; index < expr.args.size(); ++index)
        {
            auto last = index + 1 == expr.args.size();
            auto separator = last ? std::string {} : std::string {","};
            auto reserved = (int) separator.size() + (last ? trailing + 1 : 0);
            auto argument = emitExpression(expr.args[index]);

            if (at + (int) argument.size() + reserved > columnLimit)
            {
                // The space after the previous comma belongs to an argument
                // that turned out to start on the next line instead.
                if (!text.empty() && text.back() == ' ')
                    text.pop_back();

                text += "\n" + indent;
                at = (int) indent.size();
                argument = layoutExpression(expr.args[index], at, reserved, inner);
            }

            text += argument + separator + (last ? "" : " ");
            at = columnAfter(argument, at) + (int) separator.size() + (last ? 0 : 1);
        }

        return text + ")";
    }

    std::string layoutOperand(int node,
                              int column,
                              const std::string& indent,
                              int parentPrecedence,
                              bool onTheRight,
                              int trailing = 0)
    {
        auto grouped = needsParentheses(node, parentPrecedence, onTheRight);
        auto text = layoutExpression(
            node, column + (grouped ? 1 : 0), trailing + (grouped ? 1 : 0), indent);

        return grouped ? "(" + text + ")" : text;
    }

    bool needsParentheses(int node, int parentPrecedence, bool onTheRight) const
    {
        if (node < 0 || shader.expr(node).kind != ExprKind::Binary)
            return false;

        auto precedence = precedenceOf(shader.expr(node).text);

        if (precedence == 0)
            return false;

        return precedence < parentPrecedence
               || (onTheRight && precedence == parentPrecedence);
    }

    // Where a piece of text that may have wrapped leaves the cursor.
    static int columnAfter(const std::string& text, int start)
    {
        auto lastBreak = text.find_last_of('\n');

        if (lastBreak == std::string::npos)
            return start + (int) text.size();

        return (int) (text.size() - lastBreak - 1);
    }

    // Walks the left spine of a chain of one precedence. Only the spine: a right
    // operand that is itself a chain keeps its grouping, since floating-point
    // arithmetic does not re-associate.
    void flattenChain(int node,
                      int precedence,
                      Vector<std::pair<std::string, int>>& terms) const
    {
        const auto& expr = shader.expr(node);

        if (expr.kind == ExprKind::Binary && precedenceOf(expr.text) == precedence)
        {
            flattenChain(expr.args[0], precedence, terms);
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

    // A scalar local built only from literals would be a C++ float rather than a
    // value in the graph, and `auto d = 2.0f` breaks everything downstream of it
    // - min(), sin() and the vector constructors all need a handle. Anchoring it
    // with constant() gives it one without changing what it holds. Inlining a
    // helper called with constants produces these by the handful, which is why
    // it matters now and did not before.
    bool needsAnchor(int node)
    {
        return node >= 0 && typeOf(node) == Type::Float && !mentionsAName(node);
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
        {
            // GLSL reads `vector * matrix` as the row vector on the left, which
            // is the transposed product - a different value from the matrix *
            // vector the EDSL spells, not a missing overload.
            if (expr.text == "*" && matrixOrder(typeOf(expr.args[1])) > 0
                && componentsOf(typeOf(expr.args[0])) > 1)
            {
                report(DiagnosticKind::UnsupportedType, "vector * matrix");
                return "/* unsupported: vector * matrix */ (" + left + ")";
            }

            return left + " " + expr.text + " " + right;
        }

        // GLSL defines % on integers only, so what a shader reaching it needs
        // is the integer type, not a modulus - mod() is spelled for floats.
        if (expr.text == "%")
            report(DiagnosticKind::UnsupportedType, "int %");
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

        // The EDSL has an accessor for every ordering of up to four components,
        // so .yx and .bgra are each one call and one Swizzle node.
        if (!canonical.empty() && canonical.size() <= 4)
            return object + "." + canonical + "()";

        report(DiagnosticKind::UnsupportedSwizzle, "." + expr.text);
        return "/* unsupported swizzle */ " + object + "." + expr.text + "()";
    }

    std::string emitCall(int node, const Expr& expr)
    {
        auto width = vectorConstructorWidth(expr.text);

        if (width > 0)
            return emitVectorConstructor(node, expr, width);

        // `float(x)` is a conversion, and after unrolling has substituted the
        // counter it is usually a conversion of a literal. The parentheses stay
        // where dropping them would re-bind the expression around it.
        if (expr.text == "float" && expr.args.size() == 1)
        {
            auto inner = emitExpression(expr.args[0]);
            auto grouped = shader.expr(expr.args[0]).kind == ExprKind::Binary
                           || shader.expr(expr.args[0]).kind == ExprKind::Ternary;

            return grouped ? "(" + inner + ")" : inner;
        }

        // An integer conversion truncates, and the EDSL has neither the type nor
        // the intrinsic to say so.
        if (expr.text == "int" || expr.text == "uint" || expr.text == "bool")
        {
            report(DiagnosticKind::UnsupportedType, expr.text);
            return "/* unsupported: " + expr.text + " */ " + emitArguments(expr);
        }

        if (isTextureCall(expr.text))
        {
            report(DiagnosticKind::UnsupportedTexture, expr.text);
            return "/* unsupported: " + expr.text + " */ float4(constant(0.0f), "
                   + "0.0f, 0.0f, 1.0f)";
        }

        auto matrix = typeFromGlslName(expr.text);

        if (matrixOrder(matrix) > 0)
            return emitMatrixConstructor(node, expr, matrix);

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

        // GLSL overloads atan on argument count; the EDSL spells the
        // quadrant-aware form atan2, the way both shading languages do.
        auto spelling = builtin->edslBinary != nullptr && expr.args.size() == 2
                            ? builtin->edslBinary
                            : builtin->edsl;

        return std::string(spelling) + "(" + emitArguments(expr) + ")";
    }

    // GLSL fills a matrix column by column, from either one column vector per
    // column, or every component in column order, or a single scalar on the
    // diagonal. The EDSL's constructors take the columns, so only the middle
    // form has to be regrouped.
    std::string emitMatrixConstructor(int node, const Expr& expr, Type type)
    {
        auto order = matrixOrder(type);
        auto columns = Vector<std::string> {};

        // One column vector per column: each argument already emits as a
        // value, and one built only from literals anchors itself.
        if ((int) expr.args.size() == order && typeOf(expr.args[0]) != Type::Float)
        {
            for (auto arg: expr.args)
                columns.add(emitExpression(arg));

            return joinMatrix(type, columns);
        }

        auto components = Vector<std::string> {};

        if ((int) expr.args.size() == order * order)
        {
            for (auto arg: expr.args)
                components.add(emitExpression(arg));
        }
        else if (expr.args.size() == 1 && typeOf(expr.args[0]) == Type::Float)
        {
            // mat2(s) puts s down the diagonal and zero everywhere else.
            auto scalar = emitExpression(expr.args[0]);

            for (auto column = 0; column < order; ++column)
                for (auto row = 0; row < order; ++row)
                    components.add(row == column ? scalar : "0.0f");
        }
        else
        {
            report(DiagnosticKind::UnsupportedType, expr.text);
            return "/* unsupported: " + expr.text + " */ " + emitArguments(expr);
        }

        // Like a vector built only from literals, a matrix built only from them
        // has no value handle to take a graph from - see emitVectorConstructor.
        if (!mentionsAName(node))
            components[0] = "constant(" + components[0] + ")";

        auto columnName = "float" + std::to_string(order);

        for (auto column = 0; column < order; ++column)
        {
            auto parts = std::string {};

            for (auto row = 0; row < order; ++row)
                parts += (row > 0 ? ", " : "") + components[column * order + row];

            columns.add(columnName + "(" + parts + ")");
        }

        return joinMatrix(type, columns);
    }

    static std::string joinMatrix(Type type, const Vector<std::string>& columns)
    {
        auto text = std::string(edslMatrixName(type)) + "(";

        for (auto index = 0; index < columns.size(); ++index)
            text += (index > 0 ? ", " : "") + columns[index];

        return text + ")";
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
