#pragma once

#include <eacp/Graphics/Graphics.h>

// The gallery's own chrome, in one place so the sidebar and the strip under it
// cannot drift apart. Dark throughout, because everything here sits beside a
// running shader and the shader should be the brightest thing on screen.
namespace Gallery::Look
{
constexpr auto panel = eacp::Graphics::Color {0.09f, 0.10f, 0.12f};
constexpr auto edge = eacp::Graphics::Color {0.18f, 0.19f, 0.22f};
constexpr auto text = eacp::Graphics::Color {0.85f, 0.87f, 0.91f};

// Everything that is there to be read second: the measured half's names, the
// counts, a field nobody has typed in yet.
constexpr auto dimText = eacp::Graphics::Color {0.48f, 0.51f, 0.56f};

// The row the gallery is showing, and the row the keyboard is on. Two, because
// walking the list with the arrows moves one of them ahead of the other.
constexpr auto shownRow = eacp::Graphics::Color {0.14f, 0.28f, 0.50f};
constexpr auto cursorRow = eacp::Graphics::Color {0.16f, 0.17f, 0.20f};

constexpr auto accent = eacp::Graphics::Color {0.42f, 0.64f, 1.0f};

constexpr auto rowHeight = 19.f;
constexpr auto sidebarWidth = 214.f;
constexpr auto filterHeight = 30.f;
constexpr auto toolbarHeight = 34.f;

inline eacp::Graphics::FontOptions listFont()
{
    return {"Helvetica", 12.f};
}

inline eacp::Graphics::FontOptions labelFont()
{
    return {"Helvetica", 12.f};
}
} // namespace Gallery::Look
