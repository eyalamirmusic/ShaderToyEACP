#pragma once

#include <shadertoy/Transpile.h>

#include <filesystem>
#include <functional>
#include <string>

// Both ways a shader fails, over one corpus, in one run.
//
// The coverage report answers whether the transpiler could express a shader.
// It is structurally unable to answer the next question - whether the C++ it
// emitted is C++ a compiler accepts - because by then it has already said the
// shader converted. Stage 10 measured that gap by hand and found half of what
// the report passed was rejected by a compiler, which is a large enough number
// that measuring it by hand again is not an option.
//
// So this is the report and the compiler as one pass: convert everything, feed
// what converted to a compiler, and tabulate both. The compile step is a
// std::function for the same reason the fetcher's transport is one - it is the
// only part that needs a toolchain, and everything around it is bookkeeping
// over whatever it returns.
namespace Shadertoy::Coverage
{
using eacp::Vector;

// What one shader did, all the way through. A shader that did not convert is
// never compiled: there is no header to compile, and the gap it reported is
// already the answer.
struct Outcome
{
    bool passed() const { return converted && compiled; }

    std::string name;
    std::filesystem::path source;

    // What to call this shader in front of a person: the first comment line of
    // the source if it has one, which is where both fetchers put the id and the
    // author, and the file's own stem otherwise. Nothing measures with it - it
    // is for the one layer of validation that is a human looking at the frame,
    // and knowing whose shader is on screen is most of what that layer needs.
    std::string title;

    bool converted = false;
    Vector<std::string> gaps;

    bool compiled = false;
    Vector<std::string> errors;

    // What the compiler said first, kept whole. The tables group by shape, and
    // a shape is not enough to go and fix anything by.
    std::string firstError;
};

// The one thing here that needs a toolchain: a header in, whatever the
// compiler said about it out. Empty means it compiled. Called from several
// threads at once, so an implementation has to be one that can be.
using Compiler = std::function<std::string(const std::filesystem::path& header)>;

struct Options
{
    Vector<std::filesystem::path> inputs;

    // Where the generated headers are left. They are what the compiler is
    // handed, and keeping them is what makes a failure something to go and
    // look at rather than a line in a table.
    std::filesystem::path out = "scan";

    // Where to write what survived, as CMake a build can include(). Empty means
    // the scan only prints, which is what it did before there was anything that
    // could consume the answer.
    std::filesystem::path registerTo;

    // Compilers to run at once. The conversion is microseconds and the compile
    // is seconds, so this is the whole of the wall clock.
    int jobs = 0;

    bool valid = true;
    bool help = false;
    bool verbose = false;
};

Options parseOptions(int argc, char* argv[]);

// One row of either table: what blocks a shader, how many it blocks - which is
// what the roadmap is sorted by - and how often it came up in total.
struct Row
{
    std::string blocker;
    int shaders = 0;
    int occurrences = 0;
};

// The shape of a compiler error: the message with everything specific to this
// one shader taken out of it, so that two shaders that failed the same way land
// on one row. "use of undeclared identifier 'p'" and the same about 'q' are one
// blocker and not two.
std::string errorShape(const std::string& message);

// The error lines out of a compiler's diagnostics, shaped and deduplicated in
// the order they were reported.
Vector<std::string> errorsIn(const std::string& diagnostics);

// What a shape means and whose column it belongs in. A shape nobody has named
// yet is reported as itself, which is how the table discovers a row rather than
// being told its rows in advance.
struct Blame
{
    std::string label;
    std::string whose;
};

Blame blame(const std::string& shape);

struct Report
{
    int converted() const;
    int compiled() const;

    // What stopped a shader converting, ranked by how many it stopped.
    Vector<Row> conversionRows() const;

    // What stopped a converted shader compiling, ranked the same way and keyed
    // on the first error only - a shader is blocked by what it hits first.
    Vector<Row> compileRows() const;

    // Of the shaders that failed to compile, how many would compile if this one
    // blocker went away: the ones reporting nothing else. It is the number that
    // says what a fix is worth, and it is not the row's own count.
    int unblockedBy(const std::string& shape) const;

    Vector<Outcome> outcomes;
};

Report scan(const Options& options, const Compiler& compiler);

void printReport(const Report& report, bool verbose);

// What survived, written where a build can read it rather than left as a number
// in a table. Two files, because two different things consume them: a CMake
// list a target include()s to learn the names and the include path, and beside
// the generated headers an X-macro over the whole set, which is the include
// list and the entry table an app would otherwise hold by hand.
//
// It is also what makes the count checkable in the other direction. A
// registration with as many entries as the table claims agree, or one of the
// two is lying - and a gallery that fails to build is the second check on the
// same claim, since a header that compiled alone still has to compile beside
// ninety-four others.
//
// The registration says a shader converted and compiled. It does not say
// anybody has looked at the frame, and the file it writes says so too.
bool writeRegistration(const Report& report, const Options& options);

// Where the X-macro over the survivors is written, which is inside `out`
// because that is already the directory a consumer puts on its include path.
std::filesystem::path tablePathFor(const Options& options);
} // namespace Shadertoy::Coverage
