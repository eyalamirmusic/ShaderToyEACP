#pragma once

#include "Look.h"

#include <shadertoy/Runtime/Listing.h>

#include <ECodeEditor/CodeEditorView.h>

namespace Gallery
{
// One of the two texts, under a strip saying which one it is. The editor is
// ECode's, read-only and syntax coloured; what this adds is the label, since a
// window holding two of these has to say which is which.
class CodePane final : public eacp::Graphics::View
{
public:
    CodePane(std::string kindToShow, std::string extensionToShow);

    // What the pane shows, joined from the lines the listing holds. Empty when
    // there is no listing, which is a shader nothing was generated for rather
    // than an error.
    void show(const std::string& shaderName,
              std::span<const std::string_view> lines);

    void paint(eacp::Graphics::Context&) override;
    void resized() override;

private:
    // What kind of text this is ("Shadertoy GLSL"), and what the file holding
    // it is called - both drawn in the strip, since the second is the one that
    // says which pass of a multi-pass shader is on screen.
    std::string kind;
    std::string extension;
    std::string label;

    eacp::Graphics::Font font {Look::labelFont()};

    ecode::CodeEditorView editor;
};

// The shader's two texts, in a window of their own: the GLSL somebody wrote for
// the page, and the C++ the transpiler made of it.
//
// A window rather than a panel because two columns of code want the width and
// the shader wants the window it is running in. It shows both texts always:
// showing one of the two on its own is a file anybody could have opened in an
// editor, and reading them against each other is the whole reason it exists.
class CodeWindow
{
public:
    CodeWindow();

    // Which shader the panes are showing. Called whenever the gallery moves,
    // whether the window is open or not, so opening it later shows the shader
    // that is on screen rather than the one that was when it last closed.
    void setShader(const std::string& name, const Shadertoy::Listing* listing);

    void setOpen(bool shouldBeOpen);

    // Whether the window is on screen. It can be closed from its own title bar
    // without anything here being told, so the button asks this rather than
    // trusting what it last set.
    bool isOpen();

private:
    // The two texts, side by side, split down the middle.
    class Panes final : public eacp::Graphics::View
    {
    public:
        Panes();

        void resized() override;
        void paint(eacp::Graphics::Context&) override;

        CodePane glsl {"Shadertoy GLSL", ".glsl"};
        CodePane edsl {"generated EDSL", ".h"};
    };

    Panes panes;
    eacp::Graphics::Window window;
};
} // namespace Gallery
