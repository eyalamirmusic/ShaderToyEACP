#pragma once

#include "Buffer.h"

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

    // Points the view at a different program, which is what a gallery does when
    // it moves to the next shader. The buffers go with it - a buffer belongs to
    // the shader that reads it rather than to the view - and the clock rewinds,
    // since a shader that accumulates has nothing yet to accumulate from.
    void setProgram(Program& programToRun);

    // Adds an off-screen pass that runs before the image - Buffer A through D,
    // in the order they are added. The buffer must outlive the view, which the
    // usual shape gives for free: the programs, the buffers and the view are
    // members of one owner, in that order.
    //
    // Every buffer runs, then every buffer swaps, then the image draws. So the
    // image sees what the buffers produced this frame, and a buffer reading any
    // buffer - itself included - sees the frame before. That is one rule rather
    // than two, and it is the one that makes feedback mean what it says.
    void addBuffer(Buffer& buffer);

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

    // The Shadertoy set, applied to one pass. Every pass of a multi-pass shader
    // gets the same values, since the page publishes one clock and one
    // resolution however many buffers read them.
    void publishUniforms(Program& target, Graphics::Rect bounds, float scale);

    Program* program = nullptr;

    Vector<Buffer*> buffers;

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
