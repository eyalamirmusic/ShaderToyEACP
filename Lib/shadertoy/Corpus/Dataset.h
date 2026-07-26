#pragma once

#include "Transport.h"

#include <eacp/Core/Utils/Containers.h>

#include <filesystem>
#include <functional>
#include <string>

// The other way to fill Corpus/External, and the one every number in the README
// actually came from.
//
// Fetch.h talks to Shadertoy's own API, which wants a key that wants an account
// with Silver status - so the corpus the coverage tables are measured over was
// pulled by hand from somewhere else: Vipitis/Shadereval-inputs, the input set
// of the ShaderEval benchmark, whose author had already collected it through
// that API and published it with the id, the author and the licence beside each
// shader. It is served by an endpoint that wants no key at all.
//
// That makes it the one thing the measurement could not reproduce, which is a
// worse position than not having measured: a table nobody else can regenerate
// is a table nobody else can check. This is that gap closed, and it costs one
// more Transport behind bookkeeping of the same shape - page the rows, keep the
// first complete copy of each id, and never rewrite what is already there.
namespace Shadertoy::Corpus::Dataset
{
using eacp::Vector;

struct Options
{
    std::filesystem::path out = "Corpus/External";

    // The dataset, as its server names it. The default is the one the tables
    // above are measured over; a different one is somebody else's measurement.
    std::string name = "Vipitis/Shadereval-inputs";
    std::string config = "default";
    std::string split = "test";

    // Overridable so that the one thing here that cannot be checked offline can
    // be: point it at something that answers in the endpoint's shape, and
    // everything below the request is exercised.
    std::string server = "https://datasets-server.huggingface.co";

    // What the endpoint will serve at once. Asking for more comes back as this
    // many anyway, so it is the page size rather than a preference.
    int pageSize = 100;

    // Rows to read before stopping, for a run that wants a taste of a corpus
    // rather than the whole of it. Zero is the whole split.
    int limit = 0;

    bool valid = true;
    bool help = false;

    // Whether the command line asked for a dataset at all, which is what
    // decides between this and the API fetcher beside it.
    bool requested = false;
};

// A dataset row is one function of one shader, so a shader appears once per
// function it was cut into and the count that matters is the distinct one.
struct Summary
{
    bool ok() const { return failed == 0 && incomplete == 0 && shaders > 0; }

    int requests = 0;
    int rows = 0;
    int shaders = 0;

    int written = 0;
    int alreadyHad = 0;

    // Shaders the endpoint only ever sent a truncated copy of. It shortens a
    // cell rather than refusing it, and a shader cut off mid-function converts
    // into a gap that is the transport's rather than the shader's - which is
    // the one way this could quietly corrupt a measurement.
    int incomplete = 0;

    int failed = 0;
};

struct Fetcher
{
    Summary run(const Options& options) const;

    Transport transport = httpGet;
    std::function<void(const std::string&)> note = printNote;
    std::function<void(const std::string&)> warn = printWarning;
};

Options parseOptions(const Vector<std::string>& arguments);
Options parseOptions(int argc, char* argv[]);
} // namespace Shadertoy::Corpus::Dataset
