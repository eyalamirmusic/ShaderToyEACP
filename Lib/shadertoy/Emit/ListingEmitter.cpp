#include "ListingEmitter.h"

#include <sstream>

namespace Shadertoy::Emit
{
namespace
{
// A byte as it has to be spelled inside a narrow string literal, given the one
// before it.
//
// Anything outside plain printable ASCII goes out octal rather than hex, and
// that is the whole reason this is not two lines: a hex escape has no length
// limit, so "\xe2" followed by an 'f' is one escape and not two, and a comment
// with an accented letter in it silently becomes a different string. An octal
// escape is at most three digits, so it always ends where it is written.
void appendEscaped(std::string& out, char character, char previous)
{
    const auto byte = (unsigned char) character;

    if (character == '\\' || character == '"')
    {
        out += '\\';
        out += character;
        return;
    }

    if (character == '\t')
    {
        out += "\\t";
        return;
    }

    // `??=` and its eight relatives are trigraphs, which a compiler still
    // honouring them reads as one character and one that does not warns about.
    // A question mark following another is escaped and no other is, so the
    // ternary a shader is full of keeps the `? :` it was written with.
    if (character == '?' && previous == '?')
    {
        out += "\\?";
        return;
    }

    if (byte < 0x20 || byte >= 0x7f)
    {
        constexpr auto digits = "01234567";

        out += '\\';
        out += digits[(byte >> 6) & 7];
        out += digits[(byte >> 3) & 7];
        out += digits[byte & 7];
        return;
    }

    out += character;
}

std::string quoted(const std::string& line)
{
    auto out = std::string {"\""};
    auto previous = char {};

    for (auto character: line)
    {
        appendEscaped(out, character, previous);
        previous = character;
    }

    return out + "\"";
}

// The lines of a text, with the carriage returns of a file written on Windows
// dropped - they would draw as a box at the end of every line.
void writeLines(std::ostream& file, const std::string& name, const std::string& text)
{
    file << "inline constexpr std::string_view " << name << "[] = {\n";

    auto lines = std::istringstream(text);
    auto line = std::string {};
    auto count = 0;

    while (std::getline(lines, line))
    {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();

        file << "    " << quoted(line) << ",\n";
        ++count;
    }

    // An array with no elements is not something C++ has, and a shader with no
    // text is a file somebody emptied rather than an error worth reporting.
    if (count == 0)
        file << "    \"\",\n";

    file << "};\n";
}
} // namespace

std::string emitListing(const std::string& structName,
                        const std::string& glsl,
                        const std::string& edsl)
{
    auto file = std::ostringstream {};

    file << "#pragma once\n\n"
         << "// Written by the transpiler: the two texts " << structName << " is.\n"
         << "//\n"
         << "// The GLSL is the shader as it was written for the page, and the\n"
         << "// EDSL is the header beside this one, verbatim. Shown side by side\n"
         << "// by Apps/Gallery, which is where a port stops being a row in a\n"
         << "// table and becomes something a person can read.\n\n"
         << "#include <shadertoy/Runtime/Listing.h>\n\n"
         << "namespace Shadertoy::Listings\n"
         << "{\n"
         << "namespace " << structName << "Text\n"
         << "{\n";

    writeLines(file, "glsl", glsl);
    file << "\n";
    writeLines(file, "edsl", edsl);

    file << "} // namespace " << structName << "Text\n\n"
         << "inline constexpr auto " << structName << " = Listing {\"" << structName
         << "\", " << structName << "Text::glsl, " << structName << "Text::edsl};\n"
         << "} // namespace Shadertoy::Listings\n";

    return file.str();
}
} // namespace Shadertoy::Emit
