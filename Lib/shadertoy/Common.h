#pragma once

#include <eacp/GPU/GPU.h>

#include <array>

namespace Shadertoy
{
// Shorthands for the eacp modules every type here is built on, so declarations
// read like the eacp code they mirror instead of doubling in width. Shader
// bodies need no such alias: every EDSL intrinsic takes a handle from
// eacp::GPU, so argument-dependent lookup already finds sin, mix and float4
// unqualified.
namespace GPU = eacp::GPU;
namespace Graphics = eacp::Graphics;
namespace Threads = eacp::Threads;

using eacp::Vector;
} // namespace Shadertoy
