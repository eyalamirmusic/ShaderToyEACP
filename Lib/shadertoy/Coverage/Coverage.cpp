#include "Coverage.h"

#include <shadertoy/Emit/ListingEmitter.h>

#include <algorithm>
#include <atomic>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <thread>

namespace Shadertoy::Coverage
{
namespace
{
std::string readFile(const std::filesystem::path& path)
{
    auto stream = std::ifstream(path);
    auto buffer = std::ostringstream {};
    buffer << stream.rdbuf();
    return buffer.str();
}

// A file name turned into a struct name, the way the transpiler's own command
// line does it: the stem, with its first letter raised and anything C++ would
// reject replaced. Shadertoy ids start with a digit often enough to matter.
std::string structNameFor(const std::filesystem::path& path)
{
    auto name = std::string {};

    for (auto character: path.stem().string())
        name += (std::isalnum((unsigned char) character) != 0) ? character : '_';

    if (name.empty() || std::isdigit((unsigned char) name[0]) != 0)
        name = "Shader" + name;

    name[0] = (char) std::toupper((unsigned char) name[0]);
    return name;
}

bool isShader(const std::filesystem::path& path)
{
    return path.extension() == ".glsl";
}

// What to call a shader in front of a person. Both fetchers write the id and
// the author into the first comment line, which is the one thing about a
// converted shader that a struct name does not carry - and the layer of
// validation this feeds is somebody walking through 95 frames wondering which
// page to compare each one against.
std::string titleOf(const std::filesystem::path& source, const std::string& text)
{
    auto first = text.find_first_not_of(" \t\r\n");

    if (first == std::string::npos || text.compare(first, 2, "//") != 0)
        return source.stem().string();

    auto line = text.substr(first + 2, text.find('\n', first) - first - 2);
    auto from = line.find_first_not_of(" \t");

    if (from == std::string::npos)
        return source.stem().string();

    line = line.substr(from, line.find_last_not_of(" \t\r") + 1 - from);

    // A comment is somebody's prose and this ends up inside a C++ string
    // literal, so the two characters that would end it early come out.
    auto clean = std::string {};

    for (auto character: line)
        if (character != '"' && character != '\\')
            clean += character;

    return clean.empty() ? source.stem().string() : clean;
}

// Everything to measure, from what the command line named: a directory stands
// for the shaders in it, which is what makes this a scan of a corpus rather
// than of a list.
Vector<std::filesystem::path> shadersIn(const Vector<std::filesystem::path>& inputs)
{
    auto found = Vector<std::filesystem::path> {};

    for (const auto& input: inputs)
    {
        if (!std::filesystem::is_directory(input))
        {
            if (isShader(input))
                found.add(input);

            continue;
        }

        for (const auto& entry: std::filesystem::directory_iterator(input))
            if (isShader(entry.path()))
                found.add(entry.path());
    }

    std::sort(found.begin(), found.end());
    return found;
}

std::string collapseSpaces(const std::string& text)
{
    auto shaped = std::string {};

    for (auto character: text)
    {
        auto space = std::isspace((unsigned char) character) != 0;

        if (space && (shaped.empty() || shaped.back() == ' '))
            continue;

        shaped += space ? ' ' : character;
    }

    while (!shaped.empty() && shaped.back() == ' ')
        shaped.pop_back();

    return shaped;
}

// The rows the tables are ranked by, out of one blocker per shader per key.
Vector<Row> rank(const std::map<std::string, Row>& rows)
{
    auto ordered = Vector<Row> {};

    for (const auto& row: rows)
        ordered.add(row.second);

    std::sort(ordered.begin(),
              ordered.end(),
              [](const Row& a, const Row& b)
              {
                  if (a.shaders != b.shaders)
                      return a.shaders > b.shaders;

                  return a.occurrences > b.occurrences;
              });

    return ordered;
}

// One struct name per source, and never the same one twice. A name is what the
// generated header is called, so two shaders sharing one would have the second
// overwrite the first and then be measured against it - a compile result
// attributed to the wrong shader, which is the one failure a coverage table
// cannot survive. Shadertoy ids are case-sensitive and these names are not:
// `clGyWm` and `ClGyWm` are two shaders and one struct.
Vector<std::string> namesFor(const Vector<std::filesystem::path>& sources)
{
    auto names = Vector<std::string> {};
    auto taken = std::map<std::string, int> {};

    for (const auto& source: sources)
    {
        auto name = structNameFor(source);
        auto seen = ++taken[name];

        names.add(seen == 1 ? name : name + "_" + std::to_string(seen));
    }

    return names;
}

std::filesystem::path writeHeader(const std::filesystem::path& out,
                                  const std::string& structName,
                                  const std::string& code)
{
    auto header = out / (structName + ".h");
    auto stream = std::ofstream(header, std::ios::binary);

    stream << code;

    return header;
}

// Beside the header, the shader and the header as data, for the gallery to
// show. Written for everything that converted rather than only for what went on
// to compile, because whether it compiles is not known yet here - and a listing
// nobody includes costs a file in a scan directory.
void writeListing(const std::filesystem::path& out,
                  const std::string& structName,
                  const std::string& glsl,
                  const std::string& code)
{
    auto stream = std::ofstream(out / (structName + "Listing.h"), std::ios::binary);

    stream << Emit::emitListing(structName, glsl, code);
}

Outcome measure(const std::filesystem::path& source,
                const std::string& structName,
                const std::filesystem::path& out,
                const Compiler& compiler)
{
    auto outcome = Outcome {};

    outcome.source = source;
    outcome.name = structName;

    auto text = readFile(source);
    outcome.title = titleOf(source, text);

    auto result = transpile(text, outcome.name);
    outcome.converted = result.ok();

    for (const auto& diagnostic: result.diagnostics)
        outcome.gaps.add(std::string(name(diagnostic.kind)) + ": "
                         + diagnostic.detail);

    if (!outcome.converted)
        return outcome;

    auto header = writeHeader(out, outcome.name, result.code);
    writeListing(out, outcome.name, text, result.code);

    auto diagnostics = compiler(header);
    outcome.compiled = diagnostics.empty();

    if (outcome.compiled)
        return outcome;

    outcome.errors = errorsIn(diagnostics);

    auto lines = std::istringstream(diagnostics);
    auto line = std::string {};

    while (std::getline(lines, line))
        if (line.find(": error: ") != std::string::npos)
        {
            outcome.firstError = line;
            break;
        }

    // A compiler that failed and said nothing this recognises is still a
    // failure, and one worth seeing rather than counting as a pass.
    if (outcome.errors.empty())
    {
        outcome.errors.add("the compiler failed without naming an error");
        outcome.firstError = collapseSpaces(diagnostics).substr(0, 200);
    }

    return outcome;
}
} // namespace

std::string errorShape(const std::string& message)
{
    auto shaped = std::string {};
    auto quoted = false;
    auto depth = 0;

    // A spelling suggestion is about this shader's names and not about what
    // went wrong, and clang offers one on some occurrences of a message and not
    // on others - so leaving it in splits one blocker across two rows.
    auto trimmed = message.substr(0, message.find("; did you mean"));

    for (auto character: trimmed)
    {
        if (character == '\'')
        {
            quoted = !quoted;
            continue;
        }

        if (quoted)
            continue;

        if (character == '(' || character == '[')
        {
            ++depth;
            continue;
        }

        if (character == ')' || character == ']')
        {
            depth = std::max(depth - 1, 0);
            continue;
        }

        if (depth == 0)
            shaped += character;
    }

    return collapseSpaces(shaped);
}

Vector<std::string> errorsIn(const std::string& diagnostics)
{
    auto found = Vector<std::string> {};
    auto seen = std::map<std::string, bool> {};

    auto lines = std::istringstream(diagnostics);
    auto line = std::string {};

    while (std::getline(lines, line))
    {
        auto at = line.find(": error: ");

        if (at == std::string::npos)
            continue;

        auto shape = errorShape(line.substr(at + 9));

        if (shape.empty() || seen[shape])
            continue;

        seen[shape] = true;
        found.add(shape);
    }

    return found;
}

Blame blame(const std::string& shape)
{
    struct Known
    {
        const char* shape;
        const char* label;
        const char* whose;
    };

    // A compiler message says what the C++ was, and this says what the shader
    // was - which is what a table anyone can act on has to be ranked by. What
    // is not here is reported as itself: a row nobody has named yet is a
    // finding, and inventing a name for it in advance is how a measurement
    // starts agreeing with what it expected.
    static constexpr Known known[] = {
        {"no matching function for call to",
         "Unresolved intrinsic overload - a literal in an argument position "
         "eacp has no form for",
         "eacp"},
        {"use of undeclared identifier",
         "Identifier emitted before it was declared",
         "transpiler"},
        {"invalid operands to binary expression",
         "Invalid operands - a type inferred wrongly and carried into an "
         "operator",
         "transpiler"},
        {"no viable overloaded",
         "`no viable overloaded '='` - the same wrong type, one statement "
         "later",
         "transpiler"},
        {"variable declared with deduced type cannot appear in its own "
         "initializer",
         "`auto x = ... x ...` - a reassignment emitted as a declaration",
         "transpiler"},
        {"no member named in",
         "A component read off a value that has none",
         "transpiler"},
    };

    for (const auto& row: known)
        if (shape == row.shape)
            return {row.label, row.whose};

    return {shape, "?"};
}

int Report::converted() const
{
    auto count = 0;

    for (const auto& outcome: outcomes)
        if (outcome.converted)
            ++count;

    return count;
}

int Report::compiled() const
{
    auto count = 0;

    for (const auto& outcome: outcomes)
        if (outcome.passed())
            ++count;

    return count;
}

Vector<Row> Report::conversionRows() const
{
    auto rows = std::map<std::string, Row> {};

    for (const auto& outcome: outcomes)
    {
        auto seen = std::map<std::string, bool> {};

        for (const auto& gap: outcome.gaps)
        {
            auto& row = rows[gap];

            row.blocker = gap;
            ++row.occurrences;

            if (!seen[gap])
            {
                seen[gap] = true;
                ++row.shaders;
            }
        }
    }

    return rank(rows);
}

Vector<Row> Report::compileRows() const
{
    auto rows = std::map<std::string, Row> {};

    for (const auto& outcome: outcomes)
    {
        if (outcome.compiled)
            continue;

        // Ranked by what a shader hit first, since that is what blocks it, and
        // counted by everywhere it appears - a blocker that never comes first
        // is still one somebody has to close, and would vanish from the table
        // otherwise.
        for (auto index = 0; index < outcome.errors.size(); ++index)
        {
            auto& row = rows[outcome.errors[index]];

            row.blocker = outcome.errors[index];
            ++row.occurrences;

            if (index == 0)
                ++row.shaders;
        }
    }

    return rank(rows);
}

int Report::unblockedBy(const std::string& shape) const
{
    auto count = 0;

    for (const auto& outcome: outcomes)
        if (outcome.converted && !outcome.compiled && outcome.errors.size() == 1
            && outcome.errors[0] == shape)
            ++count;

    return count;
}

namespace
{
// The shader the compiler is checked with: straight-line arithmetic over the
// standard uniforms, which is the floor of the corpus and of the EDSL both. A
// compiler that will not take this one is not measuring shaders.
constexpr auto canary = R"(
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(uv, 0.0, 1.0);
}
)";
} // namespace

std::string checkCompiler(const Compiler& compiler, const std::filesystem::path& out)
{
    std::filesystem::create_directories(out);

    auto result = transpile(canary, "ProbeCheck");

    if (!result.ok())
        return "the transpiler cannot convert the shader this checks with, "
               "which is a gap in the transpiler and not in the toolchain";

    return compiler(writeHeader(out, "ProbeCheck", result.code));
}

Report scan(const Options& options, const Compiler& compiler)
{
    auto sources = shadersIn(options.inputs);
    auto names = namesFor(sources);
    auto report = Report {};

    report.outcomes.resize(sources.size());

    std::filesystem::create_directories(options.out);

    auto jobs =
        options.jobs > 0 ? options.jobs : (int) std::thread::hardware_concurrency();

    auto next = std::atomic<int> {0};

    auto work = [&]
    {
        for (auto index = next++; index < sources.size(); index = next++)
            report.outcomes[index] =
                measure(sources[index], names[index], options.out, compiler);
    };

    auto workers = Vector<std::thread> {};

    for (auto worker = 1; worker < jobs; ++worker)
        workers.add(std::thread(work));

    work();

    for (auto& worker: workers)
        worker.join();

    return report;
}

namespace
{
// The head of a long tail. Both tables run down to a great many rows blocking
// one shader each, and what a roadmap is sorted by is the top of them - so the
// rest is counted rather than listed, which is the honest way to shorten a
// table: a cut that says what it cut.
constexpr auto rowsShown = 10;

void printTail(const Vector<Row>& rows)
{
    auto shaders = 0;

    for (auto index = rowsShown; index < rows.size(); ++index)
        shaders += rows[index].shaders;

    if (rows.size() > rowsShown)
        std::cout << "\nAnd " << (rows.size() - rowsShown) << " more rows, blocking "
                  << shaders << " shaders between them.\n";
}
} // namespace

void printReport(const Report& report, bool verbose)
{
    auto total = report.outcomes.size();
    auto converted = report.converted();
    auto compiled = report.compiled();

    auto gaps = report.conversionRows();

    std::cout << "\n### What does not convert\n\n"
              << "| Blocker | Shaders | Occurrences |\n| --- | ---: | ---: |\n";

    for (auto index = 0; index < gaps.size() && index < rowsShown; ++index)
        std::cout << "| " << gaps[index].blocker << " | " << gaps[index].shaders
                  << " | " << gaps[index].occurrences << " |\n";

    printTail(gaps);

    auto failures = report.compileRows();

    std::cout << "\n### What converts and then does not compile\n\n"
              << "| Blocker | Shaders | Unblocks | Whose is it |\n"
              << "| --- | ---: | ---: | --- |\n";

    // Unblocks is what a fix is worth and Shaders is not: a shader that reports
    // two blockers is blocked by whichever it hit first and compiles the day
    // both are closed, so the two columns rank the same list differently on
    // purpose.
    for (const auto& row: failures)
        std::cout << "| " << blame(row.blocker).label << " | " << row.shaders
                  << " | " << report.unblockedBy(row.blocker) << " | "
                  << blame(row.blocker).whose << " |\n";

    std::cout << "\n"
              << converted << " of " << total << " shaders converted with no gaps.\n"
              << compiled << " of those " << converted << " compiled; "
              << (converted - compiled) << " did not.\n";

    if (!verbose)
        return;

    std::cout << "\nWhat each shader that converted and did not compile hit "
                 "first:\n\n";

    for (const auto& outcome: report.outcomes)
        if (outcome.converted && !outcome.compiled)
            std::cout << outcome.name << ": " << outcome.firstError << "\n";
}

std::filesystem::path tablePathFor(const Options& options)
{
    return std::filesystem::absolute(options.out) / "ExternalCorpus.h";
}

namespace
{
// The survivors, in the order a person would walk them rather than the order
// the threads finished in.
Vector<const Outcome*> survivorsOf(const Report& report)
{
    auto passed = Vector<const Outcome*> {};

    for (const auto& outcome: report.outcomes)
        if (outcome.passed())
            passed.add(&outcome);

    std::sort(passed.begin(),
              passed.end(),
              [](const Outcome* a, const Outcome* b) { return a->name < b->name; });

    return passed;
}

void writeCMakeList(std::ostream& file,
                    const Report& report,
                    const Options& options,
                    const Vector<const Outcome*>& passed)
{
    auto directory = std::filesystem::absolute(options.out);

    file << "# Written by shadertoy-scan --register. Every shader named here\n"
         << "# converted and then compiled, and that is the whole of what this\n"
         << "# file claims: nobody has looked at any of these frames.\n"
         << "#\n"
         << "# " << passed.size() << " of " << report.outcomes.size()
         << " shaders converted and compiled.\n"
         << "#\n"
         << "# include() this and the variables below are what a target needs.\n"
         << "\n"
         << "set(SHADERTOY_SURVIVOR_COUNT " << passed.size() << ")\n"
         << "set(SHADERTOY_SURVIVOR_INCLUDE_DIR \"" << directory.generic_string()
         << "\")\n"
         << "set(SHADERTOY_SURVIVOR_TABLE \""
         << tablePathFor(options).generic_string() << "\")\n\n"
         << "set(SHADERTOY_SURVIVORS\n";

    for (const auto* outcome: passed)
        file << "        " << outcome->name << "\n";

    file << ")\n\nset(SHADERTOY_SURVIVOR_HEADERS\n";

    for (const auto* outcome: passed)
        file << "        \"" << (directory / (outcome->name + ".h")).generic_string()
             << "\"\n";

    file << ")\n";
}

// The include list and the entry table, as an X-macro rather than as anything
// that knows what an entry is. What a consumer does with a port is its own
// business - the gallery makes one and shows it - and a generated file that
// named a type would be a generated file that had to be kept in step with one.
void writeTable(std::ostream& file,
                const Report& report,
                const Vector<const Outcome*>& passed)
{
    file << "#pragma once\n\n"
         << "// Written by shadertoy-scan --register: every shader of a corpus\n"
         << "// that converted and then compiled, " << passed.size() << " of "
         << report.outcomes.size() << " of them.\n"
         << "//\n"
         << "// These are measured rather than guaranteed. The ports a target\n"
         << "// holds by hand fail its build if one of them stops compiling,\n"
         << "// which is why they are worth holding by hand; a corpus most of\n"
         << "// which does not convert cannot keep that rule, so this is the\n"
         << "// half of a gallery that is a measurement and not a promise.\n\n";

    // The port and its listing, which is the port's two texts: a consumer that
    // shows a shader and a consumer that shows what it was written as are the
    // same consumer, and pulling them apart would mean two X-macros over one
    // list.
    for (const auto* outcome: passed)
        file << "#include <" << outcome->name << ".h>\n"
             << "#include <" << outcome->name << "Listing.h>\n";

    file << "\n#define SHADERTOY_EXTERNAL_PORT_COUNT " << passed.size() << "\n"
         << "\n// X(port, label) once per survivor, so that a consumer says\n"
         << "// what an entry is and this says only which ones there are.\n"
         << "#define SHADERTOY_EXTERNAL_PORTS(X)";

    for (const auto* outcome: passed)
        file << " \\\n    X(" << outcome->name << ", \"" << outcome->title << "\")";

    file << "\n";
}
} // namespace

bool writeRegistration(const Report& report, const Options& options)
{
    auto passed = survivorsOf(report);

    auto listPath = options.registerTo;
    auto list = std::ofstream(listPath);
    auto table = std::ofstream(tablePathFor(options));

    if (!list || !table)
        return false;

    writeCMakeList(list, report, options, passed);
    writeTable(table, report, passed);

    return list.good() && table.good();
}

Options parseOptions(int argc, char* argv[])
{
    auto options = Options {};

    for (auto index = 1; index < argc; ++index)
    {
        auto argument = std::string(argv[index]);

        if (argument == "--help" || argument == "-h")
            options.help = true;
        else if (argument == "--verbose")
            options.verbose = true;
        else if (argument == "--out" && index + 1 < argc)
            options.out = argv[++index];
        else if (argument == "--register" && index + 1 < argc)
            options.registerTo = argv[++index];
        else if (argument == "--jobs" && index + 1 < argc)
            options.jobs = (int) std::strtol(argv[++index], nullptr, 10);
        else if (argument.rfind('-', 0) == 0)
            options.valid = false;
        else
            options.inputs.add(argument);
    }

    if (options.inputs.empty())
        options.valid = false;

    return options;
}
} // namespace Shadertoy::Coverage
