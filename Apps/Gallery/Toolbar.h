#pragma once

#include "Look.h"

namespace Gallery
{
// A button that either latches or does not, drawn rather than assembled out of
// layers - there are two of them and they both look the same.
class Button final : public eacp::Graphics::View
{
public:
    explicit Button(std::string labelToShow);

    // A latching button says whether the thing it names is on; a momentary one
    // has nothing to stay lit about.
    Button& latching();

    void setOn(bool value);
    bool isOn() const { return on; }

    void paint(eacp::Graphics::Context&) override;
    void mouseDown(const eacp::Graphics::MouseEvent&) override;
    void mouseUp(const eacp::Graphics::MouseEvent&) override;
    void mouseEntered(const eacp::Graphics::MouseEvent&) override;
    void mouseExited(const eacp::Graphics::MouseEvent&) override;

    std::function<void()> onClick = [] {};

private:
    std::string label;

    bool latches = false;
    bool on = false;
    bool pressed = false;

    eacp::Graphics::Font font {Look::labelFont()};
};

// The strip along the bottom: the code window, the shader's clock, and where in
// the corpus the gallery is.
class Toolbar final : public eacp::Graphics::View
{
public:
    Toolbar();

    void setStatus(std::string text);

    void paint(eacp::Graphics::Context&) override;
    void resized() override;

    Button code {"Show Code"};
    Button restart {"Restart"};

private:
    std::string status;

    eacp::Graphics::Font font {Look::labelFont()};
};
} // namespace Gallery
