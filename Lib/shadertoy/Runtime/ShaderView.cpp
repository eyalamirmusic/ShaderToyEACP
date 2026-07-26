#include "ShaderView.h"

#include <cmath>

namespace Shadertoy
{
ShaderView::ShaderView(Program& programToRun)
{
    // A fullscreen shader has no geometric edges for multisampling to soften, so
    // the view's default 4x MSAA would shade every pixel four times over for an
    // image indistinguishable from the single-sampled one.
    setSampleCount(1);

    setHandlesMouseEvents(true);
    setContinuous(true);

    setProgram(programToRun);
}

void ShaderView::setProgram(Program& programToRun)
{
    program = &programToRun;
    buffers.clear();

    program->prepareFullscreen(sampleCount());
    restart();
}

void ShaderView::addBuffer(Buffer& buffer)
{
    buffers.add(&buffer);
}

void ShaderView::restart()
{
    elapsed = 0.0;
    frameDelta = 0.0;
    frameIndex = 0;

    // What a buffer accumulated outlives its clock, so a shader that feeds back
    // into itself would carry on from where it was however far iTime rewound.
    for (auto* buffer: buffers)
        buffer->clear();
}

void ShaderView::update(Threads::FrameTime time)
{
    frameDelta = time.delta;
    elapsed += time.delta;
    ++frameIndex;
}

void ShaderView::publishUniforms(Program& target, Graphics::Rect bounds, float scale)
{
    // Shadertoy measures iResolution and fragCoord in device pixels, so the
    // view's logical points scale up before they reach the shader. A shader
    // dividing by iResolution is unaffected either way; one drawing a fixed
    // pixel grid is not.
    target.iResolution = {bounds.w * scale, bounds.h * scale, 1.0f};
    target.iTime = (float) elapsed;
    target.iTimeDelta = (float) frameDelta;
    target.iFrame = frameIndex;
    target.iMouse = {pointer[0], pointer[1], click[0], click[1]};
}

void ShaderView::render(GPU::Frame& frame)
{
    auto bounds = getLocalBounds();
    auto scale = backingScale();

    auto pixelWidth = (int) std::lround(bounds.w * scale);
    auto pixelHeight = (int) std::lround(bounds.h * scale);

    // Every buffer runs, then every buffer swaps, then the image draws. Two
    // separate walks rather than one, because a buffer that swapped as soon as
    // it had run would publish this frame's output to the buffers after it and
    // last frame's to the ones before - and which of those a pass saw would
    // then depend on where in the list it happened to sit.
    for (auto* buffer: buffers)
    {
        publishUniforms(buffer->program, bounds, scale);
        buffer->resize(pixelWidth, pixelHeight);
        buffer->run(frame);
    }

    for (auto* buffer: buffers)
        buffer->swap();

    publishUniforms(*program, bounds, scale);
    program->refreshChannels();

    auto pass = frame.beginPass({backgroundColor});
    pass.draw(*program);
}

void ShaderView::mouseDown(const Graphics::MouseEvent& event)
{
    pointer = toShaderCoordinates(event.pos);
    click = pointer;
}

void ShaderView::mouseDragged(const Graphics::MouseEvent& event)
{
    pointer = toShaderCoordinates(event.pos);
}

void ShaderView::mouseUp(const Graphics::MouseEvent&)
{
    click = {-std::abs(click[0]), -std::abs(click[1])};
}

std::array<float, 2> ShaderView::toShaderCoordinates(Graphics::Point point) const
{
    auto bounds = getLocalBounds();
    auto scale = backingScale();

    return {point.x * scale, (bounds.h - point.y) * scale};
}
} // namespace Shadertoy
