#pragma once

#include "Program.h"

#include <optional>

namespace Shadertoy
{
// One off-screen pass of a multi-pass Shadertoy - Buffer A through D on the
// page. It owns nothing but the pair of textures its program draws into, and it
// publishes the one every other pass samples.
//
// A pair rather than one texture, because the pass a buffer exists for is the
// one that reads itself: a trail, a fluid, a life grid, anything whose next
// frame is a function of its last. No backend lets a texture be sampled by the
// pass rendering into it, so the buffer draws into the back one and hands out
// the front, and swapping them once a frame is what makes "what I read is what
// I left here last time" true rather than aspirational.
//
// The default format is float, and that is not an optimisation. Eight bits per
// channel cannot hold a value above 1 and quantises everything below it, so a
// pass feeding back into itself loses a little of its state every frame and
// settles into a flat colour it cannot leave. See TextureFormat.
class Buffer
{
public:
    explicit Buffer(Program& programToRun,
                    GPU::TextureFormat formatToUse = GPU::TextureFormat::RGBA16Float)
        : program(programToRun)
        , format(formatToUse)
    {
        program.prepareFullscreen(1, GPU::pixelFormatFor(format));
    }

    // Sizes the pair to the viewport, in device pixels. A no-op once they are
    // that size, so every frame can call it - and a resize deliberately throws
    // the contents away rather than rescaling them, because a feedback buffer's
    // contents are state rather than a picture and there is no honest way to
    // resample one.
    void resize(int newWidth, int newHeight)
    {
        if (newWidth == width && newHeight == height)
            return;

        width = newWidth;
        height = newHeight;

        if (width <= 0 || height <= 0)
            return;

        auto descriptor = GPU::TextureDescriptor {};
        descriptor.width = width;
        descriptor.height = height;
        descriptor.format = format;
        descriptor.renderTarget = true;

        for (auto& texture: textures)
            texture.emplace(GPU::Device::shared(), descriptor, nullptr);

        needsClearing = true;
    }

    // Draws the pass into the back texture. The channels are re-pointed first,
    // since a buffer reading itself has to see what the last swap published and
    // not what it was showing when the wiring was written.
    void run(GPU::Frame& frame)
    {
        if (!isReady())
            return;

        clearBoth(frame);
        program.refreshChannels();

        auto pass = frame.beginPass(back(), {clearColor});
        pass.draw(program);
    }

    // Makes what the pass just drew the thing everything else reads. Every
    // buffer swaps together, after all of them have run, so a frame's passes
    // agree about which frame they are reading.
    void swap() { showing = 1 - showing; }

    // What another pass samples: the texture this buffer published last.
    const GPU::Texture& output() const { return *textures[showing]; }

    bool isReady() const
    {
        return textures[0].has_value() && textures[1].has_value()
               && textures[0]->isRenderTarget() && textures[1]->isRenderTarget();
    }

    int getWidth() const { return width; }
    int getHeight() const { return height; }

    Program& program;

    // What the pair is cleared to on the frame they are created, which is the
    // initial state of whatever the buffer accumulates.
    Graphics::Color clearColor = Graphics::Color::black();

private:
    GPU::Texture& back() { return *textures[1 - showing]; }

    // A freshly created render target holds whatever the driver last had in
    // that memory, and the very first thing a feedback buffer does is read the
    // half nothing has drawn into yet. So both halves are cleared once, on the
    // first frame after they exist - a pass that only clears, which is what a
    // pass with nothing drawn in it is.
    void clearBoth(GPU::Frame& frame)
    {
        if (!needsClearing)
            return;

        for (auto& texture: textures)
            frame.beginPass(*texture, {clearColor});

        needsClearing = false;
    }

    GPU::TextureFormat format;

    std::array<std::optional<GPU::Texture>, 2> textures {};
    int showing = 0;

    int width = 0;
    int height = 0;
    bool needsClearing = false;
};

inline Channel& Channel::operator=(const Buffer& buffer)
{
    source = &buffer;
    refresh();

    return *this;
}

inline void Channel::refresh()
{
    if (source != nullptr && source->isReady())
        point(source->output());
}
} // namespace Shadertoy
