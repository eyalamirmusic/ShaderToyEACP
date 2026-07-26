#include "ShaderView.h"

#include <cmath>

namespace Shadertoy
{
ShaderView::ShaderView(Program& programToRun)
    : program(programToRun)
{
    // A fullscreen shader has no geometric edges for multisampling to soften, so
    // the view's default 4x MSAA would shade every pixel four times over for an
    // image indistinguishable from the single-sampled one.
    setSampleCount(1);

    setHandlesMouseEvents(true);
    setContinuous(true);

    program.prepareFullscreen(sampleCount());
}

void ShaderView::restart()
{
    elapsed = 0.0;
    frameDelta = 0.0;
    frameIndex = 0;
}

void ShaderView::update(Threads::FrameTime time)
{
    frameDelta = time.delta;
    elapsed += time.delta;
    ++frameIndex;
}

void ShaderView::render(GPU::Frame& frame)
{
    auto bounds = getLocalBounds();
    auto scale = backingScale();

    // Shadertoy measures iResolution and fragCoord in device pixels, so the
    // view's logical points scale up before they reach the shader. A shader
    // dividing by iResolution is unaffected either way; one drawing a fixed
    // pixel grid is not.
    program.iResolution = {bounds.w * scale, bounds.h * scale, 1.0f};
    program.iTime = (float) elapsed;
    program.iTimeDelta = (float) frameDelta;
    program.iFrame = (float) frameIndex;
    program.iMouse = {pointer[0], pointer[1], click[0], click[1]};

    auto pass = frame.beginPass({backgroundColor});
    pass.draw(program);
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
