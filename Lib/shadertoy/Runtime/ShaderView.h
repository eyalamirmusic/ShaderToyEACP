#pragma once

#include "Program.h"

namespace Shadertoy
{
// Runs one ported Shadertoy inside the normal eacp view hierarchy: it drives the
// clock, follows the pointer, keeps iResolution in step with the view's size and
// redraws every display refresh.
//
// The view prepares the program in its constructor, so the program must outlive
// it - the usual shape is both as members of the same owner, program first.
class ShaderView : public GPU::GPUView
{
public:
    explicit ShaderView(Program& programToRun);

    // Rewinds iTime and iFrame, the way reloading the Shadertoy page does.
    void restart();

    void render(GPU::Frame&) override;
    void update(Threads::FrameTime) override;

    void mouseDown(const Graphics::MouseEvent&) override;
    void mouseDragged(const Graphics::MouseEvent&) override;
    void mouseUp(const Graphics::MouseEvent&) override;

    Graphics::Color backgroundColor = Graphics::Color::black();

private:
    // The pointer in the coordinates a shader reads: pixels rather than points,
    // with the origin at the bottom-left, matching fragCoord.
    std::array<float, 2> toShaderCoordinates(Graphics::Point point) const;

    Program& program;

    double elapsed = 0.0;
    double frameDelta = 0.0;
    int frameIndex = 0;

    std::array<float, 2> pointer {};

    // iMouse's zw pair, stored with the sign Shadertoy gives it rather than
    // recomputed: positive while the button is held, negative once it is
    // released. It starts negative so a shader gating on `iMouse.z > 0` sees no
    // click before the first one, which a plain (0, 0) could not express.
    std::array<float, 2> click {-1.0f, -1.0f};
};
} // namespace Shadertoy
