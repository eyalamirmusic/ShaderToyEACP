#pragma once

#include "Common.h"

namespace Shadertoy::Glsl
{
enum class ExprKind
{
    Number, // value
    Identifier, // text = the name
    Binary, // text = the operator, args = {lhs, rhs}
    Unary, // text = the operator, args = {operand}
    Call, // text = the callee, args = the arguments
    Member, // text = the components, args = {object}
    Ternary, // args = {condition, whenTrue, whenFalse}
    Index, // args = {object, index}
    ArrayLiteral // text = the element type, args = the elements. GLSL spells an
    // array's contents as a constructor - `vec3[4](a, b, c, d)` - so this is a
    // call in the grammar and a value everywhere after it.
};

enum class StatementKind
{
    Declare, // type name = value
    Assign, // name op= value
    Return, // value, or -1 for a bare `return;`
    For, // init / condition / step / body
    While, // condition / body
    If, // condition / body / elseBody
    Break,
    Continue,
    Call, // a call standing alone as a statement, so value is discarded
    Unsupported // reported where it was parsed, kept so a block knows it lost one
};

// Every field carries a default initializer so that naming only the leading ones
// stays a complete aggregate initialisation - the project builds with -Wextra,
// which flags an omitted field that has no default of its own.
struct Expr
{
    ExprKind kind = ExprKind::Number;
    std::string text {};
    Vector<int> args {};
    double value = 0.0;
};

struct Statement
{
    StatementKind kind = StatementKind::Assign;
    std::string name {};
    std::string type {}; // GLSL type, on a Declare
    std::string op {}; // "+" for +=, empty for a plain assignment
    int value = -1;
    int line = 0;

    // `for (init; condition; step) body`. The three clauses are blocks rather
    // than single statements so that a comma-separated one stays intact.
    // A while uses condition and body; an if uses condition, body and elseBody.
    int init = -1;
    int condition = -1;
    int step = -1;
    int body = -1;
    int elseBody = -1;

    // `vec3 palette[4] = ...` - the declaration is of an array. Its size is the
    // number of elements the initialiser has, so the one in the brackets is
    // parsed and dropped: the two cannot disagree if only one of them is read.
    bool isArray = false;

    // Whether the port has to declare this local as a mutable variable rather
    // than binding it once. Set after lowering, by the pass that finds the
    // names a loop or a branch writes from outside its own scope: those are the
    // ones a C++ handle cannot stand in for, since rebinding it inside a lambda
    // would leave the value behind at the closing brace.
    bool isVariable = false;
};

// A brace-delimited run of statements, held in its own arena so that a nested
// block is an int on the statement that owns it. Statement is complete by the
// time this is declared, which is what keeps the two types non-recursive.
struct Block
{
    Vector<Statement> statements;
};

struct Parameter
{
    std::string type {};
    std::string name {};
    bool writesBack = false; // out / inout, so the caller sees the final value
};

struct Function
{
    std::string name {};
    std::string returnType {};
    Vector<Parameter> parameters {};
    int body = -1;
    int line = 0;
};

// A parsed Shadertoy: the body of mainImage, the helpers around it, and the
// globals both draw on. Expression nodes live in one arena and refer to each
// other by index, the way eacp's own ShaderGraph does, so a handle to a subtree
// stays a plain int and the tree owns nothing that has to be freed.
struct Shader
{
    const Expr& expr(int node) const { return nodes[node]; }
    const Block& block(int index) const { return blocks[index]; }

    int add(Expr node)
    {
        nodes.add(std::move(node));
        return nodes.size() - 1;
    }

    int add(Block newBlock)
    {
        blocks.add(std::move(newBlock));
        return blocks.size() - 1;
    }

    const Function* function(const std::string& wanted) const
    {
        for (const auto& candidate: functions)
            if (candidate.name == wanted)
                return &candidate;

        return nullptr;
    }

    Vector<Expr> nodes;
    Vector<Block> blocks;
    Vector<Function> functions;

    Vector<Statement> globals;
    Vector<Statement> statements;

    // Statements the port could not keep - the body of a loop that would not
    // unroll - kept so that the gaps *inside* them are still counted. They are
    // walked for diagnostics and their code is thrown away, which is what stops
    // one unreachable loop from hiding every intrinsic it calls.
    Vector<Statement> dropped;

    // What mainImage's parameters were called. A port keeps the author's names
    // so the generated body reads like the shader it came from.
    std::string fragColor = "fragColor";
    std::string fragCoord = "fragCoord";

    bool hasMainImage = false;
};
} // namespace Shadertoy::Glsl
