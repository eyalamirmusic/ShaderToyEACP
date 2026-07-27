#include "Corpus.h"

#include <shadertoy/Runtime/ChannelImages.h>

#include <Basis.h>
#include <BasisListing.h>
#include <Blanks.h>
#include <BlanksListing.h>
#include <Channels.h>
#include <ChannelsListing.h>
#include <Checker.h>
#include <CheckerListing.h>
#include <Compose.h>
#include <ComposeListing.h>
#include <Facets.h>
#include <FacetsListing.h>
#include <Fbm.h>
#include <FbmListing.h>
#include <Gradient.h>
#include <GradientListing.h>
#include <Kaleido.h>
#include <KaleidoListing.h>
#include <Lattice.h>
#include <LatticeListing.h>
#include <Literals.h>
#include <LiteralsListing.h>
#include <Macros.h>
#include <MacrosListing.h>
#include <Mandelbrot.h>
#include <MandelbrotListing.h>
#include <Palette.h>
#include <PaletteListing.h>
#include <Plasma.h>
#include <PlasmaListing.h>
#include <Raymarch.h>
#include <RaymarchListing.h>
#include <Surface.h>
#include <SurfaceListing.h>
#include <TrailBuffer.h>
#include <TrailBufferListing.h>
#include <TrailImage.h>
#include <TrailImageListing.h>
#include <Tunnel.h>
#include <TunnelListing.h>
#include <Voronoi.h>
#include <VoronoiListing.h>

#include <S3l23RK.h>
#include <S3l23RKListing.h>
#include <S4ssSRl.h>
#include <S4ssSRlListing.h>
#include <S7d23DR.h>
#include <S7d23DRListing.h>
#include <ScsscRl.h>
#include <ScsscRlListing.h>
#include <SctdfzN.h>
#include <SctdfzNListing.h>
#include <SdldyWN.h>
#include <SdldyWNListing.h>
#include <SftVXRc.h>
#include <SftVXRcListing.h>
#include <SsdVyWt.h>
#include <SsdVyWtListing.h>

// The measured half, written by shadertoy-scan --register during this build:
// the includes for every shader of the fetched corpus that converted and then
// compiled, its listing beside it, and an X-macro naming them. Included
// unconditionally, because a gallery quietly missing two thirds of its shaders
// is not something a build should be able to arrive at.
#include <ExternalCorpus.h>

// The corpus, as a list of things that can be shown. This is the translation
// unit every port and every listing lands in - close to four megabytes of
// generated text - and the reason it is one of its own: the app around it
// rebuilds in the time it takes to read this sentence, and none of it changes
// when a shader is added to the corpus.

using namespace eacp;
using namespace Shadertoy;

namespace Gallery
{
namespace
{
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

template <typename Port>
Entry entryFor(std::string name, const Listing& listing)
{
    return {std::move(name), [] { return makeOwned<OnePass<Port>>(); }, &listing};
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
void addExternalTo(Vector<Entry>& entries)
{
#define SHADERTOY_GALLERY_ENTRY(Port, label)                                        \
    entries.add({label,                                                             \
                 [] { return makeOwned<Unwired<Ports::Port>>(); },                  \
                 &Listings::Port,                                                   \
                 true});

    SHADERTOY_EXTERNAL_PORTS(SHADERTOY_GALLERY_ENTRY)

#undef SHADERTOY_GALLERY_ENTRY
}
} // namespace

Vector<Entry> corpus()
{
    auto entries = Vector<Entry> {};

    entries.add(entryFor<Ports::Gradient>("Gradient", Listings::Gradient));
    entries.add(entryFor<Ports::Plasma>("Plasma", Listings::Plasma));
    entries.add(entryFor<Ports::Fbm>("Fbm", Listings::Fbm));
    entries.add(entryFor<Ports::Voronoi>("Voronoi", Listings::Voronoi));
    entries.add(entryFor<Ports::Checker>("Checker", Listings::Checker));
    entries.add(entryFor<Ports::Kaleido>("Kaleido", Listings::Kaleido));
    entries.add(
        {"Tunnel", [] { return makeOwned<ShowTunnel>(); }, &Listings::Tunnel});
    entries.add(
        {"Channels", [] { return makeOwned<ShowChannels>(); }, &Listings::Channels});
    entries.add(entryFor<Ports::Raymarch>("Raymarch", Listings::Raymarch));
    entries.add(entryFor<Ports::Mandelbrot>("Mandelbrot", Listings::Mandelbrot));
    entries.add(entryFor<Ports::Palette>("Palette", Listings::Palette));
    entries.add(entryFor<Ports::Lattice>("Lattice", Listings::Lattice));
    entries.add(entryFor<Ports::Surface>("Surface", Listings::Surface));
    entries.add(entryFor<Ports::Facets>("Facets", Listings::Facets));

    // Two shaders and one entry, which is what a multi-pass Shadertoy is. The
    // listing is the image pass, since that is the one on screen; Buffer A's is
    // generated beside it and nothing shows it yet.
    entries.add(
        {"Trail", [] { return makeOwned<ShowTrail>(); }, &Listings::TrailImage});

    entries.add(entryFor<Ports::Macros>("Macros", Listings::Macros));
    entries.add(entryFor<Ports::Compose>("Compose", Listings::Compose));
    entries.add(entryFor<Ports::Basis>("Basis", Listings::Basis));
    entries.add(entryFor<Ports::Literals>("Literals", Listings::Literals));
    entries.add(entryFor<Ports::Blanks>("Blanks", Listings::Blanks));

    // And the ones nobody here wrote: real Shadertoys, named after their ids
    // because that is what the site names them, and credited to the author the
    // page credits. What they are for is the same thing the rest of the list is
    // for, except that these were not written to be convertible.
    entries.add(entryFor<Ports::S7d23DR>("7d23DR - mrange", Listings::S7d23DR));
    entries.add(entryFor<Ports::SsdVyWt>("sdVyWt - mrange", Listings::SsdVyWt));
    entries.add(entryFor<Ports::S3l23RK>("3l23RK - iq", Listings::S3l23RK));
    entries.add(entryFor<Ports::S4ssSRl>("4ssSRl - iq", Listings::S4ssSRl));
    entries.add(entryFor<Ports::SftVXRc>("ftVXRc - iq", Listings::SftVXRc));
    entries.add(
        entryFor<Ports::ScsscRl>("csscRl - pizzahollandaise", Listings::ScsscRl));
    entries.add(entryFor<Ports::SctdfzN>("ctdfzN - Peace", Listings::SctdfzN));
    entries.add(entryFor<Ports::SdldyWN>("dldyWN - lf94", Listings::SdldyWN));

    addExternalTo(entries);

    return entries;
}
} // namespace Gallery
