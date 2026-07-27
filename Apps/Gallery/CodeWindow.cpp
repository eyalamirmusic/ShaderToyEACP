#include "CodeWindow.h"

#include <ECodeSyntax/SyntaxHighlighter.h>

using namespace eacp;
using namespace eacp::Graphics;

namespace Gallery
{
namespace
{
constexpr auto headerHeight = 26.f;

std::string joined(std::span<const std::string_view> lines)
{
    auto count = std::size_t {};

    for (const auto& line: lines)
        count += line.size() + 1;

    auto text = std::string {};
    text.reserve(count);

    for (const auto& line: lines)
    {
        text.append(line);
        text += '\n';
    }

    return text;
}

WindowOptions codeWindowOptions()
{
    auto options = WindowOptions {};

    options.width = 1120;
    options.height = 760;
    options.minWidth = 420;
    options.minHeight = 260;
    options.title = "Shader source";
    options.backgroundColor = Look::panel;

    // Closing this one is a way of putting the code away, not of leaving the
    // gallery - and the state it leaves behind (the scroll position in a file
    // somebody was reading) is worth keeping for the next time a button is
    // pressed.
    options.isPrimary = false;
    options.hidesOnClose = true;

    return options;
}

// C++'s grammar over both texts, which is not a mistake for the GLSL one.
// Shadertoy GLSL is close enough to C that tree-sitter's C++ parser reads the
// declarations, the calls and the literals correctly; the handful of words it
// has and C++ does not - `in`, `out`, the vector types - come out as plain
// identifiers rather than wrong. A GLSL grammar would be better and is not
// something to hold up a code view for.
OwningPointer<ecode::Highlighter> highlighter()
{
    auto syntax = makeOwned<ecode::SyntaxHighlighter>(
        ecode::SyntaxHighlighter::frameParseBudget);

    if (!syntax->isValid())
        return {};

    return OwningPointer<ecode::Highlighter> {std::move(syntax)};
}
} // namespace

CodePane::CodePane(std::string kindToShow, std::string extensionToShow)
    : kind(std::move(kindToShow))
    , extension(std::move(extensionToShow))
{
    editor.setReadOnly(true);
    editor.setHighlighter(highlighter());

    addSubview(editor);
}

void CodePane::show(const std::string& shaderName,
                    std::span<const std::string_view> lines)
{
    label = shaderName + extension;
    editor.setText(joined(lines));

    repaint();
}

void CodePane::resized()
{
    auto bounds = getLocalBounds();
    bounds.removeFromTop(headerHeight);

    editor.setBounds(bounds);
}

void CodePane::paint(Context& context)
{
    const auto header = getLocalBounds().fromTop(headerHeight);

    context.setColor(Look::panel);
    context.fillRect(header);

    context.setColor(Look::text);
    context.drawText(label, {12.f, header.h - 8.f}, font);

    const auto width = TextMetrics::measureWidth(kind, font);

    context.setColor(Look::dimText);
    context.drawText(kind, {header.w - width - 12.f, header.h - 8.f}, font);

    context.setColor(Look::edge);
    context.fillRect(header.fromBottom(1.f));
}

CodeWindow::Panes::Panes()
{
    addChildren({glsl, edsl});
}

void CodeWindow::Panes::resized()
{
    auto bounds = getLocalBounds();

    // Down the middle, with a line's worth between them: the two texts are the
    // same shader said twice, so neither half has a claim on more room than the
    // other.
    glsl.setBounds(bounds.removeFromLeft((bounds.w - 1.f) / 2.f));
    bounds.removeFromLeft(1.f);
    edsl.setBounds(bounds);
}

void CodeWindow::Panes::paint(Context& context)
{
    context.setColor(Look::edge);
    context.fillRect(getLocalBounds());
}

CodeWindow::CodeWindow()
    : window(codeWindowOptions())
{
    window.setContentView(panes);
}

void CodeWindow::setShader(const std::string& name,
                           const Shadertoy::Listing* listing)
{
    panes.glsl.show(name,
                    listing != nullptr ? listing->glsl
                                       : std::span<const std::string_view> {});
    panes.edsl.show(name,
                    listing != nullptr ? listing->edsl
                                       : std::span<const std::string_view> {});

    window.setTitle(name + "  -  source and generated EDSL");
}

void CodeWindow::setOpen(bool shouldBeOpen)
{
    window.setVisible(shouldBeOpen);
}

bool CodeWindow::isOpen()
{
    return window.isVisible();
}
} // namespace Gallery
