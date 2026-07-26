#pragma once

#include "../Glsl/Ast.h"
#include "../Glsl/Diagnostic.h"

namespace Shadertoy::Cpp
{
using Glsl::Diagnostic;
using Glsl::Vector;

struct EmitResult
{
    std::string code;
    Vector<Diagnostic> diagnostics;
};

// Lowers a parsed shader into a C++ header declaring one Shadertoy::Program.
//
// The output is meant to be read, not just compiled: it is the same shape a
// hand port takes, so a generated shader can be opened next to the GLSL it came
// from and checked line by line. Where a construct has no EDSL spelling the
// emitter writes the offending source through with a marker comment rather than
// dropping it, so the file names its own gaps instead of silently changing what
// the shader draws.
EmitResult emit(const Glsl::Shader& shader, const std::string& structName);
} // namespace Shadertoy::Cpp
