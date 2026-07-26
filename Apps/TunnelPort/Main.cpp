#include <Tunnel.h>

#include <algorithm>
#include <vector>

using namespace eacp;

// A textured Shadertoy, converted from Tunnel.glsl at build time: polar
// coordinates into a channel, which is the shape most of the corpus's textured
// shaders have. The port is the body of mainImage, as ever; the one thing the
// app supplies on top of it is the image that channel reads.
namespace
{
constexpr auto textureSize = 256;
constexpr auto brickWidth = 64;
constexpr auto brickHeight = 32;

std::uint32_t hash(int x, int y)
{
    auto value = (std::uint32_t) (x * 374761393 + y * 668265263);
    value = (value ^ (value >> 13)) * 1274126177;

    return value ^ (value >> 16);
}

std::uint32_t pack(int r, int g, int b)
{
    auto clamped = [](int channel)
    { return (std::uint32_t) std::clamp(channel, 0, 255); };

    return 0xff000000 | (clamped(b) << 16) | (clamped(g) << 8) | clamped(r);
}

// The channel image, generated rather than shipped: Shadertoy's own textures
// are not ours to redistribute - see the licensing note in the README - and
// what this shader needs from one is only that it be busy enough to show the
// tunnel moving through it. Bricks, because the seams make the motion legible,
// with a per-brick tint and a per-texel grain so neither the sampling nor the
// wrapping can hide.
GPU::Texture makeChannelTexture()
{
    auto pixels = std::vector<std::uint32_t>(textureSize * textureSize);

    for (auto y = 0; y < textureSize; ++y)
    {
        auto row = y / brickHeight;
        auto stagger = row % 2 == 0 ? 0 : brickWidth / 2;

        for (auto x = 0; x < textureSize; ++x)
        {
            auto shifted = (x + stagger) % textureSize;
            auto brick = hash(shifted / brickWidth, row);
            auto grain = (int) (hash(x, y) & 15) - 8;

            auto mortar = shifted % brickWidth < 3 || y % brickHeight < 3;

            auto r = mortar ? 62 : 96 + (int) (brick & 63);
            auto g = mortar ? 60 : 58 + (int) ((brick >> 8) & 31);
            auto b = mortar ? 58 : 46 + (int) ((brick >> 16) & 31);

            pixels[y * textureSize + x] = pack(r + grain, g + grain, b + grain);
        }
    }

    auto descriptor = GPU::TextureDescriptor {};
    descriptor.width = textureSize;
    descriptor.height = textureSize;
    descriptor.format = GPU::TextureFormat::RGBA8Unorm;

    return GPU::Device::shared().makeTexture(descriptor, pixels.data());
}

struct MyApp
{
    MyApp()
    {
        // Assigning the texture also publishes its size as the channel's
        // iChannelResolution, which is what a shader fetching texels reads.
        shader.iChannel0 = bricks;

        window.setContentView(view);
        window.setTitle("Tunnel (transpiled)");
    }

    // The program holds a pointer to the bound texture, so the texture is
    // declared first and outlives every draw that reads it.
    GPU::Texture bricks = makeChannelTexture();
    Shadertoy::Ports::Tunnel shader;
    Shadertoy::ShaderView view {shader};
    Graphics::Window window;
};
} // namespace

int main()
{
    return Apps::run<MyApp>();
}
