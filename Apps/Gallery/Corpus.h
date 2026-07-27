#pragma once

#include <shadertoy/Runtime/Listing.h>
#include <shadertoy/Runtime/ShaderView.h>

#include <functional>
#include <string>

namespace Gallery
{
// One entry, alive: the program the view draws plus everything that has to
// outlive the draw - the buffers behind a multi-pass shader, the textures
// behind a channel.
struct Showing
{
    virtual ~Showing() = default;

    virtual Shadertoy::Program& image() = 0;

    // Multi-pass shaders add theirs; everything else is one pass and adds none.
    virtual void addPassesTo(Shadertoy::ShaderView&) {}
};

struct Entry
{
    std::string name;
    std::function<eacp::OwningPointer<Showing>()> load;

    // The two texts this shader is, for the window that shows them side by
    // side. Every entry has one: a port in the gallery is a port the transpiler
    // wrote, so the GLSL it read and the C++ it wrote both exist by the time
    // there is anything to show.
    const Shadertoy::Listing* listing = nullptr;

    // Whether this one is a shader the build guarantees or one a scan
    // measured. It is on screen because the difference is the whole point of
    // the layer this app is: a committed port that stops compiling fails this
    // build, and an external one is a shader that converted, compiled, and has
    // never been compared against the page it came from.
    bool measured = false;
};

// Ordered as the stages that opened them, which is also roughly simplest
// first: what a shader needs from the EDSL grows down the list.
eacp::Vector<Entry> corpus();
} // namespace Gallery
