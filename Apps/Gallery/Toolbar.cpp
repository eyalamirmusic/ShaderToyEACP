#include "Toolbar.h"

using namespace eacp;
using namespace eacp::Graphics;

namespace Gallery
{
namespace
{
constexpr auto buttonWidth = 96.f;
constexpr auto buttonGap = 8.f;
} // namespace

Button::Button(std::string labelToShow)
    : label(std::move(labelToShow))
{
    setHandlesMouseEvents();
}

Button& Button::latching()
{
    latches = true;
    return *this;
}

void Button::setOn(bool value)
{
    if (on == value)
        return;

    on = value;
    repaint();
}

void Button::mouseDown(const MouseEvent&)
{
    pressed = true;
    repaint();
}

void Button::mouseUp(const MouseEvent& event)
{
    pressed = false;
    repaint();

    // A press that wandered off the button before it was let go is a press
    // somebody changed their mind about.
    if (getLocalBounds().contains(event.pos))
        onClick();
}

void Button::mouseEntered(const MouseEvent&)
{
    repaint();
}

void Button::mouseExited(const MouseEvent&)
{
    repaint();
}

void Button::paint(Context& context)
{
    const auto bounds = getLocalBounds();

    auto fill = Look::edge;

    if (latches && on)
        fill = Look::shownRow;

    if (isHovering())
        fill = fill.brighter(0.06f);

    if (pressed)
        fill = fill.brighter(0.12f);

    context.setColor(fill);
    context.fillRoundedRect(bounds, 5.f);

    context.setColor(latches && on ? Look::text : Look::dimText);

    const auto width = TextMetrics::measureWidth(label, font);

    context.drawText(
        label, {bounds.center().x - width / 2.f, bounds.center().y + 4.f}, font);
}

Toolbar::Toolbar()
{
    code.latching();

    addChildren({code, restart});
}

void Toolbar::setStatus(std::string text)
{
    status = std::move(text);
    repaint();
}

void Toolbar::resized()
{
    auto bounds = getLocalBounds().inset(8.f, 6.f);

    code.setBounds(bounds.removeFromLeft(buttonWidth));
    bounds.removeFromLeft(buttonGap);

    restart.setBounds(bounds.removeFromLeft(buttonWidth));
}

void Toolbar::paint(Context& context)
{
    const auto bounds = getLocalBounds();

    context.setColor(Look::panel);
    context.fillRect(bounds);

    context.setColor(Look::edge);
    context.fillRect(bounds.fromTop(1.f));

    const auto width = TextMetrics::measureWidth(status, font);

    context.setColor(Look::dimText);
    context.drawText(
        status, {bounds.w - width - 12.f, bounds.center().y + 4.f}, font);
}
} // namespace Gallery
