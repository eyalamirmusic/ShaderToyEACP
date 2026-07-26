#include <shadertoy/Corpus/Dataset.h>
#include <shadertoy/Corpus/Fetch.h>

#include <cstdlib>
#include <iostream>

// Fills a directory the repository does not track with the shaders the coverage
// tables are measured over, from either of the two places they come from.
//
// Shadertoy's default licence is CC BY-NC-SA 3.0 unless an author says
// otherwise, and the non-commercial clause makes redistribution a real question
// rather than a formality. So the wider corpus is a list of ids here and a
// directory of files on the machine that measured them - which is also the only
// shape that scales, since what the coverage table wants is thousands of
// shaders and not the fifteen anyone would write by hand.
//
// --dataset is the other source and the one every number in the README came
// from: a corpus somebody else already collected through that API and published
// with the licences attached, served by an endpoint that wants no key. Without
// it the input to the whole measurement would be the one thing this repository
// cannot reproduce.
//
// This is a C++ tool rather than a script for the same reason everything else
// here is: eacp already has an HTTP client and a JSON parser, so the fetcher
// costs one file and no dependency the project did not already have. The
// fetching itself lives in Lib/shadertoy/Corpus, where a test can drive it
// without a key and without a socket.

using namespace Shadertoy;

namespace
{
void printUsage()
{
    std::cout
        << "Fetches the Shadertoys the coverage report measures.\n\n"
        << "Usage:\n"
        << "  shadertoy-fetch [<id>...]\n"
        << "  shadertoy-fetch --dataset [<name>]\n\n"
        << "From Shadertoy's own API, by id:\n\n"
        << "  --ids <file>     the list to read and to add discoveries to\n"
        << "                   (default: Corpus/ids.txt), used when no id is\n"
        << "                   given on the command line\n"
        << "  --out <dir>      where the shaders go (default: Corpus/External)\n"
        << "  --list <n>       ask the API for n ids and add the new ones to\n"
        << "                   the list before fetching\n"
        << "  --query <term>   discover by searching for a term rather than\n"
        << "                   from the whole index\n"
        << "  --sort <mode>    name, love, popular, newest or hot\n"
        << "  --filter <what>  vr, soundoutput, soundinput, webcam,\n"
        << "                   multipass or musicstream\n"
        << "  --ids-only       discover and stop, spending one request\n"
        << "  --retry-refused  ask again for the ids the API has refused\n"
        << "  --budget <n>     requests to spend this month (default: 1500)\n"
        << "  --delay <ms>     between requests (default: 200)\n"
        << "  --api <url>      the endpoint to ask, for testing without the "
           "site\n\n"
        << "What a run already has it does not fetch again, and what the API\n"
        << "refuses it records and does not ask for again - a key is worth\n"
        << "1500 requests a month, and the ledgers that hold that line are\n"
        << ".quota and .refused beside the shaders.\n\n"
        << "Needs a key from https://www.shadertoy.com/myapps, in\n"
        << "SHADERTOY_API_KEY. Creating one there wants a Shadertoy account\n"
        << "with Silver or Gold status.\n\n"
        << "From a published dataset, whole, and with no key at all:\n\n"
        << "  --dataset [<n>]  the dataset to pull (default:\n"
        << "                   Vipitis/Shadereval-inputs, which is the corpus\n"
        << "                   every count in the README is measured over)\n"
        << "  --out <dir>      where the shaders go (default: Corpus/External)\n"
        << "  --rows <n>       stop after n rows rather than taking the split\n"
        << "  --config <name>  the dataset's config (default: default)\n"
        << "  --split <name>   the split to read (default: test)\n"
        << "  --server <url>   the endpoint to ask, for testing without the "
           "site\n\n"
        << "The id, the author and the licence come back beside each shader,\n"
        << "and the licence is what decides whether one may be committed here\n"
        << "or only measured - .licences beside the shaders is that record.\n\n"
        << "Then measure what came back:\n\n"
        << "  shadertoy-scan Corpus/External --register survivors.cmake\n";
}

int runDataset(const Corpus::Dataset::Options& options)
{
    return Corpus::Dataset::Fetcher {}.run(options).ok() ? 0 : 1;
}

int runApi(Corpus::Options options)
{
    const auto* key = std::getenv("SHADERTOY_API_KEY");

    if (key == nullptr || *key == '\0')
    {
        std::cerr << "SHADERTOY_API_KEY is not set. Create an app at\n"
                  << "https://www.shadertoy.com/myapps - which wants an account\n"
                  << "with Silver or Gold status - and the API refuses an\n"
                  << "unkeyed request.\n\n"
                  << "Or take the corpus the tables here are measured over,\n"
                  << "which wants no key:\n\n"
                  << "  shadertoy-fetch --dataset\n";
        return 1;
    }

    options.key = key;

    return Corpus::Fetcher {}.run(options).ok() ? 0 : 1;
}
} // namespace

int main(int argc, char* argv[])
{
    // Which of the two sources a run is asking for decides which option set the
    // rest of the command line is read as, so the dataset's parse goes first
    // and only its own answer is trusted when it says yes.
    auto dataset = Corpus::Dataset::parseOptions(argc, argv);

    if (dataset.requested || dataset.help)
    {
        if (!dataset.valid || dataset.help)
        {
            printUsage();
            return dataset.help ? 0 : 1;
        }

        return runDataset(dataset);
    }

    auto options = Corpus::parseOptions(argc, argv);

    if (!options.valid || options.help)
    {
        printUsage();
        return options.help ? 0 : 1;
    }

    return runApi(options);
}
