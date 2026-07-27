#pragma once

#include "Ast.h"

namespace Shadertoy::Glsl
{
// Rewrites every body that leaves early into one that leaves at the end.
//
// A ported body is one expression returned after the last statement runs, so a
// `return` anywhere else was the largest gap the corpus named: 71 of the 204
// shaders measured hit it, most of them in a helper of two lines. The gap was
// never in the EDSL - it has the branch, the loop, the `break` and the mutable
// variable this needs - so nothing about it reaches eacp. What a body leaves
// with becomes a local, what it does after leaving becomes nothing, and the one
// return left is the last statement, which is the shape the lowering already
// inlines and the emitter already writes.
//
// Two things keep the result readable rather than merely correct. A guard
// clause - `if (h < 0.0) return -1.0;` and then the rest - puts the rest in the
// `else` it always meant, so the common case needs no flag at all; and the flag
// is declared only where something after the return actually tests it.
void rewriteEarlyReturns(Shader& shader);
} // namespace Shadertoy::Glsl
