#pragma once

#include "../Common.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

// Images to hand a channel, generated rather than shipped: Shadertoy's own
// textures are not ours to redistribute - see the licensing note in the README
// - and what a port sampling one needs from it is only that it be busy enough
// to show what the shader does to it.
namespace Shadertoy::ChannelImages
{
namespace Detail
{
inline std::uint32_t hash(int x, int y)
{
    auto value = (std::uint32_t) (x * 374761393 + y * 668265263);
    value = (value ^ (value >> 13)) * 1274126177;

    return value ^ (value >> 16);
}

inline std::uint32_t pack(int r, int g, int b)
{
    auto clamped = [](int channel)
    { return (std::uint32_t) std::clamp(channel, 0, 255); };

    return 0xff000000 | (clamped(b) << 16) | (clamped(g) << 8) | clamped(r);
}

inline GPU::Texture upload(const std::vector<std::uint32_t>& pixels, int size)
{
    auto descriptor = GPU::TextureDescriptor {};
    descriptor.width = size;
    descriptor.height = size;
    descriptor.format = GPU::TextureFormat::RGBA8Unorm;

    return GPU::Device::shared().makeTexture(descriptor, pixels.data());
}
} // namespace Detail

// Bricks, because the seams make motion through them legible, with a per-brick
// tint and a per-texel grain so neither the sampling nor the wrapping can hide.
inline GPU::Texture bricks(int size = 256)
{
    constexpr auto brickWidth = 64;
    constexpr auto brickHeight = 32;

    auto pixels = std::vector<std::uint32_t>((std::size_t) size * size);

    for (auto y = 0; y < size; ++y)
    {
        auto row = y / brickHeight;
        auto stagger = row % 2 == 0 ? 0 : brickWidth / 2;

        for (auto x = 0; x < size; ++x)
        {
            auto shifted = (x + stagger) % size;
            auto brick = Detail::hash(shifted / brickWidth, row);
            auto grain = (int) (Detail::hash(x, y) & 15) - 8;

            auto mortar = shifted % brickWidth < 3 || y % brickHeight < 3;

            auto r = mortar ? 62 : 96 + (int) (brick & 63);
            auto g = mortar ? 60 : 58 + (int) ((brick >> 8) & 31);
            auto b = mortar ? 58 : 46 + (int) ((brick >> 16) & 31);

            pixels[(std::size_t) y * size + x] =
                Detail::pack(r + grain, g + grain, b + grain);
        }
    }

    return Detail::upload(pixels, size);
}

// A second image that cannot be mistaken for the first, for the ports that read
// two channels: a shader sampling the same picture twice would look right
// however the two were wired.
inline GPU::Texture blobs(int size = 256)
{
    auto pixels = std::vector<std::uint32_t>((std::size_t) size * size);

    for (auto y = 0; y < size; ++y)
    {
        for (auto x = 0; x < size; ++x)
        {
            auto cell = Detail::hash(x / 32, y / 32);

            auto dx = (float) (x % 32) - 16.0f;
            auto dy = (float) (y % 32) - 16.0f;
            auto falloff =
                std::max(0.0f, 1.0f - std::sqrt(dx * dx + dy * dy) / 16.0f);

            auto r = (int) (falloff * (float) (60 + (cell & 195)));
            auto g = (int) (falloff * (float) (40 + ((cell >> 8) & 215)));
            auto b = (int) (falloff * (float) (90 + ((cell >> 16) & 165)));

            pixels[(std::size_t) y * size + x] = Detail::pack(r, g, b);
        }
    }

    return Detail::upload(pixels, size);
}
} // namespace Shadertoy::ChannelImages
