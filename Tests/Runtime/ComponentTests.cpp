#include "Common.h"

#include <Compose.h>

// Writing part of a value is the sixth stage whose result nothing else can
// observe. The rebuild compiles and reports nothing whichever way it is wrong:
// a component put in the wrong slot is a plausible colour, a target read back
// after the write rather than before it is another, and an accumulation inside
// a loop that reads its variable at the wrong point is a third.
//
// So Compose.glsl is built so the frame says which happened. Every write lands
// in a channel of its own, they are ordered r > g > b where the shader is lit,
// and the loop's own contribution is what makes the middle channel land where
// it does. The ordering is what is checked rather than any absolute value,
// because a read-back frame is composited and an ordering survives that.
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
} // namespace

// The pair written out of order is the sharpest of these: `col.gr = vec2(0.35,
// 0.85)` puts 0.85 in red and 0.35 in green, and a rebuild that took the
// components in the order they were spelled rather than in the order the
// swizzle names them puts them the other way round. Both are a colour.
auto tComponentsLandWhereTheSwizzleSays =
    test("Component/componentsLandWhereTheSwizzleSays") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Compose {};
    auto image = render(shader);

    check(image.isValid());

    auto left = image.at(2, 2);

    check(left.r > left.g);
    check(left.g > left.b);
};

// The compound write reads what is already there: `col.r += 0.05 * step(...)`
// only lifts red on the right-hand half, so the two halves differ in red and
// agree in the two channels nothing wrote after the split.
auto tCompoundWriteReadsTheTarget =
    test("Component/compoundWriteReadsTheTarget") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Compose {};
    auto image = render(shader);

    check(image.isValid());

    auto left = image.at(2, 2);
    auto right = image.at(13, 2);

    check(right.r > left.r);
    check(right.g > right.b);
};

// The loop adds to green once per band the pixel's own column is past, so green
// is a staircase of four steps across the frame. Flat would be a variable read
// once outside the loop, and a staircase of the wrong heights would be one read
// after its own assignment rather than before - and both of those are a colour.
auto tLoopAccumulatesIntoOneComponent =
    test("Component/loopAccumulatesIntoOneComponent") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Compose {};
    auto image = render(shader);

    check(image.isValid());

    // One sample in each quarter of a sixteen-point-wide frame.
    auto first = image.at(1, 2);
    auto second = image.at(5, 2);
    auto third = image.at(9, 2);
    auto fourth = image.at(13, 2);

    check(second.g > first.g);
    check(third.g > second.g);
    check(fourth.g > third.g);

    // Green stays under red and over blue the whole way, which is what says the
    // staircase landed in the channel the loop wrote and not in a neighbour.
    check(first.g > first.b && first.g < first.r);
    check(fourth.g > fourth.b && fourth.g < fourth.r);
};
