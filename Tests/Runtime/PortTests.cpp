#include "Common.h"

#include <Channels.h>
#include <Checker.h>
#include <Fbm.h>
#include <Kaleido.h>
#include <Mandelbrot.h>
#include <Palette.h>
#include <Raymarch.h>
#include <Tunnel.h>
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

// A port declares the channels it reads and no others, so the one texture this
// shader samples is the one binding the draw has to satisfy - and the sampling
// is the page's for a channel rather than eacp's for a texture, or the polar
// coordinate would clamp at the seam instead of wrapping round it.
auto tChannelPortCompiles = test("Ports/samplesATextureChannel") = []
{
    auto shader = Shadertoy::Ports::Tunnel {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(contains(source.source, "texture0"));
    check(!contains(source.source, "texture1"));

    check(shader.iChannel0.texture.sampling.filter == GPU::TextureFilter::Linear);

    check(shader.iChannel0.texture.sampling.addressMode
          == GPU::TextureAddressMode::Repeat);
};

// The other two reads, which each lower to something the ordinary sample is
// not: a level the shader names rather than one the derivatives imply, and a
// texel read that goes past the sampler altogether. Both are backend-specific
// spellings, so what this checks is that the generated port reached them at all.
auto tChannelReadsCompile = test("Ports/samplesAtALevelAndFetchesATexel") = []
{
    auto shader = Shadertoy::Ports::Channels {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(contains(source.source, "texture0"));
    check(contains(source.source, "texture1"));

    auto sampledLevel = Platform::isWindows() ? "SampleLevel(" : "level(";
    auto fetched = Platform::isWindows() ? ".Load(" : ".read(";

    check(contains(source.source, sampledLevel));
    check(contains(source.source, fetched));

    // Two channels and the size of one of them, on top of the Shadertoy set's
    // 48 bytes: a texture takes no room in the uniform block, a resolution
    // takes a float3's slot, and both channels declare one.
    check(shader.uniformByteSize() == 80);
};

// The shape unrolling cannot reach, and the one this whole stage was for: a
// march whose length depends on what it hits, inside a helper the port had to
// inline around it. The emitted shader holds a real loop with a real jump - not
// sixty-four copies of a body, and not a body that quietly lost its break.
auto tRaymarchPortCompiles = test("Ports/marchesWithADataDependentBreak") = []
{
    auto shader = Shadertoy::Ports::Raymarch {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(contains(source.source, "while ("));
    check(contains(source.source, "break;"));

    // One length() in the emitted source: the distance the loop tests is the
    // distance it steps by, named once and read twice.
    auto lengths = std::size_t {0};

    for (auto at = source.source.find("length("); at != std::string::npos;
         at = source.source.find("length(", at + 1))
        ++lengths;

    check(lengths == 1);
};

// The rest of the statement vocabulary in one shader: an escape-time loop whose
// count is a property of the pixel, a bool the loop sets and the shading reads,
// a colour written by both sides of an if/else and read after it, and a ternary
// over two comparisons joined by a connective.
auto tMandelbrotPortCompiles = test("Ports/escapeTimeLoopAndBranches") = []
{
    auto shader = Shadertoy::Ports::Mandelbrot {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(contains(source.source, "while ("));
    check(contains(source.source, "bool "));
    check(contains(source.source, "else"));
    check(contains(source.source, " ? "));
    check(contains(source.source, " && "));
};

// The wall the corpus was still walking into: an array, the integer that
// indexes it, and the mask that holds the index in range. All four elements
// reach the emitted source, the subscript reads the array the port declared,
// and the truncation and the mask are spelled on the integer rather than
// approximated on a float.
auto tPalettePortCompiles = test("Ports/readsAConstantArray") = []
{
    auto shader = Shadertoy::Ports::Palette {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(contains(source.source, "const float3 a0[4] = {"));
    check(contains(source.source, "a0["));
    check(contains(source.source, "int("));
    check(contains(source.source, " & 3)"));

    // One declaration, in the one stage that reads it.
    auto declarations = std::size_t {0};

    for (auto at = source.source.find("a0[4]"); at != std::string::npos;
         at = source.source.find("a0[4]", at + 1))
        ++declarations;

    check(declarations == 1);
};
