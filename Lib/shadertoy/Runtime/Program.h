#pragma once

#include "../Common.h"

namespace Shadertoy
{
// The geometry a Shadertoy runs over: one oversized triangle covering the whole
// viewport. A triangle rather than a quad because a quad's two halves meet on a
// diagonal, and the rasterizer shades the pixels along that seam twice.
//
// uv reaches 0 at the bottom-left of the viewport and 1 at the top-right, which
// is where Shadertoy puts fragCoord's origin. Clip space has y up on both
// backends, so the vertices at clip y = -1 are the bottom of the screen and take
// uv.y = 0.
struct FullscreenVertex
{
    float position[2];
    float uv[2];
};

inline constexpr FullscreenVertex fullscreenTriangle[] = {
    {{-1.0f, -1.0f}, {0.0f, 0.0f}},
    {{3.0f, -1.0f}, {2.0f, 0.0f}},
    {{-1.0f, 3.0f}, {0.0f, 2.0f}},
};

// Base for a ported Shadertoy. It owns everything the original page supplies
// implicitly - the fullscreen geometry, the uniform set, the clip-space
// position - so a port is only the body of mainImage:
//
//   struct MyShader final : Shadertoy::Program
//   {
//       MyShader() { compile(); }
//
//       GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
//       {
//           auto uv = fragCoord / iResolution.xy();
//           return float4(uv, 0.5f + 0.5f * sin(iTime), 1.0f);
//       }
//   };
//
// compile() has to run from the most-derived constructor, as it does for any
// eacp ShaderProgram: it walks the uniform members and then calls define(),
// which reaches mainImage through the vtable.
//
// The uniforms keep Shadertoy's names, so a ported body reads the same as the
// GLSL it came from. Two deviations, both because the EDSL has no integer value
// type usable in float arithmetic yet: iFrame is a float, and iDate is absent.
// Texture channels (iChannel0..3) are absent as well - they arrive with the
// texture stage of the plan.
class Program : public GPU::ShaderProgram
{
public:
    GPU::Uniform<GPU::Float3> iResolution; // viewport size in pixels, then 1
    GPU::Uniform<GPU::Float> iTime; // seconds since the shader started
    GPU::Uniform<GPU::Float> iTimeDelta; // seconds the previous frame took
    GPU::Uniform<GPU::Float> iFrame; // frames drawn since the start
    GPU::Uniform<GPU::Float4> iMouse; // xy = pointer, zw = click (see below)

    // Uploads the fullscreen triangle and builds the pipeline. sampleCount comes
    // from the view being drawn into, as it does for a plain ShaderProgram.
    void prepareFullscreen(int sampleCount)
    {
        setVertices(fullscreenTriangle);
        prepare(sampleCount);
    }

protected:
    // The ported body. fragCoord is in pixels with the origin at the bottom-left
    // corner of the viewport, exactly what Shadertoy hands mainImage, and the
    // returned value is its fragColor.
    virtual GPU::Float4 mainImage(const GPU::Float2& fragCoord) = 0;

    // Uniforms a port needs beyond the Shadertoy set - rare, since a faithful
    // port takes everything from the ones above. Declare them as members and
    // list them here with SHADERTOY_UNIFORMS.
    virtual void reflectExtraUniforms(GPU::ShaderVisitor&) {}

private:
    // The whole vertex stage of a Shadertoy: pass the covering triangle through
    // untransformed and carry uv across to the fragment stage, where it scales
    // up into the pixel coordinate mainImage expects.
    void define() final
    {
        auto position = vertexInput(&FullscreenVertex::position);
        auto uv = vertexInput(&FullscreenVertex::uv);

        setPosition(float4(position, 0.0f, 1.0f));
        setFragment(mainImage(varying(uv) * iResolution.xy()));
    }

    void reflectMembers(GPU::ShaderVisitor& visitor) final
    {
        visitor("iResolution", iResolution);
        visitor("iTime", iTime);
        visitor("iTimeDelta", iTimeDelta);
        visitor("iFrame", iFrame);
        visitor("iMouse", iMouse);

        reflectExtraUniforms(visitor);
    }
};
} // namespace Shadertoy

// Lists a port's extra uniform members, the way EACP_SHADER lists a plain
// ShaderProgram's. The Shadertoy set is already declared by the base, so this
// names only what the port added.
#define SHADERTOY_UNIFORMS(...)                                                     \
    void reflectExtraUniforms(eacp::GPU::ShaderVisitor& visitor) override           \
    {                                                                               \
        EACP_GPU_FIELDS(visitor, __VA_ARGS__)                                       \
    }
