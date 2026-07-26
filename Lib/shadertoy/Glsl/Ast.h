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
    Index // args = {object, index}
};

enum class StatementKind
{
    Declare, // type name = value
    Assign, // name op= value
    Return // value, or -1 for a bare `return;`
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
};

// A parsed Shadertoy: the straight-line body of mainImage plus the names its
// signature bound. Expression nodes live in one arena and refer to each other by
// index, the way eacp's own ShaderGraph does, so a handle to a subtree stays a
// plain int and the tree owns nothing that has to be freed.
struct Shader
{
    const Expr& expr(int node) const { return nodes[node]; }

    int add(Expr node)
    {
        nodes.add(std::move(node));
        return nodes.size() - 1;
    }

    Vector<Expr> nodes;
    Vector<Statement> statements;

    // What mainImage's parameters were called. A port keeps the author's names
    // so the generated body reads like the shader it came from.
    std::string fragColor = "fragColor";
    std::string fragCoord = "fragCoord";

    bool hasMainImage = false;
};
} // namespace Shadertoy::Glsl
