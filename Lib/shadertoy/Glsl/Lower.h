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
// A helper the shader wrote is one of two things here. Where the port can
// declare it - a signature the EDSL has types for, a body that is statements
// and then the value at the end of them, and nothing in it out of a member
// function's reach - it stays a function, lowered once, and its calls stay
// calls: which overload one means is then C++'s to resolve from the argument
// types, the way GLSL resolved it and nothing here can. Everything else is
// inlined, body and arguments both, including helpers that call helpers and
// ones that write back through an `inout` parameter.
//
// Neither costs the generated GPU code anything, because a C++ function over
// handles records its body inline wherever it is called. Which is why keeping
// one is worth doing and was never necessary: what it buys is the overload set
// and a file the size of the shader, not a smaller graph.
//
// A loop stays a loop. Everything else here follows from flattening: every
// local in a body ends up in one C++ scope, so names are made unique; and a
// name a loop or a branch writes becomes a `var`, since a C++ handle rebound
// inside a lambda is a new handle that dies at the closing brace.
//
// What will neither be kept nor inlined is reported and dropped, and its body
// is kept aside in Shader::dropped so that the gaps *inside* it are counted.
LowerResult lower(const Shader& parsed);
} // namespace Shadertoy::Glsl
