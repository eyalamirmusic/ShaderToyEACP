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
// The include path a port is compiled against, written by the build - one flag
// per line, so a path with a space in it stays one flag. Baked in as a path
// rather than as the flags themselves because the flags are generator
// expressions, and those are known when the build tree is generated rather than
// when this file is compiled.
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

// A port is a header declaring one struct whose member functions are defined
// inline, so type-checking the header is the whole question: there is nothing
// to instantiate and nothing to link. -fsyntax-only is therefore the compile,
// and it is what makes scanning a corpus take minutes rather than an hour.
Coverage::Compiler probeCompiler()
{
    auto flags = compileFlags();

    return [flags](const std::filesystem::path& header)
    {
        auto arguments = flags;

        arguments.add("-fsyntax-only");
        arguments.add("-fno-caret-diagnostics");
        arguments.add("-fno-color-diagnostics");
        arguments.add("-fshow-overloads=best");
        arguments.add("-ferror-limit=0");
        arguments.add("-x");
        arguments.add("c++");
        arguments.add(header.string());

        auto result = eacp::Processes::run(SHADERTOY_SCAN_COMPILER, arguments);

        return result.exitCode == 0 ? std::string {} : result.errorOutput;
    };
}

void printUsage()
{
    std::cout
        << "Converts a corpus of Shadertoys and compiles what converted.\n\n"
        << "Usage:\n"
        << "  shadertoy-scan <directory-or-shader>...\n\n"
        << "  --out <dir>   where the generated headers are left\n"
        << "                (default: scan)\n"
        << "  --jobs <n>    compilers to run at once (default: one per core)\n"
        << "  --verbose     name every shader that converted and did not\n"
        << "                compile, with what the compiler said first\n\n"
        << "A shader that does not convert is not compiled: the gap it\n"
        << "reported is already the answer. One that converts and does not\n"
        << "compile is the case the coverage report cannot see, since by then\n"
        << "it has already said the shader converted.\n";
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

    Coverage::printReport(Coverage::scan(options, probeCompiler()), options.verbose);
    return 0;
}
