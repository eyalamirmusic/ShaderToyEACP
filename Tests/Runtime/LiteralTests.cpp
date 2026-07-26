#include "Common.h"

#include <Blanks.h>
#include <Literals.h>

// Stage 11's two shaders, and the two things about them that compile whichever
// way they are wrong.
//
// A vector times a matrix and a matrix times a vector are the same node in the
// graph and differ only in which operand is on the left, so emitting either for
// both compiles, reports nothing, and turns the shader the wrong way. Only the
// frame says which happened.
//
// A scalar written into two components at once is the same: GLSL broadcasts it
// across both, and a rebuild that reached only the first is a plausible picture
// rather than an error. The two components are carried in a channel each here,
// so the check is that they are equal - which is what a broadcast means, and
// which survives whatever the read-back frame is composited through.
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

// The rotation carries the pixel's own x into y with one sign through the rows
// and the other through the columns, so the two channels swap places across the
// middle of the frame. Both products emitted the same way round leaves them
// equal everywhere, which is a picture too.
auto tProductsKeepTheirOrder = test("Literal/matrixProductsKeepTheirOrder") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Literals {};
    auto image = render(shader);

    check(image.isValid());

    auto left = image.at(2, 2);
    auto right = image.at(13, 2);

    check(right.g > right.r);
    check(left.r > left.g);
};

// The scalar reaches both components, which is the whole of what broadcasting
// it means: red carries the first and green the second, and one that reached
// only the first leaves green at whatever the unwritten half held.
auto tScalarWriteReachesBoth = test("Literal/aScalarWriteReachesBothComponents") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Blanks {};
    auto image = render(shader);

    check(image.isValid());

    auto pixel = image.at(8, 2);

    check(pixel.r > 0.05f);
    check(std::abs(pixel.r - pixel.g) < 0.02f);
};
