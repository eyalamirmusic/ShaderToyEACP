#include "Browser.h"

#include <algorithm>
#include <cctype>

using namespace eacp;
using namespace eacp::Graphics;

namespace Gallery
{
namespace
{
std::string lowered(std::string text)
{
    for (auto& character: text)
        character = (char) std::tolower((unsigned char) character);

    return text;
}

// A name cut down to what fits, with an ellipsis where the rest went. Measured
// rather than counted, because the list is set in a proportional face and
// "Mandelbrot" and "IIIIIIIIII" are not the same width.
std::string fitted(const std::string& name, float available, const Font& font)
{
    if (TextMetrics::measureWidth(name, font) <= available)
        return name;

    auto cut = name;

    while (!cut.empty() && TextMetrics::measureWidth(cut + "...", font) > available)
        cut.pop_back();

    return cut + "...";
}
} // namespace

Browser::Browser(const Vector<Entry>& entriesToShow)
    : entries(entriesToShow)
{
    setHandlesMouseEvents().setGrabsFocusOnMouseDown();
    rebuildMatches();
}

void Browser::rebuildMatches()
{
    const auto needle = lowered(filter);

    matches.clear();
    matches.reserve(entries.size());

    for (auto index = 0; index < entries.size(); ++index)
        if (needle.empty()
            || lowered(entries[index].name).find(needle) != std::string::npos)
            matches.add(index);

    // The cursor follows the shown entry while the shown entry is still in the
    // list, and falls to the top when a filter has excluded it - which is what
    // makes typing a few letters and pressing Return reach the one match.
    cursor = 0;

    for (auto row = 0; row < matches.size(); ++row)
        if (matches[row] == shown)
            cursor = row;

    scrollCursorIntoView();
    repaint();
}

void Browser::setShown(int index)
{
    shown = index;

    for (auto row = 0; row < matches.size(); ++row)
        if (matches[row] == shown)
        {
            cursor = row;
            scrollCursorIntoView();
        }

    repaint();
}

Rect Browser::listArea() const
{
    auto bounds = getLocalBounds();
    bounds.removeFromTop(Look::filterHeight);

    return bounds;
}

int Browser::rowsOnScreen() const
{
    return std::max(1, (int) (listArea().h / Look::rowHeight));
}

void Browser::scrollCursorIntoView()
{
    const auto visible = rowsOnScreen();

    firstRow = std::min(firstRow, cursor);
    firstRow = std::max(firstRow, cursor - visible + 1);
    firstRow = std::clamp(firstRow, 0, std::max(0, matches.size() - visible));
}

void Browser::moveCursor(int by)
{
    if (matches.empty())
        return;

    cursor = std::clamp(cursor + by, 0, matches.size() - 1);
    scrollCursorIntoView();

    // Shown as it is reached rather than on Return, so walking the list here is
    // the same gesture as walking it with the arrows over the shader.
    onPicked(matches[cursor]);
}

int Browser::rowAt(Point point) const
{
    const auto area = listArea();

    if (!area.contains(point))
        return -1;

    const auto row = firstRow + (int) ((point.y - area.y) / Look::rowHeight);

    return row < matches.size() ? row : -1;
}

void Browser::mouseDown(const MouseEvent& event)
{
    const auto row = rowAt(event.pos);

    if (row < 0)
        return;

    cursor = row;
    onPicked(matches[row]);
}

void Browser::mouseWheel(const MouseEvent& event)
{
    // A notched wheel reports lines and a trackpad reports points, so one of
    // them has to be converted before they can be added to the same figure.
    const auto lines =
        event.preciseScrolling ? event.delta.y / Look::rowHeight : event.delta.y;

    firstRow = std::clamp(
        firstRow - (int) lines, 0, std::max(0, matches.size() - rowsOnScreen()));
    repaint();
}

void Browser::keyDown(const KeyEvent& event)
{
    if (event.modifiers.command)
        return;

    if (event.keyCode == KeyCode::UpArrow)
        return moveCursor(-1);

    if (event.keyCode == KeyCode::DownArrow)
        return moveCursor(1);

    if (event.keyCode == KeyCode::PageUp)
        return moveCursor(-rowsOnScreen());

    if (event.keyCode == KeyCode::PageDown)
        return moveCursor(rowsOnScreen());

    if (event.keyCode == KeyCode::Home)
        return moveCursor(-matches.size());

    if (event.keyCode == KeyCode::End)
        return moveCursor(matches.size());

    if (event.keyCode == KeyCode::Return)
    {
        if (!matches.empty())
            onPicked(matches[cursor]);

        return onDismissed();
    }

    if (event.keyCode == KeyCode::Escape)
    {
        // The filter first, the keyboard second: one Escape undoes the typing
        // and a second hands the keyboard back, so neither needs its own key.
        if (filter.empty())
            return onDismissed();

        filter.clear();
        return rebuildMatches();
    }

    if (event.keyCode == KeyCode::Delete)
    {
        if (filter.empty())
            return;

        filter.pop_back();
        return rebuildMatches();
    }

    if (event.characters.empty())
        return;

    const auto typed = event.characters[0];

    if (typed >= ' ' && typed < 0x7f)
    {
        filter += event.characters;
        rebuildMatches();
    }
}

void Browser::resized()
{
    scrollCursorIntoView();
}

void Browser::paintFilter(Context& context, Rect area) const
{
    const auto baseline = area.y + area.h - 10.f;

    context.setColor(hasFocus() ? Look::accent : Look::dimText);
    context.drawText(hasFocus() ? "\xe2\x96\xb8" : "/", {10.f, baseline}, font);

    context.setColor(filter.empty() ? Look::dimText : Look::text);

    context.drawText(filter.empty() ? "filter" : filter, {24.f, baseline}, font);

    // The two numbers the filter is for: how many names it left, out of how
    // many there are.
    const auto count =
        std::to_string(matches.size()) + "/" + std::to_string(entries.size());

    const auto width = TextMetrics::measureWidth(count, font);

    context.setColor(Look::dimText);
    context.drawText(count, {area.w - width - 10.f, baseline}, font);

    context.setColor(Look::edge);
    context.fillRect(area.fromBottom(1.f));
}

void Browser::paintRows(Context& context, Rect area) const
{
    const auto last = std::min(matches.size(), firstRow + rowsOnScreen() + 1);

    for (auto row = firstRow; row < last; ++row)
    {
        const auto& entry = entries[matches[row]];

        const auto line = Rect {area.x,
                                area.y + (float) (row - firstRow) * Look::rowHeight,
                                area.w,
                                Look::rowHeight};

        if (matches[row] == shown)
        {
            context.setColor(Look::shownRow);
            context.fillRect(line);
        }
        else if (row == cursor && hasFocus())
        {
            context.setColor(Look::cursorRow);
            context.fillRect(line);
        }

        // The measured half reads second: those are shaders a scan says
        // converted and compiled, and nothing says the frame is right.
        context.setColor(entry.measured && matches[row] != shown ? Look::dimText
                                                                 : Look::text);

        context.drawText(fitted(entry.name, line.w - 24.f, font),
                         {line.x + 10.f, line.y + line.h - 5.f},
                         font);
    }
}

void Browser::paint(Context& context)
{
    const auto bounds = getLocalBounds();

    context.setColor(Look::panel);
    context.fillRect(bounds);

    paintFilter(context, bounds.fromTop(Look::filterHeight));
    paintRows(context, listArea());

    context.setColor(Look::edge);
    context.fillRect(bounds.fromRight(1.f));
}
} // namespace Gallery
