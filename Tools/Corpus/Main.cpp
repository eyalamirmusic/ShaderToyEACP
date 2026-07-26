#include <eacp/Network/HTTP/Http.h>

#include <Miro/Json.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
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
// costs one file and no dependency the project did not already have.

using namespace eacp;

namespace
{
struct Options
{
    Vector<std::string> ids;
    std::filesystem::path idsFile = "Corpus/ids.txt";
    std::filesystem::path out = "Corpus/External";

    // Overridable so that the one thing here that cannot be checked offline can
    // be: point it at something that answers in the API's shape, and everything
    // below the request is exercised.
    std::string api = "https://www.shadertoy.com/api/v1/shaders/";

    bool valid = true;
};

void printUsage()
{
    std::cout << "Fetches Shadertoys by id, for the coverage report to measure.\n\n"
              << "Usage:\n"
              << "  shadertoy-fetch [<id>...]\n\n"
              << "  --ids   the file to read ids from (default: Corpus/ids.txt),\n"
              << "          used when no id is given on the command line\n"
              << "  --out   where to write them (default: Corpus/External)\n"
              << "  --api   the endpoint to ask, for testing without the site\n\n"
              << "Needs a key from https://www.shadertoy.com/howto#q2, in\n"
              << "SHADERTOY_API_KEY. Then measure what came back:\n\n"
              << "  shadertoy-transpile --report Corpus/External/*.glsl\n";
}

Options parseOptions(int argc, char* argv[])
{
    auto options = Options {};

    for (auto index = 1; index < argc; ++index)
    {
        auto argument = std::string(argv[index]);

        if (argument == "--ids" && index + 1 < argc)
            options.idsFile = argv[++index];
        else if (argument == "--out" && index + 1 < argc)
            options.out = argv[++index];
        else if (argument == "--api" && index + 1 < argc)
            options.api = argv[++index];
        else if (!argument.empty() && argument[0] == '-')
            options.valid = false;
        else
            options.ids.add(argument);
    }

    return options;
}

// One id per line, with everything after a # a comment - so the file can say
// which shader each id is without the fetcher having to care.
Vector<std::string> readIds(const std::filesystem::path& path)
{
    auto ids = Vector<std::string> {};
    auto file = std::ifstream(path);

    if (!file)
    {
        std::cerr << "cannot read " << path << "\n";
        return ids;
    }

    for (std::string line; std::getline(file, line);)
    {
        line = line.substr(0, line.find('#'));

        auto first = line.find_first_not_of(" \t\r");

        if (first == std::string::npos)
            continue;

        ids.add(line.substr(first, line.find_last_not_of(" \t\r") + 1 - first));
    }

    return ids;
}

const Miro::Json::Value* field(const Miro::Json::Value& value, const char* key)
{
    if (!value.isObject())
        return nullptr;

    return Miro::Json::find(value.asObject(), key);
}

std::string stringField(const Miro::Json::Value& value, const char* key)
{
    const auto* found = field(value, key);

    return found != nullptr && found->isString() ? found->asString()
                                                 : std::string {};
}

// What this writes a pass as. The image pass keeps the shader's own id, so the
// ordinary single-pass case is one file with an obvious name; every other pass
// is suffixed with the name the page gives it, since a Shadertoy with buffers is
// several files here exactly as Corpus/TrailBuffer.glsl and TrailImage.glsl are.
std::string suffixFor(const Miro::Json::Value& renderPass)
{
    auto kind = stringField(renderPass, "type");

    if (kind.empty() || kind == "image")
        return {};

    auto name = stringField(renderPass, "name");

    if (name.empty())
        name = kind;

    // "Buf A" -> "-BufA", which is a name a C++ struct can be called after.
    auto suffix = std::string("-");

    for (auto character: name)
        if (character != ' ')
            suffix += character;

    return suffix;
}

// What each iChannel is bound to, which a port has to know and the source does
// not say. A texture is a file on Shadertoy's server and a buffer is another
// pass here; either way it is the app's job to supply it.
std::string channelNote(const Miro::Json::Value& renderPass)
{
    const auto* inputs = field(renderPass, "inputs");

    if (inputs == nullptr || !inputs->isArray() || inputs->asArray().empty())
        return {};

    auto text = std::string("//\n// Channels:\n");

    for (const auto& channel: inputs->asArray())
    {
        const auto* index = field(channel, "channel");
        auto source = stringField(channel, "src");

        text += "//   iChannel";
        text += index != nullptr && index->isNumber()
                    ? std::to_string((int) index->asNumber())
                    : "?";
        text += ": " + stringField(channel, "ctype");
        text += source.empty() ? "" : " " + source;
        text += "\n";
    }

    return text;
}

std::string header(const Miro::Json::Value& info,
                   const Miro::Json::Value& renderPass)
{
    auto name = stringField(info, "name");
    auto author = stringField(info, "username");

    auto text = "// " + name;
    text += author.empty() ? "\n" : " - " + author + "\n";
    text += "// https://www.shadertoy.com/view/" + stringField(info, "id") + "\n";
    text += "//\n";
    text += "// Fetched rather than vendored: Shadertoy's default licence is\n";
    text += "// CC BY-NC-SA 3.0 unless the author says otherwise. Not for\n";
    text += "// redistribution - this file is measured here and stays here.\n";
    text += channelNote(renderPass);

    return text + "\n";
}

// A `common` pass is not a pass at all: it is a prelude the page pastes in
// front of every other one, so it is written into each of them rather than into
// a file of its own.
std::string preludeOf(const Miro::Json::Array& passes)
{
    auto prelude = std::string {};

    for (const auto& renderPass: passes)
        if (stringField(renderPass, "type") == "common")
            prelude += stringField(renderPass, "code");

    return prelude;
}

bool writePasses(const Miro::Json::Value& shader, const std::filesystem::path& out)
{
    const auto* info = field(shader, "info");
    const auto* passes = field(shader, "renderpass");

    if (info == nullptr || passes == nullptr || !passes->isArray())
    {
        std::cerr << "unexpected response shape\n";
        return false;
    }

    auto id = stringField(*info, "id");
    auto prelude = preludeOf(passes->asArray());
    auto written = false;

    for (const auto& renderPass: passes->asArray())
    {
        if (stringField(renderPass, "type") == "common")
            continue;

        auto path = out / (id + suffixFor(renderPass) + ".glsl");
        auto file = std::ofstream(path);

        if (!file)
        {
            std::cerr << "cannot write " << path << "\n";
            continue;
        }

        file << header(*info, renderPass) << prelude
             << stringField(renderPass, "code");

        std::cout << path.string() << "\n";
        written = true;
    }

    return written;
}

bool fetch(const std::string& id, const std::string& key, const Options& options)
{
    auto request = HTTP::Request {options.api + id + "?key=" + key};
    request.headers["User-Agent"] = "ShaderToyEACP corpus fetcher";

    auto response = request.perform();

    if (!response.error.empty() || response.statusCode != 200)
    {
        std::cerr << id << ": "
                  << (response.error.empty()
                          ? "HTTP " + std::to_string(response.statusCode)
                          : response.error)
                  << "\n";
        return false;
    }

    // The API answers a bad key, a private shader and a missing one the same
    // way: 200, with an Error in the body.
    auto shader = Miro::Json::getParsedValue(response.content);

    if (shader.isNull())
    {
        std::cerr << id << ": the response was not JSON\n";
        return false;
    }

    if (const auto* error = field(shader, "Error"))
    {
        std::cerr << id << ": " << Miro::Json::print(*error) << "\n";
        return false;
    }

    return writePasses(shader, options.out);
}
} // namespace

int main(int argc, char* argv[])
{
    auto options = parseOptions(argc, argv);

    if (!options.valid)
    {
        printUsage();
        return 1;
    }

    const auto* key = std::getenv("SHADERTOY_API_KEY");

    if (key == nullptr || *key == '\0')
    {
        std::cerr << "SHADERTOY_API_KEY is not set. Register one at\n"
                  << "https://www.shadertoy.com/howto#q2 - the API refuses an\n"
                  << "unkeyed request, and so does the site's bot protection.\n";
        return 1;
    }

    auto ids = options.ids.empty() ? readIds(options.idsFile) : options.ids;

    if (ids.empty())
    {
        std::cerr << "no ids to fetch\n";
        return 1;
    }

    std::filesystem::create_directories(options.out);

    auto fetched = 0;

    for (const auto& id: ids)
        if (fetch(id, key, options))
            ++fetched;

    std::cerr << "\n"
              << fetched << " of " << ids.size() << " fetched into "
              << options.out.string() << "\n";

    return fetched == ids.size() ? 0 : 1;
}
