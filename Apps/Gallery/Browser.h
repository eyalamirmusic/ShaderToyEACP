#pragma once

#include "Corpus.h"
#include "Look.h"

#include <eacp/Graphics/Graphics.h>

namespace Gallery
{
// The corpus by name, down the left of the window: type to narrow it, arrows to
// walk what is left, click or Return to show one.
//
// It draws its rows rather than holding a view per entry. There are close to
// two hundred of them and a filter changes which ones exist on every keystroke,
// so a view each would mean building and destroying a subtree per character
// typed - where this way only the twenty rows actually on screen cost anything.
class Browser final : public eacp::Graphics::View
{
public:
    explicit Browser(const eacp::Vector<Entry>& entriesToShow);

    // Points the list at the entry the gallery is showing and scrolls it into
    // view. Deliberately does not call onPicked: this is the gallery saying
    // where it went, which is the direction the callback does not run in.
    void setShown(int index);

    void paint(eacp::Graphics::Context&) override;
    void mouseDown(const eacp::Graphics::MouseEvent&) override;
    void mouseWheel(const eacp::Graphics::MouseEvent&) override;
    void keyDown(const eacp::Graphics::KeyEvent&) override;
    void resized() override;

    // Somebody chose an entry, by index into the corpus.
    std::function<void(int)> onPicked = [](int) {};

    // Escape with an empty filter, or Return: the browser is finished with the
    // keyboard and whoever handed it over should take it back.
    std::function<void()> onDismissed = [] {};

private:
    // The corpus indices whose names contain the filter, in corpus order.
    // Rebuilt on every keystroke, which for two hundred short strings is far
    // below what a frame would notice.
    void rebuildMatches();

    // Where in `matches` the keyboard is. Moving it shows that entry, so the
    // arrows walk the corpus here the way they do over the shader itself.
    void moveCursor(int by);

    void scrollCursorIntoView();

    eacp::Graphics::Rect listArea() const;
    int rowsOnScreen() const;

    // Which row of `matches` a point in the list is over, or -1 for none.
    int rowAt(eacp::Graphics::Point point) const;

    void paintFilter(eacp::Graphics::Context&, eacp::Graphics::Rect area) const;
    void paintRows(eacp::Graphics::Context&, eacp::Graphics::Rect area) const;

    const eacp::Vector<Entry>& entries;

    std::string filter;
    eacp::Vector<int> matches;

    // Both an index into the corpus: the row the gallery is drawing, and the
    // row the keyboard is on. They agree until the list is filtered down to
    // something the shown entry is not in.
    int shown = 0;
    int cursor = 0;

    // The first row of `matches` drawn, in rows rather than points, so a resize
    // cannot leave the list scrolled to half a line.
    int firstRow = 0;

    eacp::Graphics::Font font {Look::listFont()};
};
} // namespace Gallery
