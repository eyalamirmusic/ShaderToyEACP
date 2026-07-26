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

// One of Shadertoy's four texture channels: the texture a port samples, and the
// size the page publishes beside it as iChannelResolution. They are one member
// rather than two because assigning the texture fills both, so a port cannot
// sample an image while reporting the dimensions of a different one.
//
// The sampling is Shadertoy's default for a channel rather than eacp's for a
// texture - bilinear and wrapping, which is what a shader scrolling a
// coordinate past 1 expects. A port that needs the other one sets `sampling`
// before compile() runs; it is baked into the pipeline, not chosen per draw.
struct Channel
{
    Channel()
    {
        texture.sampling = {GPU::TextureFilter::Linear,
                            GPU::TextureAddressMode::Repeat};
    }

    // A channel stands in for its texture wherever one is sampled, so a ported
    // body spells sample(iChannel0, uv) the way the GLSL it came from spelled
    // texture(iChannel0, uv).
    operator const GPU::Texture2D&() const { return texture; }

    Channel& operator=(const GPU::Texture& newTexture)
    {
        texture = newTexture;

        resolution = {(float) newTexture.width(), (float) newTexture.height(), 1.0f};

        return *this;
    }

    GPU::Uniform<GPU::Texture2D> texture;
    GPU::Uniform<GPU::Float3> resolution;
};

// Adapts eacp's uniform walk to what a port declares on top of it, so
// SHADERTOY_UNIFORMS takes a Channel and a plain Uniform in the same list: a
// Channel is two members eacp knows separately, and they have to reach the
// visitor in declaration order for the slots they take to be the ones the
// generated shader reads.
class ExtraUniformVisitor
{
public:
    explicit ExtraUniformVisitor(GPU::ShaderVisitor& visitorToUse)
        : visitor(visitorToUse)
    {
    }

    template <typename T>
    void operator()(const char* name, GPU::Uniform<T>& member)
    {
        visitor(name, member);
    }

    void operator()(const char* name, Channel& channel)
    {
        visitor(name, channel.texture);
        visitor(name, channel.resolution);
    }

private:
    GPU::ShaderVisitor& visitor;
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
// The uniforms keep Shadertoy's names and Shadertoy's types, so a ported body
// reads the same as the GLSL it came from - iFrame included, which is an int on
// the page and an Int here. One deviation is left: iDate is absent, which is a
// clock this runtime does not have rather than a type the EDSL is missing.
//
// Texture channels are not declared here. A port declares the ones it samples
// and no others, because every declared texture becomes a binding the draw has
// to satisfy - four channels on the base would make every port, textured or
// not, carry four textures it never reads:
//
//       Channel iChannel0;
//       SHADERTOY_UNIFORMS(iChannel0)
class Program : public GPU::ShaderProgram
{
public:
    GPU::Uniform<GPU::Float3> iResolution; // viewport size in pixels, then 1
    GPU::Uniform<GPU::Float> iTime; // seconds since the shader started
    GPU::Uniform<GPU::Float> iTimeDelta; // seconds the previous frame took
    GPU::Uniform<GPU::Int> iFrame; // frames drawn since the start
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

    // What a port declares beyond the Shadertoy set: the texture channels it
    // samples, and any uniform of its own - rare, since a faithful port takes
    // everything from the ones above. Declare them as members and list them
    // here with SHADERTOY_UNIFORMS.
    virtual void reflectExtraUniforms(ExtraUniformVisitor&) {}

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

        auto extra = ExtraUniformVisitor {visitor};
        reflectExtraUniforms(extra);
    }
};
} // namespace Shadertoy

// Lists a port's texture channels and extra uniform members, the way
// EACP_SHADER lists a plain ShaderProgram's. The Shadertoy set is already
// declared by the base, so this names only what the port added.
#define SHADERTOY_UNIFORMS(...)                                                     \
    void reflectExtraUniforms(Shadertoy::ExtraUniformVisitor& visitor) override     \
    {                                                                               \
        EACP_GPU_FIELDS(visitor, __VA_ARGS__)                                       \
    }
