#include <shadertoy/Transpile.h>

#include <algorithm>
#include <cctype>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <utility>

using namespace Shadertoy;

namespace
{
struct Options
{
    Glsl::Vector<std::string> inputs;
    std::string output;
    std::string structName;
    bool report = false;
    bool force = false;
    bool valid = true;
};

void printUsage()
{
    std::cout
        << "Converts Shadertoy GLSL into an eacp shader program.\n\n"
        << "Usage:\n"
        << "  shadertoy-transpile <input.glsl> [-o <out.h>] [--name <Struct>]\n"
        << "  shadertoy-transpile --report <input.glsl>...\n\n"
        << "  -o      where to write the generated header (default: stdout)\n"
        << "  --name  the generated struct's name (default: from the file)\n"
        << "  --force write the header even when the shader reported gaps\n"
        << "  --report  convert every input and print a coverage table only\n";
}

Options parseOptions(int argc, char* argv[])
{
    auto options = Options {};

    for (auto index = 1; index < argc; ++index)
    {
        auto argument = std::string(argv[index]);

        if (argument == "--report")
            options.report = true;
        else if (argument == "--force")
            options.force = true;
        else if (argument == "-o" && index + 1 < argc)
            options.output = argv[++index];
        else if (argument == "--name" && index + 1 < argc)
            options.structName = argv[++index];
        else if (argument.rfind('-', 0) == 0)
            options.valid = false;
        else
            options.inputs.add(argument);
    }

    if (options.inputs.empty())
        options.valid = false;

    return options;
}

std::string readFile(const std::string& path)
{
    auto stream = std::ifstream(path);
    auto buffer = std::ostringstream {};
    buffer << stream.rdbuf();
    return buffer.str();
}

// A file name turned into a struct name: the stem, with its first letter raised
// and anything C++ would reject replaced.
std::string structNameFor(const std::string& path)
{
    auto slash = path.find_last_of("/\\");
    auto stem = slash == std::string::npos ? path : path.substr(slash + 1);

    auto dot = stem.find_last_of('.');

    if (dot != std::string::npos)
        stem = stem.substr(0, dot);

    auto name = std::string {};

    for (auto character: stem)
        name += (std::isalnum((unsigned char) character) != 0) ? character : '_';

    if (name.empty() || std::isdigit((unsigned char) name[0]) != 0)
        name = "Shader" + name;

    name[0] = (char) std::toupper((unsigned char) name[0]);
    return name;
}

// One row of the coverage table: how many shaders a single gap blocks, which is
// the number the roadmap is sorted by, and how often it came up in total.
struct Coverage
{
    int shaders = 0;
    int occurrences = 0;
};

void printReport(const std::map<std::string, Coverage>& rows,
                 int converted,
                 int total)
{
    auto ordered = Glsl::Vector<std::pair<std::string, Coverage>> {};

    for (const auto& row: rows)
        ordered.add(row);

    std::sort(ordered.begin(),
              ordered.end(),
              [](const auto& a, const auto& b)
              {
                  if (a.second.shaders != b.second.shaders)
                      return a.second.shaders > b.second.shaders;

                  return a.second.occurrences > b.second.occurrences;
              });

    std::cout << "\n| Blocker | Shaders | Occurrences |\n";
    std::cout << "| --- | ---: | ---: |\n";

    for (const auto& row: ordered)
        std::cout << "| " << row.first << " | " << row.second.shaders << " | "
                  << row.second.occurrences << " |\n";

    std::cout << "\n"
              << converted << " of " << total << " shaders converted "
              << "with no gaps.\n";
}

int runReport(const Options& options)
{
    auto rows = std::map<std::string, Coverage> {};
    auto converted = 0;

    for (const auto& input: options.inputs)
    {
        auto result = transpile(readFile(input), structNameFor(input));

        if (result.ok())
            ++converted;

        auto seen = std::map<std::string, bool> {};

        for (const auto& diagnostic: result.diagnostics)
        {
            auto key = std::string(name(diagnostic.kind)) + ": " + diagnostic.detail;
            auto& row = rows[key];

            ++row.occurrences;

            if (!seen[key])
            {
                seen[key] = true;
                ++row.shaders;
            }
        }
    }

    printReport(rows, converted, options.inputs.size());
    return 0;
}

int runConvert(const Options& options)
{
    const auto& input = options.inputs[0];

    auto structName =
        options.structName.empty() ? structNameFor(input) : options.structName;

    auto result = transpile(readFile(input), structName);

    for (const auto& diagnostic: result.diagnostics)
        std::cerr << input << ":" << describe(diagnostic) << "\n";

    if (!result.ok() && !options.force && !options.output.empty())
    {
        std::cerr << "\n"
                  << input << ": " << result.diagnostics.size()
                  << " gap(s); not written. Pass --force to write anyway.\n";
        return 1;
    }

    if (options.output.empty())
    {
        std::cout << result.code;
        return result.ok() ? 0 : 1;
    }

    auto out = std::ofstream(options.output, std::ios::binary);
    out << result.code;

    return 0;
}
} // namespace

int main(int argc, char* argv[])
{
    auto options = parseOptions(argc, argv);

    if (!options.valid)
    {
        printUsage();
        return 2;
    }

    return options.report ? runReport(options) : runConvert(options);
}
