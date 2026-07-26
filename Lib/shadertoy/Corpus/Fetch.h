#pragma once

#include "Transport.h"

#include <eacp/Core/Utils/Containers.h>

#include <filesystem>
#include <functional>
#include <string>

// Fetching Shadertoys by id, under the two limits the API actually imposes:
// only shaders whose author marked them Public+API come back at all, and a key
// is worth 1500 requests a month. Both are why this is bookkeeping rather than
// a download loop - a run that asks again for what it already has, or for a
// shader the API has already refused, spends a budget that does not refill
// until the month does. So the corpus accretes: the id list is the queue, the
// directory is the record, and each month drains more of the one into the
// other.
//
// Dataset.h is the other way to fill the same directory, and wants no key.
namespace Shadertoy::Corpus
{
using eacp::Vector;

struct Options
{
    Vector<std::string> ids;
    std::filesystem::path idsFile = "Corpus/ids.txt";
    std::filesystem::path out = "Corpus/External";
    std::string key;

    // Overridable so that the one thing here that cannot be checked offline
    // can be: point it at something that answers in the API's shape, and
    // everything below the request is exercised.
    std::string api = "https://www.shadertoy.com/api/v1/shaders";

    // How many ids to ask the index for. One request buys the whole block,
    // which is why discovery is cheap and fetching is not.
    int discover = 0;
    std::string query;

    // name, love, popular, newest or hot; and vr, soundoutput, soundinput,
    // webcam, multipass or musicstream. Both are the API's own vocabulary,
    // passed through rather than checked here, and the filter is the one way
    // of asking for a kind of shader rather than a popular one.
    std::string sort;
    std::string filter;

    bool idsOnly = false;
    bool retryRefused = false;

    // What Shadertoy grants a key each month, and what this refuses to spend
    // more than.
    int budget = 1500;
    int delayMs = 200;

    bool valid = true;
    bool help = false;
};

Options parseOptions(const Vector<std::string>& arguments);
Options parseOptions(int argc, char* argv[]);

struct Summary
{
    // A run is fine when nothing broke and nothing was left unasked. Shaders
    // the API refuses are neither: at corpus scale most of what a list names
    // will not be Public+API, and that is the measurement rather than a fault.
    bool ok() const { return failed == 0 && leftToDo == 0; }

    int discovered = 0;
    int fetched = 0;
    int alreadyHad = 0;
    int refused = 0;
    int skippedRefused = 0;
    int failed = 0;

    int spent = 0;
    int remaining = 0;
    int leftToDo = 0;
};

struct Fetcher
{
    Summary run(const Options& options) const;

    Transport transport = httpGet;
    std::function<std::string()> date = today;
    std::function<void(const std::string&)> note = printNote;
    std::function<void(const std::string&)> warn = printWarning;
};
} // namespace Shadertoy::Corpus
