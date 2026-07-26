#pragma once

#include "Diagnostic.h"
#include "Token.h"

namespace Shadertoy::Glsl
{
// Splits GLSL into tokens, dropping comments and running the preprocessor in
// place: `#define` in both its forms, `#undef`, and the `#if` family over an
// integer constant expression. That is not notation the parser could be left to
// deal with - a real Shadertoy names its resolution with a macro and puts half
// its body behind an `#ifdef`, so a front end that stops at `#` fails those
// shaders over spelling rather than over anything the EDSL is missing.
//
// What is left is reported: the directives that describe a compilation rather
// than a program are ignored, since a Shadertoy is pasted into a page that
// supplies its own, and anything else shows up in the coverage report as what
// it is.
Vector<Token> tokenize(const std::string& source, Vector<Diagnostic>& diagnostics);
} // namespace Shadertoy::Glsl
