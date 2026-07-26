#include "Common.h"

#include <Raymarch.h>

// Control flow is the second stage whose result nothing on the CPU can observe.
// A loop that never runs, one that ignores its break, and one that runs to
// completion all compile, all report nothing, and differ only in the pixels
// they produce - so the only thing that tells them apart is a frame rendered
// and read back.
//
// Each shader below is built so that its picture says which of those happened:
// a flat frame means the loop misbehaved, and the ramp or the split means it
// did what the source said.
//
// Self-skips without a GPU device.

using namespace nano;
using namespace eacp;

namespace
{
// Steps a sixteenth at a time until it passes the pixel's own coordinate, so
// the number of iterations differs per pixel and the frame comes out a
// horizontal ramp. A loop that never ran would be black everywhere; one that
// ignored its break would be white everywhere.
struct MarchingLoop final : Shadertoy::Program
{
    MarchingLoop() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();

        auto travelled = var(0.0f);
        auto steps = var(0.0f);

        loop(steps < 16.0f,
             [&]
             {
                 steps += 1.0f;
                 travelled += 0.0625f;

                 ifThen(travelled > uv.x(), [&] { breakLoop(); });
             });

        auto shade = steps.get() / 16.0f;
        return float4(shade, shade, shade, 1.0f);
    }
};

// A branch and a select over the same kind of test, side by side: the left half
// red and the right half green from the if, the leftmost quarter carrying blue
// from the select. One frame says whether either of them chose.
struct BranchedShade final : Shadertoy::Program
{
    BranchedShade() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();
        auto colour = var(float3(constant(0.0f), 0.0f, 0.0f));

        ifThen(
            uv.x() < 0.5f,
            [&] { colour = float3(constant(1.0f), 0.0f, 0.0f); },
            [&] { colour = float3(constant(0.0f), 1.0f, 0.0f); });

        auto blue = select(uv.x() < 0.25f, 1.0f, 0.0f);
        return float4(colour.get().xy(), blue, 1.0f);
    }
};

Graphics::Image render(Shadertoy::Program& program)
{
    auto view = Shadertoy::ShaderView {program};
    view.setBounds({0.0f, 0.0f, 16.0f, 4.0f});

    return view.renderToImage(1.0f);
}
} // namespace

// The ramp: dark where the march stops after one step, white where it runs the
// whole way. Both ends have to be right - one of them alone would pass for a
// loop stuck at either extreme.
auto tLoopIterates = test("ControlFlow/loopRunsUntilItsBreak") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = MarchingLoop {};
    auto image = render(shader);

    check(image.isValid());
    check(image.at(0, 2).r < 0.25f);
    check(image.at(15, 2).r > 0.75f);

    // And it is a ramp between them rather than a step, which is what says the
    // count differs per pixel instead of the loop having two outcomes.
    check(image.at(4, 2).r < image.at(11, 2).r);
};

// The two ways of choosing, in one frame.
auto tBranchAndSelect = test("ControlFlow/branchAndSelectChoose") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = BranchedShade {};
    auto image = render(shader);

    check(image.isValid());

    // The if: red on the left, green on the right.
    check(image.at(2, 2).r > 0.5f && image.at(2, 2).g < 0.5f);
    check(image.at(13, 2).g > 0.5f && image.at(13, 2).r < 0.5f);

    // The select, over a narrower test than the branch beside it.
    check(image.at(2, 2).b > 0.5f);
    check(image.at(6, 2).b < 0.5f);
};

// The same thing over a port nobody wrote: Raymarch.glsl through the
// transpiler, where the variable, the loop and the break are all generated
// rather than typed. The sphere is at the centre, so a march that works fades
// from lit in the middle to nothing at the edge - and a loop that stopped
// immediately would be a flat frame at the colour of zero distance.
auto tGeneratedPortMarches = test("ControlFlow/generatedPortMarches") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Raymarch {};
    auto image = render(shader);

    check(image.isValid());

    auto centre = image.at(8, 2).r;
    auto corner = image.at(0, 0).r;

    check(centre > corner + 0.25f);
    check(centre < 1.0f);
};
