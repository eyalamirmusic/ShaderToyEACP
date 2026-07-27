#include "Browser.h"
#include "CodeWindow.h"
#include "Toolbar.h"

#include <iostream>

using namespace eacp;
using namespace Shadertoy;

// The corpus, on screen. Every shader here was converted from GLSL by the
// transpiler at build time, and this walks through them one at a time.
//
// The report says a shader converted and RuntimeTests says the C++ it converted
// to compiles and draws what a handful of pixels expect. Neither says the frame
// looks like the shader - a march that terminates one step early still reports
// nothing, compiles, and renders something plausible - and this is where that
// gets looked at.
//
// Beside the frame there are two ways of finding a shader and reading one. The
// list down the left is the corpus by name, since a hundred and seventy shaders
// reached only by pressing the right arrow is a corpus nobody looks past the
// front of. Show Code puts the shader's GLSL and the C++ it converted to side
// by side in a window of their own, which is the comparison this whole project
// is about and the one thing a table of counts cannot show.
//
// Being a target is the other half of what it does: a shader that converts but
// does not compile breaks this build, which is the check no report can make.
namespace Gallery
{
namespace
{
// ShaderView already follows the pointer, which a shader reads as iMouse. The
// keys are the gallery's own, and are all this adds to it.
struct GalleryView final : ShaderView
{
    explicit GalleryView(Program& programToRun)
        : ShaderView(programToRun)
    {
        // So that clicking the shader after typing in the list hands the keys
        // back to it, rather than leaving the arrows filtering names.
        setGrabsFocusOnMouseDown();
    }

    void keyDown(const Graphics::KeyEvent& event) override { onKey(event.keyCode); }

    std::function<void(std::uint16_t)> onKey = [](std::uint16_t) {};
};

// Where the three pieces go: the list down the left, the strip along the
// bottom, and the shader in what is left - which is deliberately last, so the
// frame takes whatever the chrome did not.
struct Layout final : Graphics::View
{
    Layout(Graphics::View& browserToPlace,
           Graphics::View& shaderToPlace,
           Graphics::View& toolbarToPlace)
        : browser(browserToPlace)
        , shader(shaderToPlace)
        , toolbar(toolbarToPlace)
    {
        addChildren({browser, shader, toolbar});
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        toolbar.setBounds(bounds.removeFromBottom(Look::toolbarHeight));
        browser.setBounds(bounds.removeFromLeft(Look::sidebarWidth));
        shader.setBounds(bounds);
    }

    // The shader owns the keyboard whenever this window becomes key, rather
    // than the layout that happens to be the content view. Without this the
    // window hands focus to whichever view it likes when it is activated, and
    // the gallery's own keys - the arrows, space, C - land on a list that reads
    // every letter as something to filter by.
    void* nativeFocusTarget() override { return shader.getHandle(); }

    Graphics::View& browser;
    Graphics::View& shader;
    Graphics::View& toolbar;
};

// What the list is made of, said once at startup, because the two halves are
// different claims and the count of the second one is the thing stage 12 was
// for. A build with no external corpus says so by reporting none.
void announceCorpus(const Vector<Entry>& entries)
{
    auto measured = 0;

    for (const auto& entry: entries)
        measured += entry.measured ? 1 : 0;

    std::cout << entries.size() << " shaders: " << (entries.size() - measured)
              << " this repository holds and this build guarantees, " << measured
              << " a scan measured.\n"
              << "Arrows to walk them, space to restart, / to search by name.\n"
              << "Show Code, or C, opens the shader beside the C++ it became."
              << std::endl;
}

Graphics::WindowOptions windowOptions()
{
    auto options = Graphics::WindowOptions {};

    options.width = 1180;
    options.height = 760;
    options.minWidth = 640;
    options.minHeight = 360;
    options.title = "Gallery";
    options.backgroundColor = Look::panel;

    return options;
}

struct MyApp
{
    MyApp()
    {
        view.onKey = [this](std::uint16_t code) { handleKey(code); };

        browser.onPicked = [this](int picked) { show(picked); };
        browser.onDismissed = [this] { focusShader(); };

        toolbar.code.onClick = [this] { toggleCode(); };

        toolbar.restart.onClick = [this]
        {
            view.restart();
            focusShader();
        };

        // The code window can be closed from its own title bar, which nothing
        // here is told about. The main window coming back to the front is the
        // moment that matters - it is when the buttons are next looked at.
        window.events.onActivationChanged = [this](bool isKey)
        {
            if (isKey)
                syncButtons();
        };

        window.setContentView(layout);
        announceCorpus(entries);
        announce();
        focusShader();
    }

    void handleKey(std::uint16_t code)
    {
        if (code == Graphics::KeyCode::RightArrow
            || code == Graphics::KeyCode::DownArrow)
            show(index + 1);
        else if (code == Graphics::KeyCode::LeftArrow
                 || code == Graphics::KeyCode::UpArrow)
            show(index - 1);
        else if (code == Graphics::KeyCode::Space)
            view.restart();
        else if (code == Graphics::KeyCode::Slash)
            focusBrowser();
        else if (code == Graphics::KeyCode::C)
            toggleCode();
    }

    // The new shader is built before the old one is let go, so the view is
    // never pointed at a program that has been destroyed.
    void show(int next)
    {
        index = (next + entries.size()) % entries.size();

        auto loaded = entries[index].load();

        view.setProgram(loaded->image());
        loaded->addPassesTo(view);

        showing = std::move(loaded);

        browser.setShown(index);

        if (codeWindow != nullptr)
            codeWindow->setShader(entries[index].name, entries[index].listing);

        announce();
    }

    void focusShader()
    {
        view.focus();
        browser.repaint();
    }

    void focusBrowser()
    {
        browser.focus();
        browser.repaint();
    }

    void announce()
    {
        const auto& entry = entries[index];

        window.setTitle(entry.name);

        toolbar.setStatus(std::to_string(index + 1) + "/"
                          + std::to_string(entries.size())
                          + (entry.measured ? "   measured" : "   committed")
                          + "      arrows move  ·  space restarts  ·  / filters  ·  "
                            "C shows the code");
    }

    bool codeWindowOpen() { return codeWindow != nullptr && codeWindow->isOpen(); }

    // What the button does is decided against the window rather than against
    // what the button was last set to, since the window can be closed from its
    // own title bar without anything here being told.
    void toggleCode()
    {
        if (codeWindowOpen())
        {
            codeWindow->setOpen(false);
            syncButtons();
            return;
        }

        if (codeWindow == nullptr)
        {
            // Built the first time somebody asks for it, so a session that
            // never opens the code never rasterizes a glyph or parses a file.
            codeWindow = makeOwned<CodeWindow>();
            codeWindow->setShader(entries[index].name, entries[index].listing);
        }

        codeWindow->setOpen(true);
        syncButtons();
    }

    void syncButtons() { toolbar.code.setOn(codeWindowOpen()); }

    int index = 0;

    Vector<Entry> entries = corpus();
    OwningPointer<Showing> showing = entries[index].load();

    GalleryView view {showing->image()};
    Browser browser {entries};
    Toolbar toolbar;

    Layout layout {browser, view, toolbar};
    Graphics::Window window {windowOptions()};

    OwningPointer<CodeWindow> codeWindow;
};
} // namespace
} // namespace Gallery

int main()
{
    return eacp::Apps::run<Gallery::MyApp>();
}
