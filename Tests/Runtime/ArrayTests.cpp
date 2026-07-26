#include "Common.h"

#include <Palette.h>

// An array read at a computed index is the third thing nothing on the CPU can
// observe. A shader that always read element zero compiles, reports nothing and
// renders a perfectly plausible flat colour; so does one whose index saturates
// at either end. Only a frame says which element each pixel actually got.
//
// So each shader below paints a different colour per element and the frame is
// read back a quarter at a time: four different quarters mean the subscript
// varied, and which end the left one came from says whether the index that fed
// it was signed.
//
// Self-skips without a GPU device.

using namespace nano;
using namespace eacp;

namespace
{
// Four quarters, one element each, over an index masked into range - the way a
// palette shader spells it. Red, green, blue then white from left to right.
struct MaskedPalette final : Shadertoy::Program
{
    MaskedPalette() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();

        auto palette = array(float3(constant(1.0f), 0.0f, 0.0f),
                             float3(constant(0.0f), 1.0f, 0.0f),
                             float3(constant(0.0f), 0.0f, 1.0f),
                             float3(constant(1.0f), 1.0f, 1.0f));

        auto index = toInt(uv.x() * 4.0f) & 3;

        return float4(palette[index], 1.0f);
    }
};

// The same palette over an index that really does go negative, held in range by
// a clamp rather than a mask. The left half computes a negative index and comes
// out the *first* element; counting in unsigned would wrap it to a huge number
// and clamp it to the last one instead, so which end of the palette the left of
// the frame carries is what says the index is signed.
struct ClampedPalette final : Shadertoy::Program
{
    ClampedPalette() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();

        auto palette = array(float3(constant(1.0f), 0.0f, 0.0f),
                             float3(constant(0.0f), 1.0f, 0.0f),
                             float3(constant(0.0f), 0.0f, 1.0f),
                             float3(constant(1.0f), 1.0f, 1.0f));

        auto index = min(max(toInt(uv.x() * 8.0f - 4.0f), 0), 3);

        return float4(palette[index], 1.0f);
    }
};

Graphics::Image render(Shadertoy::Program& program)
{
    auto view = Shadertoy::ShaderView {program};
    view.setBounds({0.0f, 0.0f, 16.0f, 4.0f});

    return view.renderToImage(1.0f);
}

bool isRed(const Graphics::Color& color)
{
    return color.r > 0.5f && color.g < 0.5f && color.b < 0.5f;
}

bool isGreen(const Graphics::Color& color)
{
    return color.g > 0.5f && color.r < 0.5f && color.b < 0.5f;
}

bool isBlue(const Graphics::Color& color)
{
    return color.b > 0.5f && color.r < 0.5f && color.g < 0.5f;
}

bool isWhite(const Graphics::Color& color)
{
    return color.r > 0.5f && color.g > 0.5f && color.b > 0.5f;
}
} // namespace

// Every quarter a different element, which is the whole claim: the array is
// indexed by what the pixel computed rather than by a constant.
auto tSubscriptVaries = test("Array/subscriptFollowsTheIndex") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = MaskedPalette {};
    auto image = render(shader);

    check(image.isValid());
    check(isRed(image.at(1, 2)));
    check(isGreen(image.at(5, 2)));
    check(isBlue(image.at(9, 2)));
    check(isWhite(image.at(13, 2)));
};

// The signed half of it: the left end clamps to the first element, not the last.
auto tIndexIsSigned = test("Array/negativeIndexClampsToTheFirst") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = ClampedPalette {};
    auto image = render(shader);

    check(image.isValid());

    // Negative all the way to the middle, so the whole left half is element
    // zero. An unsigned index would make this white.
    check(isRed(image.at(1, 2)));
    check(isRed(image.at(6, 2)));

    // And the right of the frame still walks the rest of the palette, which is
    // what says the clamp held the index rather than replaced it.
    check(isWhite(image.at(15, 2)));
};

// The same thing over a port nobody wrote: Palette.glsl through the transpiler,
// where the array, the truncation and the mask are all generated rather than
// typed. Its four entries have no two channels in the same order, so which one
// a quarter got is readable from the ratios alone - which is what keeps this
// independent of the time factor the shader scales them all by.
auto tGeneratedPortReadsItsArray = test("Array/generatedPortReadsItsArray") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Palette {};
    auto image = render(shader);

    check(image.isValid());

    auto first = image.at(1, 2); // (0.1, 0.1, 0.2): blue leads
    auto second = image.at(5, 2); // (0.9, 0.4, 0.2): red leads
    auto third = image.at(9, 2); // (0.2, 0.8, 0.6): green leads
    auto fourth = image.at(13, 2); // (1.0, 0.9, 0.7): red leads, but barely

    check(first.b > first.r);
    check(second.r > second.g && second.g > second.b);
    check(third.g > third.r && third.g > third.b);
    check(fourth.r > fourth.g && fourth.g > fourth.b);

    // And the fourth is the brightest of them, which no two of the ratios above
    // could say on their own.
    check(fourth.r > second.r && second.r > third.r && third.r > first.r);
};
