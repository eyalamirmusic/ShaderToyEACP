#include "Coverage.h"

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

Outcome measure(const std::filesystem::path& source,
                const std::filesystem::path& out,
                const Compiler& compiler)
{
    auto outcome = Outcome {};

    outcome.source = source;
    outcome.name = structNameFor(source);

    auto result = transpile(readFile(source), outcome.name);
    outcome.converted = result.ok();

    for (const auto& diagnostic: result.diagnostics)
        outcome.gaps.add(std::string(name(diagnostic.kind)) + ": "
                         + diagnostic.detail);

    if (!outcome.converted)
        return outcome;

    auto header = out / (outcome.name + ".h");
    auto stream = std::ofstream(header, std::ios::binary);

    stream << result.code;
    stream.close();

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

Report scan(const Options& options, const Compiler& compiler)
{
    auto sources = shadersIn(options.inputs);
    auto report = Report {};

    report.outcomes.resize(sources.size());

    std::filesystem::create_directories(options.out);

    auto jobs =
        options.jobs > 0 ? options.jobs : (int) std::thread::hardware_concurrency();

    auto next = std::atomic<int> {0};

    auto work = [&]
    {
        for (auto index = next++; index < sources.size(); index = next++)
            report.outcomes[index] = measure(sources[index], options.out, compiler);
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
