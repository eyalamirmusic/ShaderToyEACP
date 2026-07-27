#pragma once

#include "Ast.h"
#include "Diagnostic.h"

namespace Shadertoy::Glsl
{
struct LowerResult
{
    Shader shader;
    Vector<Diagnostic> diagnostics;
};

// Flattens a parsed shader into the form the emitter lowers.
//
// The one thing that happens here and buys coverage without eacp growing
// anything is inlining: a call to a helper is replaced by the helper's body,
// including helpers that call helpers and ones that write back through an
// `inout` parameter. It costs the generated GPU code nothing, because a C++
// function over handles records its body inline wherever it is called - so a
// port holds no functions of its own however many the shader was written with.
//
// A loop stays a loop. Everything else here follows from flattening: every
// local ends up in one C++ scope, so names are made unique; and a name a loop
// or a branch writes becomes a `var`, since a C++ handle rebound inside a
// lambda is a new handle that dies at the closing brace.
//
// What will not inline is reported and dropped, and its body is kept aside in
// Shader::dropped so that the gaps *inside* it are still counted.
LowerResult lower(const Shader& parsed);
} // namespace Shadertoy::Glsl
