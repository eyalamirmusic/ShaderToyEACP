#include <shadertoy/Runtime/ChannelImages.h>

#include <iostream>

#include <Basis.h>
#include <Blanks.h>
#include <Channels.h>
#include <Checker.h>
#include <Compose.h>
#include <Facets.h>
#include <Fbm.h>
#include <Gradient.h>
#include <Kaleido.h>
#include <Lattice.h>
#include <Literals.h>
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

#include <S3l23RK.h>
#include <S4ssSRl.h>
#include <S7d23DR.h>
#include <ScsscRl.h>
#include <SctdfzN.h>
#include <SdldyWN.h>
#include <SftVXRc.h>
#include <SsdVyWt.h>

// The measured half, when the build was pointed at a directory of it with
// -DSHADERTOY_EXTERNAL_CORPUS. It is one file written by shadertoy-scan
// --register: the includes for every shader of a corpus that converted and
// then compiled, and an X-macro naming them.
#if __has_include(<ExternalCorpus.h>)
#include <ExternalCorpus.h>
#endif

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

// A port nobody wired up, which is what every shader of an external corpus is.
// Each of the ones below declares exactly the channels its shader sampled, and
// every declared texture is a binding the draw has to satisfy - but what the
// page bound them to is not in the GLSL and not in the corpus. So they get a
// generated image, and the frame is the shader's own arithmetic over something
// rather than a draw missing a binding.
//
// The texture is declared before the program so it outlives every draw that
// samples it, and bound after both are constructed, exactly as a hand-wired
// entry does it.
template <typename Port>
struct Unwired final : Showing
{
    Unwired()
    {
        if constexpr (requires { shader.iChannel0; })
            shader.iChannel0 = standIn;

        if constexpr (requires { shader.iChannel1; })
            shader.iChannel1 = standIn;

        if constexpr (requires { shader.iChannel2; })
            shader.iChannel2 = standIn;

        if constexpr (requires { shader.iChannel3; })
            shader.iChannel3 = standIn;
    }

    Program& image() override { return shader; }

    GPU::Texture standIn = ChannelImages::bricks();
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

    // Whether this one is a shader the build guarantees or one a scan
    // measured. It is on screen because the difference is the whole point of
    // the layer this app is: a committed port that stops compiling fails this
    // build, and an external one is a shader that converted, compiled, and has
    // never been compared against the page it came from.
    bool measured = false;
};

template <typename Port>
Entry entryFor(std::string name)
{
    return {std::move(name), [] { return makeOwned<OnePass<Port>>(); }};
}

// The measured half, and the reason it is a half rather than the whole list.
//
// The entries above are committed shaders, and this target compiling every one
// of them is what makes a port that converts and will not build a failed build
// rather than a line nobody reads. An external corpus cannot keep that rule:
// most of it does not convert at all, so a build that insisted would never run.
// What can be said about these is what shadertoy-scan measured - they converted
// and a compiler took them - and that is a weaker claim kept deliberately
// apart from the stronger one.
void addExternalTo([[maybe_unused]] Vector<Entry>& entries)
{
#ifdef SHADERTOY_EXTERNAL_PORTS
#define SHADERTOY_GALLERY_ENTRY(Port, label)                                        \
    entries.add({label, [] { return makeOwned<Unwired<Ports::Port>>(); }, true});

    SHADERTOY_EXTERNAL_PORTS(SHADERTOY_GALLERY_ENTRY)

#undef SHADERTOY_GALLERY_ENTRY
#endif
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
    entries.add(entryFor<Ports::Literals>("Literals"));
    entries.add(entryFor<Ports::Blanks>("Blanks"));

    // And the ones nobody here wrote: real Shadertoys, named after their ids
    // because that is what the site names them, and credited to the author the
    // page credits. What they are for is the same thing the rest of the list is
    // for, except that these were not written to be convertible.
    entries.add(entryFor<Ports::S7d23DR>("7d23DR - mrange"));
    entries.add(entryFor<Ports::SsdVyWt>("sdVyWt - mrange"));
    entries.add(entryFor<Ports::S3l23RK>("3l23RK - iq"));
    entries.add(entryFor<Ports::S4ssSRl>("4ssSRl - iq"));
    entries.add(entryFor<Ports::SftVXRc>("ftVXRc - iq"));
    entries.add(entryFor<Ports::ScsscRl>("csscRl - pizzahollandaise"));
    entries.add(entryFor<Ports::SctdfzN>("ctdfzN - Peace"));
    entries.add(entryFor<Ports::SdldyWN>("dldyWN - lf94"));

    addExternalTo(entries);

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
              << "Arrows to walk them, space to restart." << std::endl;
}

struct MyApp
{
    MyApp()
    {
        view.onKey = [this](std::uint16_t code) { handleKey(code); };

        window.setContentView(view);
        announceCorpus(entries);
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
        const auto& entry = entries[index];

        window.setTitle(std::to_string(index + 1) + "/"
                        + std::to_string(entries.size()) + "  " + entry.name
                        + (entry.measured ? "  [measured]" : "")
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
