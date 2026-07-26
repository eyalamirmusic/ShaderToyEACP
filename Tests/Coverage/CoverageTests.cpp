#include <shadertoy/Coverage/Coverage.h>

#include <NanoTest/NanoTest.h>

#include <fstream>
#include <map>

using namespace nano;
using namespace Shadertoy;

namespace
{
// A compiler, in the shape a real one answers in, without a toolchain. What the
// scan's whole job is is deciding what a shader did and grouping shaders that
// did the same thing, so what a test asserts on is mostly this: what it was
// handed, and which row the answer landed in.
struct FakeCompiler
{
    std::string operator()(const std::filesystem::path& header)
    {
        auto stem = header.stem().string();
        auto found = errors.find(stem);

        return found != errors.end() ? found->second : std::string {};
    }

    std::map<std::string, std::string> errors;
};

std::filesystem::path scratch()
{
    auto directory = std::filesystem::temp_directory_path() / "shadertoy-coverage";

    std::filesystem::remove_all(directory);
    std::filesystem::create_directories(directory / "in");

    return directory;
}

void write(const std::filesystem::path& path, const std::string& text)
{
    auto stream = std::ofstream(path, std::ios::binary);
    stream << text;
}

std::string shaderBody(const std::string& body)
{
    return "void mainImage(out vec4 fragColor, in vec2 fragCoord)\n{\n" + body
           + "\n}\n";
}

const Coverage::Outcome* outcomeOf(const Coverage::Report& report,
                                   const std::string& name)
{
    for (const auto& outcome: report.outcomes)
        if (outcome.name == name)
            return &outcome;

    return nullptr;
}

std::string error(const std::string& message)
{
    return "/tmp/x.h:12:7: error: " + message + "\n";
}
} // namespace

// Two shaders that failed the same way have to agree on one row, and what makes
// them agree is dropping everything about the message that is about this shader
// rather than about what went wrong.
auto tErrorShape = test("Coverage/errorsOfOneKindAgree") = []
{
    check(Coverage::errorShape("use of undeclared identifier 'ro'")
          == Coverage::errorShape("use of undeclared identifier 'kk'"));

    // clang offers a spelling suggestion on some occurrences of a message and
    // not on others, which split one blocker across two rows until it went.
    check(Coverage::errorShape("use of undeclared identifier 'float2'; did you "
                               "mean '__float2'?")
          == Coverage::errorShape("use of undeclared identifier 'ro'"));

    check(Coverage::errorShape("invalid operands to binary expression ('Float3' "
                               "and 'Float2')")
          == "invalid operands to binary expression");

    // And two that failed differently must not.
    check(Coverage::errorShape("no matching function for call to 'min'")
          != Coverage::errorShape("no member named 'x' in 'Float'"));
};

// The kinds a compiler reported, in the order it reported them and once each -
// the first is what blocked the shader, and the rest are what else would have
// to go for a fix to that one to be worth anything.
auto tErrorsIn = test("Coverage/errorsAreDeduplicatedInOrder") = []
{
    auto found =
        Coverage::errorsIn(error("no matching function for call to 'min'")
                           + "somewhere.h:3:1: note: candidate ignored\n"
                           + error("use of undeclared identifier 'p'")
                           + error("no matching function for call to 'max'"));

    check(found.size() == 2);
    check(found[0] == "no matching function for call to");
    check(found[1] == "use of undeclared identifier");
};

// A shader that does not convert is never compiled: there is no header to
// compile, and the gap it reported is already the answer.
auto tGapsSkipTheCompiler = test("Coverage/whatDoesNotConvertIsNotCompiled") = []
{
    auto directory = scratch();

    write(directory / "in" / "Plain.glsl",
          shaderBody("    fragColor = vec4(fragCoord / iResolution.xy, 0.0, 1.0);"));

    write(directory / "in" / "Blocked.glsl",
          shaderBody("    if (fragCoord.x > 0.0) return;\n"
                     "    fragColor = vec4(1.0);"));

    auto options = Coverage::Options {};
    options.inputs.add(directory / "in");
    options.out = directory / "out";
    options.jobs = 1;

    auto compiler = FakeCompiler {};
    auto report = Coverage::scan(options, compiler);

    check(report.outcomes.size() == 2);
    check(report.converted() == 1);
    check(report.compiled() == 1);

    const auto* blocked = outcomeOf(report, "Blocked");
    check(blocked != nullptr && !blocked->converted && !blocked->compiled);
    check(!std::filesystem::exists(directory / "out" / "Blocked.h"));

    // And what does convert is written out, because a failure is something to
    // go and look at rather than a line in a table.
    check(std::filesystem::exists(directory / "out" / "Plain.h"));
};

// The two numbers a fix is scored by, which rank the same list differently on
// purpose: a shader is blocked by whichever blocker it hit first, and compiles
// the day every blocker it has is closed.
auto tRanking = test("Coverage/blockedFirstIsNotUnblockedOutright") = []
{
    auto directory = scratch();

    for (auto name: {"One", "Two", "Three"})
        write(directory / "in" / (std::string(name) + ".glsl"),
              shaderBody("    fragColor = vec4(fragCoord / iResolution.xy, 0.0, "
                         "1.0);"));

    auto compiler = FakeCompiler {};

    compiler.errors["One"] = error("no matching function for call to 'min'");
    compiler.errors["Two"] = error("no matching function for call to 'max'")
                             + error("use of undeclared identifier 'p'");
    compiler.errors["Three"] = error("use of undeclared identifier 'q'");

    auto options = Coverage::Options {};
    options.inputs.add(directory / "in");
    options.out = directory / "out";
    options.jobs = 1;

    auto report = Coverage::scan(options, compiler);

    check(report.converted() == 3);
    check(report.compiled() == 0);

    auto rows = report.compileRows();
    check(rows.size() == 2);

    // Two shaders hit the overload first and three mention it or the other one;
    // only one of the two would compile if the overload alone went away.
    check(rows[0].blocker == "no matching function for call to");
    check(rows[0].shaders == 2);
    check(report.unblockedBy(rows[0].blocker) == 1);

    check(rows[1].shaders == 1);
    check(report.unblockedBy(rows[1].blocker) == 1);
};

// A blocker nobody has named yet is reported as itself, which is how the table
// discovers a row rather than being told its rows in advance.
auto tBlame = test("Coverage/anUnnamedBlockerIsItsOwnRow") = []
{
    check(Coverage::blame("no matching function for call to").whose == "eacp");
    check(Coverage::blame("use of undeclared identifier").whose == "transpiler");

    auto unknown = Coverage::blame("something nobody has seen yet");
    check(unknown.whose == "?");
    check(unknown.label == "something nobody has seen yet");
};
