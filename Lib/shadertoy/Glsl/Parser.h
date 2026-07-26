#pragma once

#include "Ast.h"
#include "Diagnostic.h"

namespace Shadertoy::Glsl
{
struct ParseResult
{
    Shader shader;
    Vector<Diagnostic> diagnostics;
};

// Parses a Shadertoy source file down to the straight-line body of mainImage.
//
// The grammar accepted here is deliberately wider than what the emitter can
// lower: comparisons, `?:` and control flow all parse, and are reported as gaps
// further down the pipeline. Rejecting them at the parser would collapse every
// such shader into one useless "syntax error near `if`" instead of the list of
// capabilities it actually needs, and the list is the whole point.
//
// Recovery follows from the same reasoning: an unsupported construct is skipped
// and parsing continues, so one shader reports every wall it hits rather than
// the first.
ParseResult parse(const std::string& source);
} // namespace Shadertoy::Glsl
