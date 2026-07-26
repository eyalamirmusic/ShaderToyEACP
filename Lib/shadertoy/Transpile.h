#pragma once

#include "Emit/CppEmitter.h"

namespace Shadertoy
{
struct TranspileResult
{
    // A shader converts when nothing was reported. A shader that reports is
    // still emitted: the marked-up output is what makes the gap legible, and
    // the report is what the coverage table is built from.
    bool ok() const { return diagnostics.empty(); }

    std::string code;
    Glsl::Vector<Glsl::Diagnostic> diagnostics;
};

TranspileResult transpile(const std::string& source, const std::string& structName);
} // namespace Shadertoy
