#include <shadertoy/Corpus/Dataset.h>

#include <iostream>

// Adds to the corpus the coverage tables are measured over. Not the way to have
// one: Corpus/External is committed, so a clone is already holding every shader
// the tables report on, and nothing in a build runs this.
//
// What it pulls is a published dataset - shaders collected and republished with
// a licence recorded beside each one, which is what decides whether a shader may
// be committed here or only measured.
//
// This is a C++ tool rather than a script for the same reason everything else
// here is: eacp already has an HTTP client and a JSON parser, so the fetcher
// costs one file and no dependency the project did not already have. The
// fetching itself lives in Lib/shadertoy/Corpus, where a test can drive it
// without a socket.

using namespace Shadertoy;

namespace
{
void printUsage()
{
    std::cout
        << "Adds to the Shadertoys the coverage report measures.\n\n"
        << "Corpus/External is committed, so this is how that corpus grows\n"
        << "rather than how it is obtained - a run against an up-to-date\n"
        << "clone writes nothing.\n\n"
        << "Usage:\n"
        << "  shadertoy-fetch --dataset [<name>]\n\n"
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
} // namespace

int main(int argc, char* argv[])
{
    auto options = Corpus::Dataset::parseOptions(argc, argv);

    if (!options.requested || !options.valid || options.help)
    {
        printUsage();
        return options.help ? 0 : 1;
    }

    return Corpus::Dataset::Fetcher {}.run(options).ok() ? 0 : 1;
}
