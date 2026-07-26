#pragma once

#include "Diagnostic.h"
#include "Token.h"

namespace Shadertoy::Glsl
{
// Splits GLSL into tokens, dropping comments and resolving object-like #defines
// in place - `#define PI 3.14159` is common enough in the corpus that leaving it
// to the parser would fail shaders over notation rather than over capability.
// Function-like macros and every other directive are reported instead, so they
// show up in the coverage report as what they are.
Vector<Token> tokenize(const std::string& source, Vector<Diagnostic>& diagnostics);
} // namespace Shadertoy::Glsl
