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

// Flattens a parsed shader into the straight-line form the emitter lowers.
//
// Two things happen here, and both buy coverage without eacp growing anything:
// a `for` whose trip count is a constant is unrolled into that many copies of
// its body, and a call to a helper is replaced by the helper's body. Neither
// blows up the generated GPU code - eacp's own emitter promotes any node used
// more than once to a named local - so an unrolled march emits linear MSL and
// HLSL rather than a nested expression.
//
// The loop counter is substituted as a literal at each copy, which is what
// keeps `int` out of the picture: after unrolling there is no integer left to
// express. Locals declared inside a body are renamed per copy, since flattening
// puts every one of them in the same C++ scope.
//
// What will not unroll or inline is reported and dropped, and its body is kept
// aside in Shader::dropped so that the gaps *inside* it are still counted.
LowerResult lower(const Shader& parsed);
} // namespace Shadertoy::Glsl
