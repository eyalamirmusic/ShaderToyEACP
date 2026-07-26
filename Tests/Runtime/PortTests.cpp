#include "Common.h"

#include <Fbm.h>
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
