#include <eacp/Core/Process/Process.h>
#include <shadertoy/Coverage/Coverage.h>

#include <fstream>
#include <iostream>

// Converts a directory of Shadertoys, compiles what converted, and tabulates
// both.
//
// The two numbers this prints were produced by hand once, in stage 10, and the
// larger of the two findings was that half of what the coverage report passed a
// compiler rejected. A finding that size is worth rerunning after every change,
// which is the whole reason this exists: a fix to eacp or to the transpiler is
// scored by the difference between two runs of it rather than by an argument
// about what it should have been worth.
//
// The scanning is Lib/shadertoy/Scan, where a test can drive it without a
// toolchain. This is the command line around it, and the one part that needs
// one: the compiler, the flags a port is compiled with, and the wiring between
// them, all of which the build knows and a library cannot.

using namespace Shadertoy;

namespace
{
// The command line a port is compiled with, written by the build - one flag per
// line, so a path with a space in it stays one flag. Baked in as a path rather
// than as the flags themselves because the flags are generator expressions, and
// those are known when the build tree is generated rather than when this file
// is compiled.
eacp::Vector<std::string> compileFlags()
{
    auto flags = eacp::Vector<std::string> {};
    auto stream = std::ifstream(SHADERTOY_SCAN_FLAGS);
    auto line = std::string {};

    while (std::getline(stream, line))
        if (!line.empty())
            flags.add(line);

    return flags;
}

// The header, and nothing this file chose. Which flags check a header without
// compiling it, and how they are spelled, is a fact about the driver rather
// than about scanning - and a driver drops a flag meant for another one instead
// of refusing it, so a spelling guessed here is a corpus measured against a
// compiler nobody configured. See Tools/Scan/CMakeLists.txt, which writes them.
Coverage::Compiler probeCompiler()
{
    auto flags = compileFlags();

    return [flags](const std::filesystem::path& header)
    {
        auto arguments = flags;
        arguments.add(header.string());

        auto result = eacp::Processes::run(SHADERTOY_SCAN_COMPILER, arguments);

        if (result.exitCode == 0)
            return std::string {};

        // Clang says it on stderr and cl says it on stdout, and a failure
        // nobody can read is a row the table cannot fill in.
        return result.errorOutput.empty() ? result.output : result.errorOutput;
    };
}

void printUsage()
{
    std::cout
        << "Converts a corpus of Shadertoys and compiles what converted.\n\n"
        << "Usage:\n"
        << "  shadertoy-scan <directory-or-shader>...\n\n"
        << "  --out <dir>        where the generated headers are left\n"
        << "                     (default: scan)\n"
        << "  --jobs <n>         compilers to run at once (default: one per\n"
        << "                     core)\n"
        << "  --register <file>  write what survived as CMake a build can\n"
        << "                     include(), and the entry table beside the\n"
        << "                     headers it names\n"
        << "  --verbose          name every shader that converted and did not\n"
        << "                     compile, with what the compiler said first\n\n"
        << "A shader that does not convert is not compiled: the gap it\n"
        << "reported is already the answer. One that converts and does not\n"
        << "compile is the case the coverage report cannot see, since by then\n"
        << "it has already said the shader converted.\n\n"
        << "What --register writes is two files: a CMake list at <file>, and\n"
        << "an ExternalCorpus.h beside the headers holding their includes and\n"
        << "an entry table. Apps/Gallery runs all of this for itself, so this\n"
        << "is the command to reach for over a corpus that is not that one.\n";
}
} // namespace

int main(int argc, char* argv[])
{
    auto options = Coverage::parseOptions(argc, argv);

    if (!options.valid || options.help)
    {
        printUsage();
        return options.help ? 0 : 2;
    }

    auto compiler = probeCompiler();

    // Before the corpus, the compiler. A scan that cannot compile anything at
    // all still prints a table and still registers what survived, and what
    // survived is nothing - so a build wired to it goes on quietly missing
    // every shader it was supposed to measure. That is the one failure this
    // reports instead of tabulating.
    if (auto broken = Coverage::checkCompiler(compiler, options.out);
        !broken.empty())
    {
        std::cerr << "The compiler this scans with cannot compile a port at all,\n"
                     "so nothing it would say about the corpus is a measurement.\n"
                     "That is the toolchain wiring rather than the shaders: the\n"
                     "flags are written by Tools/Scan/CMakeLists.txt, and read\n"
                     "from "
                  << SHADERTOY_SCAN_FLAGS << ".\n\n"
                  << broken << "\n";

        return 1;
    }

    auto report = Coverage::scan(options, compiler);

    Coverage::printReport(report, options.verbose);

    if (options.registerTo.empty())
        return 0;

    if (!Coverage::writeRegistration(report, options))
    {
        std::cerr << "cannot write " << options.registerTo << "\n";
        return 1;
    }

    std::cout << "\nRegistered " << report.compiled() << " shaders in "
              << options.registerTo << ",\nwith the table beside their headers in "
              << Coverage::tablePathFor(options) << ".\n"
              << "That says they compile. Nothing yet says they are right.\n";

    return 0;
}
