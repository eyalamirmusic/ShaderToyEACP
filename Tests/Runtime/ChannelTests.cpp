#include "Common.h"

#include <Tunnel.h>

// A channel a port declares has to survive the whole way to the draw: the
// member becomes a texture binding in the generated shader, the bind walk hands
// the assigned texture to the pass at that slot, and the body reads it through
// the sampler the port declared. Nothing on the CPU observes any of it - a
// channel that never reaches the GPU renders black and reports nothing - so the
// only thing that checks it is a frame rendered and read back.
//
// This is also the first of the reference-image layer the plan calls for, and
// it is here rather than over a corpus port because what is being pinned is the
// runtime path, not the transpiler.
//
// Self-skips without a GPU device.

using namespace nano;
using namespace eacp;

namespace
{
constexpr std::uint32_t red = 0xff0000ff; // RGBA8, little-endian: A B G R
constexpr std::uint32_t green = 0xff00ff00;

// Two texels side by side, red then green, so which half of the viewport a
// colour lands in says which texel was read.
GPU::Texture makeTwoTexelTexture()
{
    static std::uint32_t pixels[] = {red, green};

    auto descriptor = GPU::TextureDescriptor {};
    descriptor.width = 2;
    descriptor.height = 1;
    descriptor.format = GPU::TextureFormat::RGBA8Unorm;

    return GPU::Device::shared().makeTexture(descriptor, pixels);
}

// Shows nothing but its channel, so what reads back is what was bound. Nearest
// rather than the channel default, so a pixel is one texel rather than a blend
// of two and the check needs no tolerance.
struct SampledChannel final : Shadertoy::Program
{
    Shadertoy::Channel iChannel0;

    SHADERTOY_UNIFORMS(iChannel0)

    SampledChannel()
    {
        iChannel0.texture.sampling.filter = GPU::TextureFilter::Nearest;
        compile();
    }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        return sample(iChannel0, fragCoord / iResolution.xy());
    }
};

// The same two texels through the read that takes no sampler at all. It
// addresses texels rather than the unit square, so it only has coordinates to
// work in because assigning the texture published its size.
struct FetchedChannel final : Shadertoy::Program
{
    Shadertoy::Channel iChannel0;

    SHADERTOY_UNIFORMS(iChannel0)

    FetchedChannel() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();
        return fetch(iChannel0, iChannel0.resolution.xy() * uv);
    }
};

Graphics::Image render(Shadertoy::Program& program)
{
    auto view = Shadertoy::ShaderView {program};
    view.setBounds({0.0f, 0.0f, 16.0f, 4.0f});

    return view.renderToImage(1.0f);
}

// A single red texel, so a shader sampling anywhere in the image gets the same
// answer and what the picture shows is only whether it sampled at all.
GPU::Texture makeSolidTexture()
{
    static std::uint32_t pixels[] = {red};

    auto descriptor = GPU::TextureDescriptor {};
    descriptor.width = 1;
    descriptor.height = 1;
    descriptor.format = GPU::TextureFormat::RGBA8Unorm;

    return GPU::Device::shared().makeTexture(descriptor, pixels);
}

bool isRed(const Graphics::Color& color)
{
    return color.r > 0.5f && color.g < 0.5f;
}

bool isGreen(const Graphics::Color& color)
{
    return color.g > 0.5f && color.r < 0.5f;
}
} // namespace

// The texture assigned to a channel is the one the shader reads, at the slot
// the port declared it on. Black anywhere here means the binding never arrived.
auto tBoundTextureIsSampled = test("Channel/boundTextureIsSampled") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto texture = makeTwoTexelTexture();

    if (!texture.isValid())
        return;

    auto shader = SampledChannel {};
    shader.iChannel0 = texture;

    auto image = render(shader);

    check(image.isValid());
    check(isRed(image.at(2, 2)));
    check(isGreen(image.at(13, 2)));
};

// The same thing over a port nobody wrote: Tunnel.glsl through the transpiler,
// which is where the channel member, the SHADERTOY_UNIFORMS list and the
// sample() call are all generated rather than typed. The shader fades to black
// towards the centre, so the corners are what carry the colour.
auto tGeneratedPortSamplesItsChannel = test("Channel/generatedPortSamples") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto texture = makeSolidTexture();

    if (!texture.isValid())
        return;

    auto shader = Shadertoy::Ports::Tunnel {};
    shader.iChannel0 = texture;

    auto image = render(shader);

    check(image.isValid());
    check(isRed(image.at(0, 0)));
    check(isRed(image.at(15, 3)));
};

// The same texture read texel by texel. Both backends spell this differently
// from a sample and neither goes through the sampler, so it is its own path to
// the same pixels - and it is the one that would silently read nothing if the
// size the channel publishes were wrong.
auto tFetchedTexelsAreTheStoredColours = test("Channel/fetchReadsTheTexels") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto texture = makeTwoTexelTexture();

    if (!texture.isValid())
        return;

    auto shader = FetchedChannel {};
    shader.iChannel0 = texture;

    check(shader.iChannel0.resolution.value == std::array {2.0f, 1.0f, 1.0f});

    auto image = render(shader);

    check(image.isValid());
    check(isRed(image.at(2, 2)));
    check(isGreen(image.at(13, 2)));
};
