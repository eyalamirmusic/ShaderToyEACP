#include <shadertoy/Corpus/Fetch.h>

#include <cstdlib>
#include <iostream>

// Fetches Shadertoys by id into a directory the repository does not track.
//
// Shadertoy's default licence is CC BY-NC-SA 3.0 unless an author says
// otherwise, and the non-commercial clause makes redistribution a real question
// rather than a formality. So the wider corpus is a list of ids here and a
// directory of files on the machine that measured them - which is also the only
// shape that scales, since what the coverage table wants is thousands of
// shaders and not the fifteen anyone would write by hand.
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
        << "Fetches Shadertoys by id, for the coverage report to measure.\n\n"
        << "Usage:\n"
        << "  shadertoy-fetch [<id>...]\n\n"
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
        << "with Silver or Gold status. Then measure what came back:\n\n"
        << "  shadertoy-transpile --report Corpus/External/*.glsl\n";
}
} // namespace

int main(int argc, char* argv[])
{
    auto options = Corpus::parseOptions(argc, argv);

    if (!options.valid || options.help)
    {
        printUsage();
        return options.help ? 0 : 1;
    }

    const auto* key = std::getenv("SHADERTOY_API_KEY");

    if (key == nullptr || *key == '\0')
    {
        std::cerr << "SHADERTOY_API_KEY is not set. Create an app at\n"
                  << "https://www.shadertoy.com/myapps - which wants an account\n"
                  << "with Silver or Gold status - and the API refuses an\n"
                  << "unkeyed request.\n";
        return 1;
    }

    options.key = key;

    return Corpus::Fetcher {}.run(options).ok() ? 0 : 1;
}
