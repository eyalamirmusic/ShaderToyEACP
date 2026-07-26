#include "Common.h"

#include <Facets.h>
#include <Surface.h>

// The aggregate is the fifth stage whose result nothing else can observe. A
// struct scalarises into one local per field, and every way of getting that
// wrong still compiles and still reports nothing: a leaf read out of the wrong
// slot is a plausible colour, a field the loop wrote that never escaped it is
// the colour it started as, and a choice made once for the whole struct instead
// of per field is a picture too.
//
// So each port below is built so the frame says which happened, and the two
// that matter are generated - the structs, the fields and the names they became
// are the transpiler's rather than anything typed here. The one that is not
// pins the claim they rest on: that a C++ struct of handles already is the
// aggregate, so there was never anything to add to the EDSL.
//
// Self-skips without a GPU device.

using namespace nano;
using namespace eacp;

namespace
{
Graphics::Image render(Shadertoy::Program& program)
{
    auto view = Shadertoy::ShaderView {program};
    view.setBounds({0.0f, 0.0f, 16.0f, 4.0f});

    return view.renderToImage(1.0f);
}

// The claim the whole stage rests on, written by hand rather than generated: an
// aggregate of shader values is a C++ aggregate, and the EDSL needs to know
// nothing about it. If this stops compiling, the reason the transpiler
// scalarises instead of asking eacp for a type has stopped being true.
struct HandWrittenStruct final : Shadertoy::Program
{
    HandWrittenStruct() { compile(); }

    struct Hit
    {
        GPU::Float distance;
        GPU::Float3 albedo;
    };

    Hit scene(const GPU::Float2& p)
    {
        return {length(p), float3(constant(0.9f), 0.4f, 0.2f)};
    }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto hit = scene(fragCoord / iResolution.xy());
        return float4(hit.albedo * hit.distance, 1.0f);
    }
};
} // namespace

// A struct of handles crosses a function boundary and comes back, which is the
// whole of what a Shadertoy asks an aggregate for. Nothing in eacp knows this
// happened: the two fields are a Float and a Float3 recorded like any other.
auto tHandWrittenStructCompiles =
    test("Struct/aCppStructOfHandlesIsTheAggregate") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = HandWrittenStruct {};
    auto image = render(shader);

    check(image.isValid());

    // Brighter away from the origin, since the shade is the distance itself,
    // and in the albedo's own order of components.
    auto near = image.at(0, 0);
    auto far = image.at(15, 3);

    check(far.r > near.r);
    check(far.r > far.g);
    check(far.g > far.b);
};

// Surface.glsl: a march whose hit carries back a distance and a colour, written
// together inside the loop and read after it. The sphere is at the centre, so
// the frame is bright there and dark at the corner - and the colour it is bright
// in is the albedo the struct was built with, whose components are ordered
// 0.9 > 0.4 > 0.2.
//
// That ordering is the whole point of checking it: it survives whatever transfer
// function the frame is read back through, and nothing but the albedo leaf
// landing in the albedo slot produces it. A frame shaded by the distance leaf
// instead comes out grey, with the three channels equal.
auto tSurfaceCarriesAHitBack = test("Struct/carriesAHitOutOfALoop") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Surface {};
    auto image = render(shader);

    check(image.isValid());

    auto centre = image.at(8, 2);
    auto corner = image.at(0, 0);

    // The march arrived in the middle and ran out at the edge, which is what
    // says the distance leaf is the one the loop stepped by.
    check(centre.r > corner.r + 0.25f);

    // And what it arrived carrying is the colour rather than the distance.
    check(centre.r > centre.g);
    check(centre.g > centre.b);
};

// Facets.glsl: two candidates differing in every field, one chosen per pixel by
// a ternary over the whole struct. Left of centre the red one wins at full
// shine; right of centre the green one wins at half.
//
// A choice that picked one struct's distance and another's material would light
// the wrong half, and a nested field read from the outer struct's slot would
// come out black - the shine sits where the albedo's third component does.
auto tFacetsChooseAWholeStruct = test("Struct/choosesBetweenTwoWholeStructs") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Facets {};
    auto image = render(shader);

    check(image.isValid());

    auto left = image.at(2, 2);
    auto right = image.at(13, 2);

    check(left.r > 0.5f && left.g < 0.25f);
    check(right.g > 0.25f && right.r < 0.25f);

    // The shine came from the same candidate the albedo did: the green half is
    // lit at half the strength the red half is, not at the same one.
    check(right.g < left.r);
};
