#pragma once

#include "Common.h"

namespace Shadertoy::Glsl
{
// Why a shader did not convert.
//
// Each kind names one missing capability rather than a place in the file,
// because what these are collected for is the count: how many shaders in the
// corpus each gap blocks is what decides which gap to close next. A shader that
// hits five different walls reports five diagnostics, not the first one - so
// conversion never stops at the first failure.
enum class DiagnosticKind
{
    ControlFlow, // do / switch / discard, an early return, a jump with no loop
    UnsupportedIntrinsic, // a builtin the EDSL has no spelling for
    UnsupportedSwizzle, // a component pattern beyond x/y/z/w, xy and xyz
    UnsupportedType, // int, ivec/bvec, arrays, structs, the bitwise operators
    UnsupportedTexture, // iChannel sampling
    UserFunction, // a helper the port would have to inline
    Preprocessor, // a directive beyond an object-like #define
    ComponentAssignment, // writing one component of a value, e.g. col.x = 1.0
    UnknownIdentifier, // a name the port cannot resolve, e.g. iDate
    ParseError
};

inline const char* name(DiagnosticKind kind)
{
    switch (kind)
    {
        case DiagnosticKind::ControlFlow:
            return "control-flow";
        case DiagnosticKind::UnsupportedIntrinsic:
            return "intrinsic";
        case DiagnosticKind::UnsupportedSwizzle:
            return "swizzle";
        case DiagnosticKind::UnsupportedType:
            return "type";
        case DiagnosticKind::UnsupportedTexture:
            return "texture";
        case DiagnosticKind::UserFunction:
            return "user-function";
        case DiagnosticKind::Preprocessor:
            return "preprocessor";
        case DiagnosticKind::ComponentAssignment:
            return "component-assignment";
        case DiagnosticKind::UnknownIdentifier:
            return "unknown-identifier";
        case DiagnosticKind::ParseError:
            return "parse-error";
    }

    return "parse-error";
}

struct Diagnostic
{
    DiagnosticKind kind = DiagnosticKind::ParseError;

    // What exactly was hit: the intrinsic's name, the swizzle's components, the
    // keyword. This is the string the coverage report groups on, so it stays
    // narrow enough that two shaders blocked by the same thing agree on it.
    std::string detail;

    int line = 0;
};

inline std::string describe(const Diagnostic& diagnostic)
{
    return std::to_string(diagnostic.line) + ": " + name(diagnostic.kind) + ": "
           + diagnostic.detail;
}
} // namespace Shadertoy::Glsl
