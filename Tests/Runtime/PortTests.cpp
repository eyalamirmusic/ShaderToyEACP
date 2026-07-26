#include "Common.h"

#include <Checker.h>
#include <Fbm.h>
#include <Kaleido.h>
#include <Voronoi.h>

using namespace nano;
using namespace eacp;

namespace
{
bool contains(const std::string& haystack, std::string_view needle)
{
    return haystack.find(needle) != std::string::npos;
}
} // namespace

// Converting is not the same as being right, and a header that reports no gaps
// can still be one the EDSL rejects: a scalar built from literals alone is a
// C++ float rather than a value in the graph, and min() or a vector constructor
// will not take it. That is a compile error in the generated file, which is
// exactly what these two ports are here to turn into a test failure.
//
// Both are transpiled from Corpus/ by the build, so what is compiled below is
// whatever the transpiler emits today.
auto tUnrolledPortCompiles = test("Ports/unrolledLoopAndInlinedHelpers") = []
{
    auto shader = Shadertoy::Ports::Fbm {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(contains(source.source, source.fragmentEntry));

    // Four octaves of a helper that hashes four corners: whatever the emitter
    // names them, the fragment stage has to hold a good many more sin() calls
    // than the source file's one.
    auto sines = std::size_t {0};

    for (auto at = source.source.find("sin("); at != std::string::npos;
         at = source.source.find("sin(", at + 1))
        ++sines;

    check(sines >= 16);
};

// Nested loops and a helper that writes back through an inout parameter.
auto tNestedPortCompiles = test("Ports/nestedLoopsAndOutParameters") = []
{
    auto shader = Shadertoy::Ports::Voronoi {};

    check(!shader.source().source.empty());
    check(shader.uniformByteSize() == 48);
};

// The two gaps stage 3 closed that had nothing to do with control flow: mod,
// which the shading languages only offer as a truncating fmod, and a reordered
// swizzle, which had no accessor. Both are one line of ordinary GLSL, and
// between them they were the whole of what stood between this shader and a port.
auto tModulusAndSwizzlePortCompiles = test("Ports/modulusAndReorderedSwizzle") = []
{
    auto shader = Shadertoy::Ports::Checker {};
    const auto& source = shader.source();

    check(!source.source.empty());

    // mod() lowers to the floored form, so the emitted shader holds the
    // subtraction and the floor rather than a call the backend would truncate.
    check(contains(source.source, "floor("));
    check(!contains(source.source, "fmod("));
    check(contains(source.source, ".yx"));
};

// The rest of stage 3 in one shader: a mat2 rotation built inline, polar
// coordinates through atan2, mod tiling, exp falloff, rsqrt, sign, and swizzles
// of every width including a four-component one.
auto tMatrixAndIntrinsicPortCompiles = test("Ports/matricesAndIntrinsics") = []
{
    auto shader = Shadertoy::Ports::Kaleido {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(contains(source.source, "float2x2("));
    check(contains(source.source, "atan2("));
    check(contains(source.source, "exp("));
    check(contains(source.source, "rsqrt("));
    check(contains(source.source, "sign("));
    check(contains(source.source, ".wzyx"));
};
