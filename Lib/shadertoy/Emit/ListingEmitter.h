#pragma once

#include <string>

namespace Shadertoy::Emit
{
// One shader's two texts as a header the Gallery can include: the GLSL it was
// written as and the C++ it converted to, both as arrays of lines, plus the
// Shadertoy::Listing naming them.
//
// Written by both producers of a port - shadertoy-transpile for the ports a
// target holds by hand, shadertoy-scan for the corpus it measures - so it lives
// here rather than in either of them, and both halves of the gallery show the
// same thing.
//
// `edsl` is the emitted header verbatim, which is why this takes it rather than
// re-running the transpiler: a listing showing something other than the header
// the app is running would be the one bug this feature can have.
std::string emitListing(const std::string& structName,
                        const std::string& glsl,
                        const std::string& edsl);
} // namespace Shadertoy::Emit
