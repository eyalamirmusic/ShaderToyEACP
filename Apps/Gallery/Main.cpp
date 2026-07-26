#include <shadertoy/Runtime/ChannelImages.h>

#include <Basis.h>
#include <Channels.h>
#include <Checker.h>
#include <Compose.h>
#include <Facets.h>
#include <Fbm.h>
#include <Gradient.h>
#include <Kaleido.h>
#include <Lattice.h>
#include <Macros.h>
#include <Mandelbrot.h>
#include <Palette.h>
#include <Plasma.h>
#include <Raymarch.h>
#include <Surface.h>
#include <TrailBuffer.h>
#include <TrailImage.h>
#include <Tunnel.h>
#include <Voronoi.h>

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
// Being a target is the other half of what it does: a shader that converts but
// does not compile breaks this build, which is the check no report can make.
namespace
{
// One entry, alive: the program the view draws plus everything that has to
// outlive the draw - the buffers behind a multi-pass shader, the textures
// behind a channel.
struct Showing
{
    virtual ~Showing() = default;

    virtual Program& image() = 0;

    // Multi-pass shaders add theirs; everything else is one pass and adds none.
    virtual void addPassesTo(ShaderView&) {}
};

template <typename Port>
struct OnePass final : Showing
{
    Program& image() override { return shader; }

    Port shader;
};

// The two ports that read channels. The texture is declared before the program
// so it outlives every draw that samples it, and is bound after both are
// constructed - a port compiles from its channel's declaration, not from what
// happens to be in it.
struct ShowTunnel final : Showing
{
    ShowTunnel() { shader.iChannel0 = image0; }

    Program& image() override { return shader; }

    GPU::Texture image0 = ChannelImages::bricks();
    Ports::Tunnel shader;
};

struct ShowChannels final : Showing
{
    ShowChannels()
    {
        shader.iChannel0 = image0;
        shader.iChannel1 = image1;
    }

    Program& image() override { return shader; }

    GPU::Texture image0 = ChannelImages::bricks();
    GPU::Texture image1 = ChannelImages::blobs();
    Ports::Channels shader;
};

// The multi-pass one: Buffer A reads what it left there last frame, and the
// image pass shows what it accumulated.
struct ShowTrail final : Showing
{
    ShowTrail()
    {
        bufferShader.iChannel0 = buffer;
        imageShader.iChannel0 = buffer;
    }

    Program& image() override { return imageShader; }
    void addPassesTo(ShaderView& view) override { view.addBuffer(buffer); }

    Ports::TrailBuffer bufferShader;
    Ports::TrailImage imageShader;
    Buffer buffer {bufferShader};
};

struct Entry
{
    std::string name;
    std::function<OwningPointer<Showing>()> load;
};

template <typename Port>
Entry entryFor(std::string name)
{
    return {std::move(name), [] { return makeOwned<OnePass<Port>>(); }};
}

// Ordered as the stages that opened them, which is also roughly simplest
// first: what a shader needs from the EDSL grows down the list.
Vector<Entry> corpus()
{
    auto entries = Vector<Entry> {};

    entries.add(entryFor<Ports::Gradient>("Gradient"));
    entries.add(entryFor<Ports::Plasma>("Plasma"));
    entries.add(entryFor<Ports::Fbm>("Fbm"));
    entries.add(entryFor<Ports::Voronoi>("Voronoi"));
    entries.add(entryFor<Ports::Checker>("Checker"));
    entries.add(entryFor<Ports::Kaleido>("Kaleido"));
    entries.add({"Tunnel", [] { return makeOwned<ShowTunnel>(); }});
    entries.add({"Channels", [] { return makeOwned<ShowChannels>(); }});
    entries.add(entryFor<Ports::Raymarch>("Raymarch"));
    entries.add(entryFor<Ports::Mandelbrot>("Mandelbrot"));
    entries.add(entryFor<Ports::Palette>("Palette"));
    entries.add(entryFor<Ports::Lattice>("Lattice"));
    entries.add(entryFor<Ports::Surface>("Surface"));
    entries.add(entryFor<Ports::Facets>("Facets"));
    entries.add({"Trail", [] { return makeOwned<ShowTrail>(); }});
    entries.add(entryFor<Ports::Macros>("Macros"));
    entries.add(entryFor<Ports::Compose>("Compose"));
    entries.add(entryFor<Ports::Basis>("Basis"));

    return entries;
}

// ShaderView already follows the pointer, which a shader reads as iMouse. The
// keys are the gallery's own, and are all this adds to it.
struct GalleryView final : ShaderView
{
    using ShaderView::ShaderView;

    void keyDown(const Graphics::KeyEvent& event) override { onKey(event.keyCode); }

    std::function<void(std::uint16_t)> onKey = [](std::uint16_t) {};
};

struct MyApp
{
    MyApp()
    {
        view.onKey = [this](std::uint16_t code) { handleKey(code); };

        window.setContentView(view);
        announce();
        view.focus();
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
        announce();
    }

    void announce()
    {
        window.setTitle(std::to_string(index + 1) + "/"
                        + std::to_string(entries.size()) + "  " + entries[index].name
                        + "  -  arrows to move, space to restart");
    }

    int index = 0;

    Vector<Entry> entries = corpus();
    OwningPointer<Showing> showing = entries[index].load();

    GalleryView view {showing->image()};
    Graphics::Window window;
};
} // namespace

int main()
{
    return Apps::run<MyApp>();
}
