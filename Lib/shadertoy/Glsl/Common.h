#pragma once

#include <eacp/Core/Utils/Containers.h>

#include <string>
#include <string_view>

// The GLSL front end is portable C++ with no GPU dependency: it reads text and
// produces text, and nothing in it touches Metal, D3D or a device. That is what
// lets the transpiler run as a build step on a machine with no GPU at all.
namespace Shadertoy::Glsl
{
using eacp::Vector;
} // namespace Shadertoy::Glsl
