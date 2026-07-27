#pragma once

#include <span>
#include <string_view>

namespace Shadertoy
{
// The two texts one shader is, carried into the binary beside the port built
// from them: the Shadertoy GLSL somebody wrote, and the C++ the transpiler made
// of it.
//
// Embedded rather than read off disk at run time, because a .app handed to
// somebody has neither the corpus nor the build directory beside it - and a
// code view that works from a checkout and comes up empty from a download would
// be worse than none. The generated listings are written by shadertoy-transpile
// and by shadertoy-scan; see Emit/ListingEmitter.h for their shape.
//
// Lines rather than one string, because that is what a reader shows and because
// a whole shader as a single literal is past what a compiler has to accept.
struct Listing
{
    std::string_view name;

    std::span<const std::string_view> glsl;
    std::span<const std::string_view> edsl;
};
} // namespace Shadertoy
