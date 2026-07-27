#include "CppEmitter.h"

#include <cstdio>
#include <map>
#include <set>

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
    Bool, // what a comparison yields and a branch or a select tests
    BVec2, // and what comparing two vectors yields, one component at a time
    BVec3,
    BVec4,
    Int, // what subscripts an array, and what % and the bitwise set take
    IVec2, // the cell a shader working on a grid counts
    IVec3,
    IVec4,
    Float,
    Vec2,
    Vec3,
    Vec4,
    Mat2,
    Mat3,
    Mat4,
    Channel, // a texture channel, which is sampled rather than evaluated
    Array, // a constant array, whose element type is tracked beside the name
    Struct // an aggregate the EDSL has no counterpart for at all
};

// Which of the three vocabularies a type belongs to. GLSL has no implicit
// conversion between them and neither does the EDSL, so this is what decides
// whether an expression needs a crossing written into it rather than a
// broadcast.
enum class Family
{
    Float,
    Int,
    Bool,
    Other // a matrix, a channel, an array - nothing that crosses or broadcasts
};

Family familyOf(Type type)
{
    switch (type)
    {
        case Type::Float:
        case Type::Vec2:
        case Type::Vec3:
        case Type::Vec4:
            return Family::Float;
        case Type::Int:
        case Type::IVec2:
        case Type::IVec3:
        case Type::IVec4:
            return Family::Int;
        case Type::Bool:
        case Type::BVec2:
        case Type::BVec3:
        case Type::BVec4:
            return Family::Bool;
        default:
            return Family::Other;
    }
}

// How many components a value has, and so how wide anything built beside it
// broadcasts to. Zero for everything outside the three families, which is what
// keeps a matrix out of the widening rule below.
int widthOf(Type type)
{
    switch (type)
    {
        case Type::Float:
        case Type::Int:
        case Type::Bool:
            return 1;
        case Type::Vec2:
        case Type::IVec2:
        case Type::BVec2:
            return 2;
        case Type::Vec3:
        case Type::IVec3:
        case Type::BVec3:
            return 3;
        case Type::Vec4:
        case Type::IVec4:
        case Type::BVec4:
            return 4;
        default:
            return 0;
    }
}

// The member of a family at a given width - what a swizzle of one lands in, and
// what a comparison of two yields.
Type vectorOf(Family family, int width)
{
    constexpr Type members[3][4] = {
        {Type::Float, Type::Vec2, Type::Vec3, Type::Vec4},
        {Type::Int, Type::IVec2, Type::IVec3, Type::IVec4},
        {Type::Bool, Type::BVec2, Type::BVec3, Type::BVec4},
    };

    if (family == Family::Other || width < 1 || width > 4)
        return Type::Unknown;

    return members[(int) family][width - 1];
}

bool isInteger(Type type)
{
    return familyOf(type) == Family::Int;
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
    return vectorOf(Family::Float, components);
}

Type typeFromGlslName(std::string_view name)
{
    if (name == "bool")
        return Type::Bool;
    if (name == "int")
        return Type::Int;
    if (name == "float")
        return Type::Float;
    if (name == "vec2")
        return Type::Vec2;
    if (name == "vec3")
        return Type::Vec3;
    if (name == "vec4")
        return Type::Vec4;
    if (name == "ivec2")
        return Type::IVec2;
    if (name == "ivec3")
        return Type::IVec3;
    if (name == "ivec4")
        return Type::IVec4;
    if (name == "bvec2")
        return Type::BVec2;
    if (name == "bvec3")
        return Type::BVec3;
    if (name == "bvec4")
        return Type::BVec4;
    if (name == "mat2")
        return Type::Mat2;
    if (name == "mat3")
        return Type::Mat3;
    if (name == "mat4")
        return Type::Mat4;

    return Type::Unknown;
}

// The EDSL's spelling of a vector constructor, and of the thing that anchors one
// built purely from literals: a value handle for the graph to be taken from,
// which a literal on its own is not. A boolean needs no entry - every `true` and
// `false` a port emits is already anchored where it is read.
const char* constructorName(Family family)
{
    switch (family)
    {
        case Family::Int:
            return "int";
        case Family::Bool:
            return "bool";
        default:
            return "float";
    }
}

const char* anchorName(Family family)
{
    return family == Family::Int ? "integer" : "constant";
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
    Boolean, // a mask collapsed to the one condition a branch can test
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

    // What collapses a mask into a condition. GLSL and both shading languages
    // agree on the names, so these pass straight through.
    {"any", "any", ResultShape::Boolean},
    {"all", "all", ResultShape::Boolean},

    // The two matrix operations both shading languages have. GLSL has a third
    // and neither of them does, which is why inverse is below rather than here.
    {"transpose", "transpose", ResultShape::LikeArg0},
    {"determinant", "determinant", ResultShape::Scalar},

    // Everything below is a gap: GLSL has it, the EDSL does not.
    {"inverse", nullptr, ResultShape::LikeArg0},
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
           || name == "texelFetch" || name == "textureGrad" || name == "textureSize";
}

// A Shadertoy has four texture channels, named iChannel0 to iChannel3.
constexpr auto channelCount = 4;

// The channel a name stands for, or -1 for anything else. Those four are the
// only samplers a shader ever sees, so a port needs no notion of a texture
// beyond which of them it is.
int channelIndex(const std::string& name)
{
    if (name.rfind("iChannel", 0) != 0 || name.size() != 9)
        return -1;

    auto channel = name.back() - '0';

    return channel >= 0 && channel < channelCount ? channel : -1;
}

// vec2/vec3/vec4, ivec2..4 and bvec2..4, each with an EDSL counterpart of the
// same width in the same family. Zero width for anything that is not one of the
// nine, which is what sends a matrix constructor down its own path.
int vectorConstructorWidth(const std::string& name)
{
    auto type = typeFromGlslName(name);
    auto width = familyOf(type) == Family::Other ? 0 : widthOf(type);

    // `float`, `int` and `bool` name the scalars, which are conversions rather
    // than constructors and are emitted as such.
    return width > 1 ? width : 0;
}

// The componentwise comparisons, which GLSL spells as calls because it reserves
// the operators for scalars. Both languages the EDSL emits into give the
// operator itself to a pair of vectors and yield a mask, so a port writes what
// the shader meant: lessThan(a, b) is a < b.
const char* comparisonOperator(const std::string& name)
{
    if (name == "lessThan")
        return "<";
    if (name == "lessThanEqual")
        return "<=";
    if (name == "greaterThan")
        return ">";
    if (name == "greaterThanEqual")
        return ">=";
    if (name == "equal")
        return "==";
    if (name == "notEqual")
        return "!=";

    return nullptr;
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

// C++ and GLSL agree on the precedence of every operator the port emits, so an
// expression that needed no parentheses in the source needs none in the port.
// Emitting them anyway is what turned a readable sum into a thicket.
// eacp's own column limit, so a generated header sits in the project without
// clang-format wanting to reflow it.
constexpr auto columnLimit = 85;

// Zero for an operator the port has no spelling for at all, so emitBinary
// reports it rather than emitting it. The order is C++'s, which is GLSL's:
// shifts below the additive operators, the bitwise set below equality and above
// the connectives.
int precedenceOf(const std::string& op)
{
    if (op == "*" || op == "/" || op == "%")
        return 10;

    if (op == "+" || op == "-")
        return 9;

    if (op == "<<" || op == ">>")
        return 8;

    if (op == "<" || op == ">" || op == "<=" || op == ">=")
        return 7;

    if (op == "==" || op == "!=")
        return 6;

    if (op == "&")
        return 5;

    if (op == "^")
        return 4;

    if (op == "|")
        return 3;

    if (op == "&&")
        return 2;

    if (op == "||")
        return 1;

    return 0;
}

// Whether an operator yields a bool rather than something shaped like its
// operands.
bool yieldsBool(const std::string& op)
{
    return op == "<" || op == ">" || op == "<=" || op == ">=" || op == "=="
           || op == "!=" || op == "&&" || op == "||";
}

// The operators GLSL defines on integers only. A shader reaching one over
// floats needs the integer type rather than the operator - mod() is what a
// float tiles with, and there is no float to take a complement of.
bool integerOnly(const std::string& op)
{
    return op == "%" || op == "&" || op == "|" || op == "^" || op == "<<"
           || op == ">>";
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

// A literal that sits beside an integer is spelled as one. GLSL truncates
// towards zero on the way into an int and so does the EDSL, so a literal that
// reached here with a fraction - from a fold, or from a shader that wrote 3.0
// where it meant 3 - loses it the same way.
std::string integerLiteral(double value)
{
    return std::to_string((long long) value);
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
        types["iFrame"] = Type::Int;
        types["iMouse"] = Type::Vec4;

        for (auto channel = 0; channel < channelCount; ++channel)
            types["iChannel" + std::to_string(channel)] = Type::Channel;
    }

    EmitResult run()
    {
        auto body = std::string {};

        for (const auto& statement: shader.statements)
            body += emitStatement(statement);

        body += emitResult();

        // The channels the port ends up declaring are the ones the code it
        // keeps reads, so they are counted before the dropped statements below
        // are walked: a channel only a discarded loop samples would be a
        // texture the draw has to bind and the shader never reads.
        auto channels = channelDeclarations();

        // Statements lowering could not keep are walked for what they need and
        // their text thrown away, so an unreachable loop still contributes every
        // intrinsic, swizzle and channel inside it to the coverage report.
        for (const auto& statement: shader.dropped)
            emitStatement(statement);

        auto result = EmitResult {};
        result.code = preamble(channels) + body + epilogue();
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

    std::string preamble(const std::string& channels) const
    {
        return "#pragma once\n\n#include <shadertoy/Shadertoy.h>\n\n"
               "// Generated by the ShaderToyEACP transpiler. Edit the GLSL this\n"
               "// came from, not this file.\n\n"
               "namespace Shadertoy::Ports\n{\n"
               "struct "
               + structName + " final : Program\n{\n" + channels + "    "
               + structName
               + "() { compile(); }\n\n"
                 "    GPU::Float4 mainImage(const GPU::Float2& "
               + shader.fragCoord + ") override\n    {\n";
    }

    // The channel members the port declares, in channel order. A port declares
    // the ones it reads and no others: every declared texture is one the draw
    // has to bind, so four unconditional channels would make a shader that
    // samples none of them carry four.
    std::string channelDeclarations() const
    {
        if (channelsUsed.empty())
            return {};

        auto declarations = std::string {};
        auto names = std::string {};

        for (auto channel: channelsUsed)
        {
            auto name = "iChannel" + std::to_string(channel);
            declarations += "    Channel " + name + ";\n";

            if (!names.empty())
                names += ", ";

            names += name;
        }

        return declarations + "\n    SHADERTOY_UNIFORMS(" + names + ")\n\n";
    }

    std::string epilogue() const
    {
        return "    }\n};\n} // namespace Shadertoy::Ports\n";
    }

    // The out parameter is an ordinary local as far as the port is concerned:
    // C++ locals rebind their handle on assignment, so every write GLSL makes to
    // fragColor is just another `=`, and the last value it holds is returned.
    // Unless a branch is what writes it, in which case it is a variable and the
    // read at the end is a read like any other.
    std::string emitResult()
    {
        if (types.count(shader.fragColor) != 0)
            return indent + "return " + readOf(shader.fragColor) + ";\n";

        if (wroteReturn)
            return {};

        report(DiagnosticKind::ParseError, "mainImage never writes fragColor");
        return indent + "return float4(constant(0.0f), 0.0f, 0.0f, 1.0f);\n";
    }

    // The name a value is read under. A mutable local is a Var, whose read is a
    // node of its own recorded where the read appears, so the port spells it
    // out rather than leaning on the implicit conversion - which keeps the
    // difference between a bound handle and a place visible in the source.
    std::string readOf(const std::string& name) const
    {
        return variables.count(name) != 0 ? name + "()" : name;
    }

    std::string emitBlock(int block)
    {
        if (block < 0)
            return {};

        auto saved = indent;
        indent += "    ";

        auto text = std::string {};

        for (const auto& statement: shader.block(block).statements)
            text += emitStatement(statement);

        indent = saved;
        return text;
    }

    std::string emitStatement(const Statement& statement)
    {
        currentLine = statement.line;

        switch (statement.kind)
        {
            case StatementKind::Return:
                return emitReturn(statement);

            case StatementKind::Declare:
                return emitDeclare(statement);

            case StatementKind::While:
                return emitLoop(statement);

            case StatementKind::If:
                return emitBranch(statement);

            case StatementKind::Break:
                return indent + "breakLoop();\n";

            case StatementKind::Continue:
                return indent + "continueLoop();\n";

            default:
                return emitAssign(statement);
        }
    }

    std::string emitReturn(const Statement& statement)
    {
        if (statement.value < 0)
        {
            report(DiagnosticKind::ControlFlow, "early return");
            return {};
        }

        wroteReturn = true;
        markIntegers(statement.value, false);
        return layout(indent + "return ", statement.value, ";");
    }

    // A constant array is one declaration and one value: the EDSL takes its
    // elements as a pack and its size from them, so the port says what the GLSL
    // said with none of the repetition around it.
    std::string emitArrayDeclare(const Statement& statement)
    {
        types[statement.name] = Type::Array;
        arrayElements[statement.name] = typeFromGlslName(statement.type);

        markIntegers(statement.value, false);

        return layout(
            indent + "auto " + statement.name + " = ", statement.value, ";");
    }

    std::string emitDeclare(const Statement& statement)
    {
        if (statement.isArray)
            return emitArrayDeclare(statement);

        auto declared = declaredType(statement.type);
        markIntegers(statement.value, isInteger(declared));

        if (statement.isVariable)
        {
            types[statement.name] =
                declared != Type::Unknown ? declared : typeOf(statement.value);
            variables.insert(statement.name);

            if (statement.value < 0)
                return indent + "auto " + statement.name + " = var("
                       + zeroOf(types[statement.name]) + ");\n";

            return layout(indent + "auto " + statement.name + " = var(",
                          statement.value,
                          ");");
        }

        // A declaration with no initialiser is spelled with a zero rather than
        // deferred to the assignment that follows, because a name can be read
        // before it is ever assigned: `vec4 q;` then `q.x = ...` rebuilds the
        // whole value out of the components it is not writing, and `vec2 ro;`
        // handed to a helper as an out parameter is bound by the inliner before
        // anything has been written to it. Both read a name that a deferred
        // declaration has not introduced yet. GLSL leaves the value undefined,
        // so the zero is a value it is free to have.
        if (statement.value < 0)
        {
            types[statement.name] = declared;

            return indent + "auto " + statement.name + " = " + zeroOf(declared)
                   + ";\n";
        }

        types[statement.name] =
            declared != Type::Unknown ? declared : typeOf(statement.value);

        return layoutValue(
            indent + "auto " + statement.name + " = ", statement.value, ";");
    }

    // A branch, and a loop, as the statements the EDSL spells them with: the
    // condition, then the body as a lambda recording into a block of its own.
    std::string emitBranch(const Statement& statement)
    {
        markIntegers(statement.condition, false);

        auto text = layout(indent + "ifThen(", statement.condition, ", [&]");
        text += indent + "{\n" + emitBlock(statement.body) + indent + "}";

        if (statement.elseBody >= 0)
            text += ",\n" + indent + "[&]\n" + indent + "{\n"
                    + emitBlock(statement.elseBody) + indent + "}";

        return text + ");\n";
    }

    std::string emitLoop(const Statement& statement)
    {
        markIntegers(statement.condition, false);

        auto text = layout(indent + "loop(", statement.condition, ", [&]");
        return text + indent + "{\n" + emitBlock(statement.body) + indent + "});\n";
    }

    std::string emitAssign(const Statement& statement)
    {
        if (types.count(statement.name) == 0)
        {
            // The first write to the out parameter, or to a name whose
            // declaration was skipped: introduce it here.
            types[statement.name] = statement.name == shader.fragColor
                                        ? Type::Vec4
                                        : typeOf(statement.value);
            markIntegers(statement.value, isInteger(types[statement.name]));

            return layoutValue(
                indent + "auto " + statement.name + " = ", statement.value, ";");
        }

        markIntegers(statement.value, isInteger(types[statement.name]));

        // `col += x` becomes `col = col + x`, with the right-hand side
        // parenthesised only where the compound operator would otherwise
        // rebind it: `col -= a + b` must not become `col = col - a + b`.
        if (!statement.op.empty())
        {
            auto read = readOf(statement.name);
            auto head = indent + statement.name + " = " + read;
            auto single =
                head + " " + statement.op + " "
                + emitOperand(statement.value, precedenceOf(statement.op), true)
                + ";";

            if ((int) single.size() <= columnLimit)
                return single + "\n";

            auto start = (int) indent.size() + 4 + (int) statement.op.size() + 1;

            return head + "\n" + indent + "    " + statement.op + " "
                   + layoutOperand(statement.value,
                                   start,
                                   indent + "        ",
                                   precedenceOf(statement.op),
                                   true)
                   + ";\n";
        }

        return layoutValue(indent + statement.name + " = ", statement.value, ";");
    }

    // The value a variable declared without one starts at, which GLSL leaves
    // undefined and the port has to spell. Every one of them is a handle rather
    // than a C++ literal, since this is what a plain declaration binds as well
    // as what a var() is opened with, and `auto x = 0.0f` would bind a float.
    std::string zeroOf(Type type)
    {
        switch (type)
        {
            case Type::Bool:
                return "boolean(false)";
            case Type::Int:
                return "integer(0)";
            case Type::Float:
                return "constant(0.0f)";
            case Type::Vec2:
                return "float2(constant(0.0f), 0.0f)";
            case Type::Vec3:
                return "float3(constant(0.0f), 0.0f, 0.0f)";
            case Type::Vec4:
                return "float4(constant(0.0f), 0.0f, 0.0f, 0.0f)";
            case Type::IVec2:
                return "int2(integer(0), 0)";
            case Type::IVec3:
                return "int3(integer(0), 0, 0)";
            case Type::IVec4:
                return "int4(integer(0), 0, 0, 0)";
            case Type::BVec2:
                return "bool2(boolean(false), false)";
            case Type::BVec3:
                return "bool3(boolean(false), false, false)";
            case Type::BVec4:
                return "bool4(boolean(false), false, false, false)";
            case Type::Mat2:
                return "float2x2(" + zeroOf(Type::Vec2) + ", " + zeroOf(Type::Vec2)
                       + ")";
            case Type::Mat3:
                return "float3x3(" + zeroOf(Type::Vec3) + ", " + zeroOf(Type::Vec3)
                       + ", " + zeroOf(Type::Vec3) + ")";
            case Type::Mat4:
                return "float4x4(" + zeroOf(Type::Vec4) + ", " + zeroOf(Type::Vec4)
                       + ", " + zeroOf(Type::Vec4) + ", " + zeroOf(Type::Vec4) + ")";
            default:
                break;
        }

        report(DiagnosticKind::UnsupportedType, "uninitialised variable");
        return "0.0f";
    }

    // --- layout ----------------------------------------------------------

    // Everything below exists because an inlined body arrives as one
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
            layoutExpression(node, column, (int) suffix.size(), indent + "    ");
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
        auto precedence = precedenceOf(operatorOf(node));

        if (precedence > 0)
        {
            auto terms = Vector<std::pair<std::string, int>> {};
            flattenChain(node, precedence, terms);

            if (terms.size() >= 2)
                return layoutChain(terms, column, trailing, indent, precedence);
        }

        if (expr.kind == ExprKind::Call && !expr.args.empty())
        {
            auto call = wrappableCall(node, expr);

            if (!call.columns.empty())
                return layoutColumns(
                    call.callee, call.columns, column, trailing, indent);

            if (!call.callee.empty())
                return layoutCall(
                    call.callee, call.arguments, column, trailing, indent);
        }

        // A ternary emits as select(condition, whenTrue, whenFalse) over the
        // three nodes it was parsed with, which is exactly the shape the call
        // layout re-walks - and an array literal is array(e0, e1, ...) over
        // its elements, which is the same shape again. A palette is the one
        // thing here that reliably runs long, so this is what it needs.
        if (expr.kind == ExprKind::Ternary)
            return layoutCall("select", expr.args, column, trailing, indent);

        if (expr.kind == ExprKind::ArrayLiteral && !expr.args.empty())
            return layoutCall("array", expr.args, column, trailing, indent);

        return single;
    }

    // What a call emits as, when it emits as name(a, b, ...) over nodes this
    // layout can re-walk. The nodes are usually the ones it was parsed with, and
    // the callee empty for a call that has no such form at all - a constructor
    // that anchors itself with constant(), or one whose components have to cross
    // vocabularies on the way in. Those stay on one line.
    struct WrappableCall
    {
        std::string callee {};
        Vector<int> arguments {};

        // A call whose arguments are text rather than nodes, because what it
        // emits is not what it was parsed with: a matrix constructor takes the
        // columns and GLSL spells the components. A column is short - four
        // components at the most - so it is laid out whole and the break goes
        // between them.
        Vector<std::string> columns {};
    };

    WrappableCall wrappableCall(int node, const Expr& expr)
    {
        auto width = vectorConstructorWidth(expr.text);

        if (width > 0)
            return wrappableConstructor(node, expr, width);

        auto matrix = typeFromGlslName(expr.text);

        if (matrixOrder(matrix) > 0)
            return {edslMatrixName(matrix), {}, matrixColumns(expr, matrix)};

        if (isTextureCall(expr.text))
            return {passthroughTextureCall(expr), expr.args};

        const auto* builtin = findBuiltin(expr.text);

        if (builtin == nullptr || builtin->edsl == nullptr)
            return {};

        auto callee = builtin->edslBinary != nullptr && expr.args.size() == 2
                          ? builtin->edslBinary
                          : builtin->edsl;

        return {callee, expr.args};
    }

    WrappableCall wrappableConstructor(int node, const Expr& expr, int width)
    {
        auto family = familyOf(typeFromGlslName(expr.text));

        if (!mentionsAName(node))
            return {};

        for (auto argument: expr.args)
            if (!readsInFamily(argument, family))
                return {};

        auto callee = constructorName(family) + std::to_string(width);

        // A scalar spread across every component is the one constructor whose
        // emitted arguments are not the ones it was parsed with: it is the same
        // node, `width` times. Saying that is all the layout needs to break one
        // - and without it a broadcast of anything but a short name is the one
        // shape that could still run past the column limit.
        if (isBroadcast(expr, width))
        {
            auto repeated = Vector<int> {};

            for (auto index = 0; index < width; ++index)
                repeated.add(expr.args[0]);

            return {callee, repeated};
        }

        return {callee, expr.args};
    }

    // The same test emitVectorConstructor makes, kept beside the layout that
    // has to rebuild what it produced.
    bool isBroadcast(const Expr& expr, int width)
    {
        return expr.args.size() == 1 && width > 1
               && widthOf(typeOf(expr.args[0])) == 1;
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
                           const Vector<int>& arguments,
                           int column,
                           int trailing,
                           const std::string& indent)
    {
        auto inner = indent + "    ";
        auto text = callee + "(";
        auto at = column + (int) text.size();

        for (auto index = 0; index < arguments.size(); ++index)
        {
            auto last = index + 1 == arguments.size();
            auto separator = last ? std::string {} : std::string {","};
            auto reserved = (int) separator.size() + (last ? trailing + 1 : 0);
            auto argument = emitExpression(arguments[index]);

            if (at + (int) argument.size() + reserved > columnLimit)
            {
                // The space after the previous comma belongs to an argument
                // that turned out to start on the next line instead.
                if (!text.empty() && text.back() == ' ')
                    text.pop_back();

                text += "\n" + indent;
                at = (int) indent.size();
                argument = layoutExpression(arguments[index], at, reserved, inner);
            }

            text += argument + separator + (last ? "" : " ");
            at = columnAfter(argument, at) + (int) separator.size() + (last ? 0 : 1);
        }

        return text + ")";
    }

    // The same break as layoutCall over arguments that have already been
    // emitted, since a regrouped one has no node left to walk back into.
    std::string layoutColumns(const std::string& callee,
                              const Vector<std::string>& columns,
                              int column,
                              int trailing,
                              const std::string& indent)
    {
        auto text = callee + "(";
        auto at = column + (int) text.size();

        for (auto index = 0; index < columns.size(); ++index)
        {
            auto last = index + 1 == columns.size();
            auto separator = last ? std::string {} : std::string {","};
            auto reserved = (int) separator.size() + (last ? trailing + 1 : 0);

            if (at + (int) columns[index].size() + reserved > columnLimit)
            {
                if (!text.empty() && text.back() == ' ')
                    text.pop_back();

                text += "\n" + indent;
                at = (int) indent.size();
            }

            text += columns[index] + separator + (last ? "" : " ");
            at += (int) columns[index].size() + (int) separator.size()
                  + (last ? 0 : 1);
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
        auto precedence = precedenceOf(operatorOf(node));

        if (precedence == 0)
            return false;

        return precedence < parentPrecedence
               || (onTheRight && precedence == parentPrecedence);
    }

    // The operator a node emits as, whether the GLSL wrote it as one or as the
    // call GLSL makes a componentwise comparison. Empty for anything that is not
    // an operator at all - which is what the parenthesising and the wrapping
    // paths both key on, so a comparison written as a call is grouped by the
    // same rules as the `<` a scalar one is written with.
    std::string operatorOf(int node) const
    {
        if (node < 0)
            return {};

        const auto& expr = shader.expr(node);

        if (expr.kind == ExprKind::Binary)
            return expr.text;

        if (expr.kind == ExprKind::Call && expr.args.size() == 2)
            if (const auto* spelling = comparisonOperator(expr.text))
                return spelling;

        return {};
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
        auto op = operatorOf(node);

        if (precedenceOf(op) == precedence)
        {
            const auto& expr = shader.expr(node);

            flattenChain(expr.args[0], precedence, terms);
            terms.add({op, expr.args[1]});
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
                if (expr.text == "true" || expr.text == "false")
                    return Type::Bool;

                auto found = types.find(expr.text);
                return found != types.end() ? found->second : Type::Unknown;
            }

            case ExprKind::Unary:
                return expr.text == "!" ? Type::Bool : typeOf(expr.args[0]);

            case ExprKind::Binary:
            {
                if (yieldsBool(expr.text))
                    return Type::Bool;

                auto left = typeOf(expr.args[0]);
                auto right = typeOf(expr.args[1]);

                // An integer beside an integer literal is still an integer.
                // GLSL has no implicit conversion between the two vocabularies
                // and neither does the EDSL, so nothing here widens one out of
                // its family - only within it, where a vector next to a scalar
                // broadcasts exactly as the EDSL's operators do.
                if (isInteger(left) || isInteger(right))
                    return vectorOf(Family::Int,
                                    std::max(widthOf(left), widthOf(right)));

                return widthOf(left) >= widthOf(right) ? left : right;
            }

            case ExprKind::Ternary:
                return typeOf(expr.args[1]);

            case ExprKind::Member:
                return swizzleType(expr);

            case ExprKind::Index:
                return typeOfIndex(expr);

            case ExprKind::ArrayLiteral:
                return Type::Array;

            case ExprKind::Call:
                return typeOfCall(expr);
        }

        return Type::Unknown;
    }

    // A type by name, over the built-in vocabulary plus whatever structs the
    // shader declared - none of which the EDSL can express, which is exactly
    // what naming them is for.
    Type declaredType(const std::string& name) const
    {
        return shader.isStructType(name) ? Type::Struct : typeFromGlslName(name);
    }

    // What a swizzle reads: the family of what it was taken from, at the width
    // it names. `.x` of an ivec2 is an int and has to cross into float
    // arithmetic explicitly, the way the GLSL that wrote it had to.
    //
    // Unless what it was taken from is a struct, in which case this is a field
    // and the gap is the aggregate rather than the components named.
    Type swizzleType(const Expr& expr)
    {
        if (typeOf(expr.args[0]) == Type::Struct)
            return Type::Unknown;

        auto width = (int) expr.text.size();
        auto family = familyOf(typeOf(expr.args[0]));

        return family == Family::Other ? typeOfWidth(width)
                                       : vectorOf(family, width);
    }

    // What a subscript reads. iChannelResolution is the one array a Shadertoy
    // indexes without declaring; everything else is a name the port declared as
    // an array, and the element type is what it was declared with.
    Type typeOfIndex(const Expr& expr)
    {
        if (channelResolutionIndex(expr) >= 0)
            return Type::Vec3;

        auto element = arrayElements.find(nameOfArray(expr));
        return element != arrayElements.end() ? element->second : Type::Unknown;
    }

    // The name a subscript reads out of, empty when the object is not one the
    // port declared as an array.
    std::string nameOfArray(const Expr& expr) const
    {
        const auto& object = shader.expr(expr.args[0]);

        if (object.kind != ExprKind::Identifier
            || arrayElements.count(object.text) == 0)
            return {};

        return object.text;
    }

    Type typeOfCall(const Expr& expr)
    {
        // A channel read is an RGBA texel whichever form it took, and
        // textureSize is the one that is not a read at all.
        if (isTextureCall(expr.text))
            return expr.text == "textureSize" ? Type::Vec2 : Type::Vec4;

        // A componentwise comparison is a mask as wide as what it compared.
        if (comparisonOperator(expr.text) != nullptr && expr.args.size() == 2)
            return vectorOf(Family::Bool, widthOf(typeOf(expr.args[0])));

        // not() negates a mask, so it is shaped like the one it was given.
        if (expr.text == "not" && expr.args.size() == 1)
            return typeOf(expr.args[0]);

        auto declared = declaredType(expr.text);

        if (declared != Type::Unknown)
            return declared;

        const auto* builtin = findBuiltin(expr.text);

        if (builtin == nullptr)
            return Type::Unknown;

        switch (builtin->shape)
        {
            case ResultShape::Scalar:
                return Type::Float;
            case ResultShape::Boolean:
                return Type::Bool;
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

    // Which literals in a subtree are spelled as integers. Where a literal sits
    // is what decides it, not the literal itself: `index & 3` needs a 3 and
    // `int(uv.x * 4.0)` needs a 4.0f, and the same node kind carries both.
    //
    // Walked once per statement, immediately before that statement is emitted,
    // because the types it reads are the ones the statements above it left
    // behind. The result is a set of nodes rather than a flag threaded through
    // emission, so the line-wrapping path - which re-walks the same nodes -
    // reaches the same answer without knowing this exists.
    void markIntegers(int node, bool integer)
    {
        if (node < 0)
            return;

        const auto& expr = shader.expr(node);

        switch (expr.kind)
        {
            case ExprKind::Number:
                if (integer)
                    integerLiterals.insert(node);

                return;

            case ExprKind::Identifier:
                return;

            case ExprKind::Unary:
                markIntegers(expr.args[0], isInteger(typeOf(expr.args[0])));
                return;

            case ExprKind::Binary:
            {
                // Either operand being an integer settles it for both, which is
                // what puts the 3 in `index & 3` and in `3 & index` alike.
                auto operands = integer || isInteger(typeOf(expr.args[0]))
                                || isInteger(typeOf(expr.args[1]));

                markIntegers(expr.args[0], operands);
                markIntegers(expr.args[1], operands);
                return;
            }

            case ExprKind::Ternary:
                markIntegers(expr.args[0], false);
                markIntegers(expr.args[1], integer);
                markIntegers(expr.args[2], integer);
                return;

            case ExprKind::Member:
                markIntegers(expr.args[0], isInteger(typeOf(expr.args[0])));
                return;

            case ExprKind::Index:
                markIntegers(expr.args[0], false);
                markIntegers(expr.args[1], !nameOfArray(expr).empty());
                return;

            case ExprKind::ArrayLiteral:
                for (auto argument: expr.args)
                    markIntegers(argument, isInteger(typeFromGlslName(expr.text)));

                return;

            case ExprKind::Call:
            {
                // A vector constructor decides its arguments one at a time
                // rather than all together: ivec2(fragCoord / 16.0) converts a
                // float pair, while ivec2(cell.x, 1) has a literal in it that
                // has to be spelled as an integer.
                auto width = vectorConstructorWidth(expr.text);

                if (width > 0)
                {
                    auto family = familyOf(typeFromGlslName(expr.text));

                    for (auto argument: expr.args)
                        markIntegers(argument,
                                     family == Family::Int
                                         && readsInFamily(argument, family));

                    return;
                }

                // A conversion's argument is in the other vocabulary by
                // definition, which is the whole reason it is written.
                auto arguments = !isConversion(expr.text) && takesIntegers(expr);

                for (auto argument: expr.args)
                    markIntegers(argument, arguments);

                return;
            }
        }
    }

    // Whether an argument filling a component already reads in the family being
    // built, so that no crossing has to be written around it. A literal counts:
    // which vocabulary a number is spelled in is decided by where it sits, which
    // is what markIntegers is for.
    bool readsInFamily(int node, Family family)
    {
        return familyOf(typeOf(node)) == family || !mentionsAName(node);
    }

    static bool isConversion(const std::string& callee)
    {
        return callee == "int" || callee == "uint" || callee == "float"
               || callee == "bool";
    }

    bool takesIntegers(const Expr& expr)
    {
        for (auto argument: expr.args)
            if (isInteger(typeOf(argument)))
                return true;

        return false;
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

        return needsParentheses(node, parentPrecedence, onTheRight)
                   ? "(" + text + ")"
                   : text;
    }

    std::string emitExpression(int node)
    {
        if (node < 0)
            return "0.0f";

        const auto& expr = shader.expr(node);

        switch (expr.kind)
        {
            case ExprKind::Number:
                return integerLiterals.count(node) != 0 ? integerLiteral(expr.value)
                                                        : floatLiteral(expr.value);

            case ExprKind::Identifier:
                return emitIdentifier(expr);

            case ExprKind::Unary:
                return emitUnary(expr);

            case ExprKind::Binary:
                return emitBinary(expr);

            case ExprKind::Member:
                return emitMember(expr);

            case ExprKind::Ternary:
                // Both sides are values the port has already computed, so the
                // ternary picks between them rather than skipping one - which
                // is what select() is, and what the shading languages emit for
                // the conditional operator too.
                return "select(" + emitArguments(expr) + ")";

            case ExprKind::Index:
                return emitIndex(expr);

            case ExprKind::ArrayLiteral:
                return "array(" + emitArguments(expr) + ")";

            case ExprKind::Call:
                return emitCall(node, expr);
        }

        return "0.0f";
    }

    std::string emitIdentifier(const Expr& expr)
    {
        auto channel = channelIndex(expr.text);

        if (channel >= 0)
        {
            channelsUsed.insert(channel);
            return expr.text;
        }

        // A boolean literal has no graph of its own to record into, the way a
        // float literal has none - boolean() is what anchors it.
        if (expr.text == "true" || expr.text == "false")
            return "boolean(" + expr.text + ")";

        if (types.count(expr.text) != 0)
            return readOf(expr.text);

        report(DiagnosticKind::UnknownIdentifier, expr.text);
        return "/* unresolved: " + expr.text + " */ " + expr.text;
    }

    // iChannelResolution is the one array a Shadertoy reads, and only ever at a
    // literal index - so it needs no array type, just the size the channel at
    // that index already carries. Every other subscript is the gap it was.
    int channelResolutionIndex(const Expr& expr) const
    {
        const auto& object = shader.expr(expr.args[0]);
        const auto& index = shader.expr(expr.args[1]);

        if (object.kind != ExprKind::Identifier
            || object.text != "iChannelResolution" || index.kind != ExprKind::Number)
            return -1;

        auto channel = (int) index.value;

        return channel >= 0 && channel < channelCount ? channel : -1;
    }

    std::string emitIndex(const Expr& expr)
    {
        auto channel = channelResolutionIndex(expr);

        if (channel >= 0)
        {
            channelsUsed.insert(channel);
            return "iChannel" + std::to_string(channel) + ".resolution";
        }

        // A subscript of a name the port declared as an array is the EDSL's
        // own, so it is spelled exactly as the GLSL wrote it. Anything else -
        // a matrix column, a swizzle written as an index - is the gap it was.
        if (!nameOfArray(expr).empty())
            return emitExpression(expr.args[0]) + "[" + emitExpression(expr.args[1])
                   + "]";

        report(DiagnosticKind::UnsupportedType, "indexing");
        return "/* unsupported: [] */ (" + emitExpression(expr.args[0]) + ")";
    }

    std::string emitUnary(const Expr& expr)
    {
        auto operand = emitExpression(expr.args[0]);
        auto compound = shader.expr(expr.args[0]).kind == ExprKind::Binary;

        if (expr.text == "-")
            return compound ? "-(" + operand + ")" : "-" + operand;

        if (expr.text == "+")
            return operand;

        if (expr.text == "!")
            return "!(" + operand + ")";

        // What is left is `~`, the one unary operator no float has.
        if (expr.text == "~" && isInteger(typeOf(expr.args[0])))
            return compound ? "~(" + operand + ")" : "~" + operand;

        report(DiagnosticKind::UnsupportedType, "int " + expr.text);
        return "/* unsupported: " + expr.text + " */ (" + operand + ")";
    }

    std::string emitBinary(const Expr& expr)
    {
        auto precedence = precedenceOf(expr.text);
        auto left = emitOperand(expr.args[0], precedence, false);
        auto right = emitOperand(expr.args[1], precedence, true);

        // %, the bitwise set and the shifts are defined on integers only, so a
        // shader reaching one over floats needs the integer type rather than
        // the operator - mod() is what a float tiles with.
        auto integer =
            isInteger(typeOf(expr.args[0])) || isInteger(typeOf(expr.args[1]));

        if (precedence > 0 && (integer || !integerOnly(expr.text)))
        {
            // GLSL's == and != on two vectors compare the whole value and yield
            // one bool; it is equal() and notEqual() that are componentwise,
            // and those arrive as calls. Both languages under the EDSL give the
            // operator itself to a pair of vectors and yield a mask instead, so
            // what says what the shader said is that mask collapsed.
            auto wide = widthOf(typeOf(expr.args[0])) > 1
                        && widthOf(typeOf(expr.args[1])) > 1;

            if (wide && (expr.text == "==" || expr.text == "!="))
            {
                auto collapse = expr.text == "==" ? "all(" : "any(";
                return collapse + left + " " + expr.text + " " + right + ")";
            }

            return left + " " + expr.text + " " + right;
        }

        report(DiagnosticKind::UnsupportedType, "int " + expr.text);
        return "/* unsupported: " + expr.text + " */ (" + left + ")";
    }

    // A swizzle binds tighter than any operator, so an object that emitted as
    // one has to be grouped before it: `(a + b).xy()` reads the sum and
    // `a + b.xy()` reads b. GLSL needed the same parentheses to say the first
    // of those, and leaving them out here is the difference between the two.
    std::string emitPostfixObject(int node)
    {
        auto grouped =
            shader.expr(node).kind == ExprKind::Unary || !operatorOf(node).empty();
        auto text = emitExpression(node);

        return grouped ? "(" + text + ")" : text;
    }

    std::string emitMember(const Expr& expr)
    {
        auto object = emitPostfixObject(expr.args[0]);

        // A field of a struct is not a swizzle that happens to be spelled
        // oddly: what is missing is the aggregate it was read out of, which is
        // already reported where the struct was declared.
        if (typeOf(expr.args[0]) == Type::Struct)
            return "/* unsupported: struct field */ " + object;

        // One component of a scalar is the scalar. Nothing in GLSL spells that
        // and nothing here parses it: what produces one is the rebuild a write
        // to part of a value becomes, which reads a component per slot it
        // fills - and a scalar right-hand side is broadcast across all of them.
        // `p.xy += 0.05 * iTime` adds the one value to both components.
        if (expr.text.size() == 1 && widthOf(typeOf(expr.args[0])) == 1)
            return object;

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
            return emitVectorCall(node, expr, width);

        // `float(x)` is a conversion, and over a float it is the identity -
        // usually of a literal the folding has already worked out. The
        // parentheses stay where dropping them would
        // re-bind the expression around it; over anything else it is a crossing
        // between vocabularies, which the EDSL spells out. A condition is one
        // of those - `float(a > b)` is 1.0 or 0.0 and is what a shader counting
        // how many of its tests passed adds up - and treating it as the
        // identity left a bool where a number was wanted.
        if (expr.text == "float" && expr.args.size() == 1)
        {
            auto inner = emitExpression(expr.args[0]);

            if (familyOf(typeOf(expr.args[0])) != Family::Float)
                return "toFloat(" + inner + ")";

            auto grouped = shader.expr(expr.args[0]).kind == ExprKind::Binary
                           || shader.expr(expr.args[0]).kind == ExprKind::Ternary;

            return grouped ? "(" + inner + ")" : inner;
        }

        // And the crossing the other way, which truncates towards zero in the
        // EDSL exactly as it does in GLSL. Over something already an integer it
        // is the identity, the way float() is over a float.
        if (expr.text == "int" && expr.args.size() == 1)
        {
            auto inner = emitExpression(expr.args[0]);
            return isInteger(typeOf(expr.args[0])) ? inner : "toInt(" + inner + ")";
        }

        // `uint` has no fragment-stage counterpart - the EDSL's unsigned type is
        // the compute thread id - and `bool(x)` has no spelling at all. The
        // unsigned vectors go with the scalar, for the same reason.
        if (expr.text == "uint" || expr.text == "bool"
            || expr.text.rfind("uvec", 0) == 0)
        {
            report(DiagnosticKind::UnsupportedType, expr.text);
            return "/* unsupported: " + expr.text + " */ " + emitArguments(expr);
        }

        // A componentwise comparison is the operator itself here, so it is laid
        // out and parenthesised as one - see operatorOf.
        if (const auto* spelling = comparisonOperator(expr.text))
            if (expr.args.size() == 2)
            {
                auto precedence = precedenceOf(spelling);

                return emitOperand(expr.args[0], precedence, false) + " " + spelling
                       + " " + emitOperand(expr.args[1], precedence, true);
            }

        // And so is not(), which GLSL spells as a call for want of an operator
        // it can overload.
        if (expr.text == "not" && expr.args.size() == 1)
            return "!(" + emitExpression(expr.args[0]) + ")";

        // Likewise its constructor, which would otherwise read as a call to a
        // helper the port could not find.
        if (shader.isStructType(expr.text))
            return "/* unsupported: struct */ " + emitArguments(expr);

        if (isTextureCall(expr.text))
            return emitTextureCall(expr);

        auto matrix = typeFromGlslName(expr.text);

        if (matrixOrder(matrix) > 0)
            return emitMatrixConstructor(expr, matrix);

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

    // The channel reads. texture() is the whole of what most Shadertoys use;
    // textureLod picks the mip level rather than taking the one the derivatives
    // imply, and texelFetch addresses texels instead of the unit square and
    // goes past the sampler entirely.
    std::string emitTextureCall(const Expr& expr)
    {
        // A first argument that is not one of the four channels is a sampler
        // the shader passed around - through a helper the port could not
        // inline, or an array of them - and there is nothing to sample.
        if (expr.args.empty() || channelIndex(shader.expr(expr.args[0]).text) < 0)
        {
            report(DiagnosticKind::UnsupportedTexture, expr.text);
            return unsampled(expr);
        }

        auto channel = emitExpression(expr.args[0]);

        if (!passthroughTextureCall(expr).empty())
            return "sample(" + channel + ", " + emitExpression(expr.args[1])
                   + (expr.args.size() > 2 ? ", " + emitExpression(expr.args[2])
                                           : std::string {})
                   + ")";

        if (expr.text == "texelFetch" && expr.args.size() >= 2)
        {
            // GPU::Texture holds one mip level, so a fetch of any other is a
            // read of something that is not there rather than a spelling the
            // EDSL is missing.
            if (expr.args.size() > 2 && !isZeroLiteral(expr.args[2]))
                report(DiagnosticKind::UnsupportedTexture, "texelFetch level");

            return "fetch(" + channel + ", " + emitFetchCoordinates(expr.args[1])
                   + ")";
        }

        // What is left is a form the EDSL has no node for: a sampling bias, the
        // explicit-gradient sample, and the texture's own dimensions - which a
        // port reads from the channel's resolution instead.
        report(DiagnosticKind::UnsupportedTexture,
               expr.text == "texture" ? "texture bias" : expr.text);

        return unsampled(expr);
    }

    // The name a channel read emits under when it hands its arguments straight
    // to the EDSL - the only shape the wrapping layout can rebuild, since that
    // re-walks the argument nodes rather than the text emitTextureCall
    // produced. A fetch rewrites its coordinate and has no such form.
    std::string passthroughTextureCall(const Expr& expr) const
    {
        if (expr.args.empty() || channelIndex(shader.expr(expr.args[0]).text) < 0)
            return {};

        auto plain = (expr.text == "texture" || expr.text == "texture2D")
                     && expr.args.size() == 2;

        return plain || (expr.text == "textureLod" && expr.args.size() == 3)
                   ? "sample"
                   : std::string {};
    }

    // What a channel read that could not be lowered leaves behind: opaque
    // black, the colour a Shadertoy channel with nothing bound to it samples
    // as. It never compiles into a port - the diagnostic above already stops
    // that - but it keeps the surrounding expression well formed so the rest of
    // the shader still reports what it needs.
    static std::string unsampled(const Expr& expr)
    {
        return "/* unsupported: " + expr.text
               + " */ float4(constant(0.0f), 0.0f, 0.0f, 1.0f)";
    }

    bool isZeroLiteral(int node) const
    {
        return node >= 0 && shader.expr(node).kind == ExprKind::Number
               && shader.expr(node).value == 0.0;
    }

    // texelFetch takes an ivec2 in GLSL and the EDSL now has one, so the
    // coordinate crosses as what it was written as. A shader that hands it a
    // float pair instead still works: fetch() takes one of those too, and it
    // truncates towards zero exactly as the ivec2 conversion would have.
    std::string emitFetchCoordinates(int node)
    {
        const auto& expr = shader.expr(node);

        // uvec2 is the one spelling with nowhere to land: the EDSL's unsigned
        // type is the compute thread id.
        if (expr.kind == ExprKind::Call && expr.text == "uvec2")
        {
            report(DiagnosticKind::UnsupportedType, expr.text);
            return emitArguments(expr);
        }

        return emitExpression(node);
    }

    // GLSL fills a matrix column by column, from either one column vector per
    // column, or every component in column order, or a single scalar on the
    // diagonal. The EDSL's constructors take the columns, so only the middle
    // form has to be regrouped - which is also why this hands back the columns
    // rather than the finished call: regrouped, they are no longer the argument
    // nodes the wrapping path knows how to re-walk. Empty for a matrix built in
    // none of the three ways.
    Vector<std::string> matrixColumns(const Expr& expr, Type type)
    {
        auto order = matrixOrder(type);
        auto columns = Vector<std::string> {};

        // One column vector per column: each argument already emits as a
        // value, and one built only from literals anchors itself.
        if ((int) expr.args.size() == order && typeOf(expr.args[0]) != Type::Float)
        {
            for (auto arg: expr.args)
                columns.add(emitExpression(arg));

            return columns;
        }

        auto components = Vector<std::string> {};
        auto named = Vector<int> {};

        if ((int) expr.args.size() == order * order)
        {
            for (auto arg: expr.args)
            {
                components.add(emitExpression(arg));
                named.add(mentionsAName(arg) ? 1 : 0);
            }
        }
        else if (expr.args.size() == 1 && typeOf(expr.args[0]) == Type::Float)
        {
            // mat2(s) puts s down the diagonal and zero everywhere else.
            auto scalar = emitExpression(expr.args[0]);
            auto isName = mentionsAName(expr.args[0]);

            for (auto column = 0; column < order; ++column)
                for (auto row = 0; row < order; ++row)
                {
                    components.add(row == column ? scalar : "0.0f");
                    named.add(row == column && isName ? 1 : 0);
                }
        }
        else
        {
            return columns;
        }

        auto columnName = "float" + std::to_string(order);

        for (auto column = 0; column < order; ++column)
        {
            auto first = column * order;

            // Like a vector built only from literals, a column built only from
            // them has no value handle to take a graph from - see
            // emitVectorConstructor. The regrouping is what makes this per
            // column rather than once: each column is a constructor of its own,
            // so a matrix whose names all land in one of them leaves the others
            // needing an anchor apiece.
            auto anchor = true;

            for (auto row = 0; row < order; ++row)
                anchor = anchor && named[first + row] == 0;

            auto parts = std::string {};

            for (auto row = 0; row < order; ++row)
            {
                const auto& component = components[first + row];

                parts += (row > 0 ? ", " : "")
                         + (anchor && row == 0 ? "constant(" + component + ")"
                                               : component);
            }

            columns.add(columnName + "(" + parts + ")");
        }

        return columns;
    }

    std::string emitMatrixConstructor(const Expr& expr, Type type)
    {
        auto columns = matrixColumns(expr, type);

        if (columns.empty())
        {
            report(DiagnosticKind::UnsupportedType, expr.text);
            return "/* unsupported: " + expr.text + " */ " + emitArguments(expr);
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

    // `ivec2(fragCoord / 16.0)` is not a constructor at all - it is the whole
    // value crossing into the other vocabulary, which the EDSL spells as one
    // call rather than a component at a time. Same width, other family, one
    // argument: that is the shape a conversion has, whichever way it goes.
    std::string emitVectorCall(int node, const Expr& expr, int width)
    {
        auto family = familyOf(typeFromGlslName(expr.text));

        if (expr.args.size() == 1)
        {
            auto argument = typeOf(expr.args[0]);

            if (widthOf(argument) == width && familyOf(argument) != family)
            {
                if (family == Family::Int && familyOf(argument) == Family::Float)
                    return "toInt(" + emitExpression(expr.args[0]) + ")";

                if (family == Family::Float && isInteger(argument))
                    return "toFloat(" + emitExpression(expr.args[0]) + ")";
            }

            // And a value already of the right shape converts to itself.
            if (argument == vectorOf(family, width))
                return emitExpression(expr.args[0]);
        }

        return emitVectorConstructor(node, expr, width, family);
    }

    // One component of a constructor, crossed into the family being built where
    // it is not already in it - which is what GLSL does implicitly inside a
    // constructor and the EDSL makes explicit everywhere.
    std::string emitComponent(int node, Family family)
    {
        auto text = emitExpression(node);

        if (readsInFamily(node, family))
            return text;

        if (family == Family::Int)
            return "toInt(" + text + ")";

        if (family == Family::Float && isInteger(typeOf(node)))
            return "toFloat(" + text + ")";

        return text;
    }

    std::string
        emitVectorConstructor(int node, const Expr& expr, int width, Family family)
    {
        auto name = constructorName(family) + std::to_string(width);
        auto parts = Vector<std::string> {};

        // GLSL broadcasts a lone scalar across the whole vector; the EDSL's
        // constructors take one argument per component, so the scalar is
        // repeated. It is emitted rather than bound to a temporary, so a
        // complex argument is recorded once per component - correct, but worth
        // knowing when reading the generated graph.
        if (expr.args.size() == 1 && widthOf(typeOf(expr.args[0])) == 1 && width > 1)
        {
            auto scalar = emitComponent(expr.args[0], family);

            for (auto index = 0; index < width; ++index)
                parts.add(scalar);
        }
        else
        {
            for (auto arg: expr.args)
                parts.add(emitComponent(arg, family));
        }

        // A constructor built purely from literals has no value handle to take
        // a graph from, and the EDSL rejects it. Anchoring the first component
        // gives it one without changing what it evaluates to. A boolean needs no
        // anchor: every literal one is already read through boolean().
        if (!mentionsAName(node) && !parts.empty() && family != Family::Bool)
            parts[0] = anchorName(family) + std::string {"("} + parts[0] + ")";

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

    // The element type of every name declared as a constant array, which is
    // what a subscript of it reads and what the array's own type does not say.
    std::map<std::string, Type> arrayElements;

    std::set<std::string> variables; // the locals declared with var()
    std::set<int> integerLiterals; // the numbers spelled 3 rather than 3.0f
    std::set<int> channelsUsed;
    Vector<Diagnostic> diagnostics;

    // Where the statement being emitted sits. A body nested in a loop or a
    // branch is one level further in, and the wrapping layout measures its
    // columns from here.
    std::string indent = "        ";

    int currentLine = 0;
    bool wroteReturn = false;
};
} // namespace

EmitResult emit(const Glsl::Shader& shader, const std::string& structName)
{
    return Emitter {shader, structName}.run();
}
} // namespace Shadertoy::Cpp
