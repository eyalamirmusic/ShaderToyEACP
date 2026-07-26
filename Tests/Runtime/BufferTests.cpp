#include "Common.h"

#include <TrailBuffer.h>
#include <TrailImage.h>

// A two-pass Shadertoy, which is the first shape that needs more than one frame
// to say anything: Buffer A reads itself, adds a little, and hands the result to
// the image pass. What it holds after eight frames is eight times what it held
// after one, and neither the report nor the compiler can see the difference.
//
// The 8-bit run beside it is the control, and it is the whole reason a buffer is
// float by default. Both runs draw the same shaders through the same passes;
// they differ only in what the buffer is made of, and the one that cannot hold a
// value above 1 stops accumulating the moment it gets there. Comparing the two
// renders rather than either against a number is also what keeps this
// independent of whatever transfer function the frame comes back through.
//
// A buffer's textures are sized by the first render, so readiness is checked
// after running rather than before: asked too early it is always false, and a
// test that skips itself on that is a test that passes without looking.
//
// Self-skips without a GPU device.

using namespace nano;
using namespace eacp;

namespace
{
constexpr auto viewWidth = 16;
constexpr auto viewHeight = 4;

// The trail adds 0.25 + uv.x * 0.5 per frame, so the right-hand side passes 1
// on the second frame and the left-hand side on the fourth. Eight is well past
// both, which is what makes the two runs disagree rather than merely differ.
constexpr auto frames = 8;

// One Shadertoy with a buffer: the two generated ports, the pass that owns the
// pair of textures, and the view that runs them in order.
//
// The wiring is the whole of what a multi-buffer page is. iChannel0 of the
// buffer is the buffer, which is the feedback; iChannel0 of the image is the
// same buffer, which is how what it accumulated reaches the screen.
struct TrailShader
{
    explicit TrailShader(GPU::TextureFormat format)
        : buffer(bufferProgram, format)
    {
        bufferProgram.iChannel0 = buffer;
        imageProgram.iChannel0 = buffer;

        view.addBuffer(buffer);
        view.setBounds({0.0f, 0.0f, (float) viewWidth, (float) viewHeight});
    }

    Graphics::Image runFor(int frameCount)
    {
        auto image = Graphics::Image {};

        for (auto frame = 0; frame < frameCount; ++frame)
            image = view.renderToImage(1.0f);

        return image;
    }

    Shadertoy::Ports::TrailBuffer bufferProgram;
    Shadertoy::Ports::TrailImage imageProgram;

    Shadertoy::Buffer buffer;
    Shadertoy::ShaderView view {imageProgram};
};

// Well inside the right-hand half, where the trail grows fastest.
float rightOf(const Graphics::Image& image)
{
    return image.at(viewWidth - 2, viewHeight / 2).r;
}

float leftOf(const Graphics::Image& image)
{
    return image.at(1, viewHeight / 2).r;
}
} // namespace

// The buffer reached the image at all: one frame of it is not black, and it
// carries the horizontal gradient the buffer pass wrote rather than a flat
// colour. Everything below rests on this.
auto tBufferReachesTheImage = test("Buffer/theBufferReachesTheImagePass") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = TrailShader {GPU::TextureFormat::RGBA16Float};
    auto image = shader.runFor(1);

    check(shader.buffer.isReady());
    check(image.isValid());
    check(rightOf(image) > 0.0f);
    check(rightOf(image) > leftOf(image));
};

// And it read itself: eight frames hold eight times what one frame did. A
// buffer whose channel never reached the previous frame's texture would come
// back with the same picture however long it ran.
auto tBufferAccumulates = test("Buffer/theBufferReadsItsPreviousFrame") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto once = TrailShader {GPU::TextureFormat::RGBA16Float};
    auto many = TrailShader {GPU::TextureFormat::RGBA16Float};

    auto first = once.runFor(1);
    auto later = many.runFor(frames);

    check(once.buffer.isReady() && many.buffer.isReady());
    check(first.isValid() && later.isValid());
    check(rightOf(later) > rightOf(first) * 2.0f);
};

// The control, and the reason a buffer is float. The same eight frames through
// an 8-bit buffer saturate: everything past 1 is thrown away as it is written,
// so the float run comes back brighter, and the 8-bit one comes back flat -
// both sides of it hit the ceiling and the gradient the buffer wrote is gone.
auto tFloatBufferOutlastsEightBits = test("Buffer/anEightBitBufferSaturates") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto asFloat = TrailShader {GPU::TextureFormat::RGBA16Float};
    auto asBytes = TrailShader {GPU::TextureFormat::RGBA8Unorm};

    auto floatImage = asFloat.runFor(frames);
    auto byteImage = asBytes.runFor(frames);

    check(asFloat.buffer.isReady() && asBytes.buffer.isReady());
    check(floatImage.isValid() && byteImage.isValid());

    // The float buffer kept counting where the 8-bit one stopped.
    check(rightOf(floatImage) > rightOf(byteImage));

    // And what the 8-bit one lost is the gradient: saturated, its two sides are
    // the same, while the float one still has the shape the pass wrote.
    check(rightOf(floatImage) > leftOf(floatImage));
    check(std::abs(rightOf(byteImage) - leftOf(byteImage)) < 0.05f);
};
