#include "Lexer.h"

#include <algorithm>
#include <cctype>
#include <map>

namespace Shadertoy::Glsl
{
namespace
{
bool isIdentifierStart(char c)
{
    return std::isalpha((unsigned char) c) != 0 || c == '_';
}

bool isIdentifierPart(char c)
{
    return isIdentifierStart(c) || std::isdigit((unsigned char) c) != 0;
}

// The multi-character operators, longest first so that `<=` never lexes as `<`
// followed by `=`.
constexpr std::string_view multiCharacterOperators[] = {
    "<<=",
    ">>=",
    "==",
    "!=",
    "<=",
    ">=",
    "&&",
    "||",
    "^^",
    "+=",
    "-=",
    "*=",
    "/=",
    "%=",
    "++",
    "--",
    "<<",
    ">>",
};

// One pass over a chunk of source with no directive handling: the shader body
// and a macro's replacement list are scanned by the same code, which is what
// makes a macro expand into real tokens rather than a re-lexed string.
void scanChunk(std::string_view text, int startLine, Vector<Token>& out)
{
    auto line = startLine;
    auto index = std::size_t {0};

    while (index < text.size())
    {
        auto c = text[index];

        if (c == '\n')
        {
            ++line;
            ++index;
            continue;
        }

        if (std::isspace((unsigned char) c) != 0)
        {
            ++index;
            continue;
        }

        if (c == '/' && index + 1 < text.size() && text[index + 1] == '/')
        {
            while (index < text.size() && text[index] != '\n')
                ++index;

            continue;
        }

        if (c == '/' && index + 1 < text.size() && text[index + 1] == '*')
        {
            index += 2;

            while (index + 1 < text.size()
                   && !(text[index] == '*' && text[index + 1] == '/'))
            {
                if (text[index] == '\n')
                    ++line;

                ++index;
            }

            index = std::min(index + 2, text.size());
            continue;
        }

        if (isIdentifierStart(c))
        {
            auto start = index;

            while (index < text.size() && isIdentifierPart(text[index]))
                ++index;

            out.add({TokenType::Identifier,
                     std::string(text.substr(start, index - start)),
                     line});
            continue;
        }

        // A number, including the leading-dot form (.5) and exponents (1e-3).
        if (std::isdigit((unsigned char) c) != 0
            || (c == '.' && index + 1 < text.size()
                && std::isdigit((unsigned char) text[index + 1]) != 0))
        {
            auto start = index;

            while (index < text.size()
                   && (std::isdigit((unsigned char) text[index]) != 0
                       || text[index] == '.'))
                ++index;

            if (index < text.size() && (text[index] == 'e' || text[index] == 'E'))
            {
                ++index;

                if (index < text.size()
                    && (text[index] == '+' || text[index] == '-'))
                    ++index;

                while (index < text.size()
                       && std::isdigit((unsigned char) text[index]) != 0)
                    ++index;
            }

            // GLSL's float and unsigned suffixes carry no meaning here; the
            // emitter re-spells every literal for C++ anyway.
            while (index < text.size()
                   && (text[index] == 'f' || text[index] == 'F' || text[index] == 'u'
                       || text[index] == 'U'))
                ++index;

            out.add({TokenType::Number,
                     std::string(text.substr(start, index - start)),
                     line});
            continue;
        }

        auto rest = text.substr(index);
        auto matched = false;

        for (auto candidate: multiCharacterOperators)
        {
            if (rest.substr(0, candidate.size()) == candidate)
            {
                out.add({TokenType::Punctuator, std::string(candidate), line});
                index += candidate.size();
                matched = true;
                break;
            }
        }

        if (matched)
            continue;

        out.add({TokenType::Punctuator, std::string(1, c), line});
        ++index;
    }
}

// The span of one logical source line starting at index, following backslash
// continuations so a multi-line #define arrives as one piece.
std::size_t endOfDirective(std::string_view source, std::size_t index)
{
    while (index < source.size() && source[index] != '\n')
    {
        if (source[index] == '\\' && index + 1 < source.size()
            && source[index + 1] == '\n')
        {
            index += 2;
            continue;
        }

        ++index;
    }

    return index;
}

bool onlyBlankSinceLineStart(std::string_view source, std::size_t index)
{
    while (index > 0)
    {
        auto previous = source[index - 1];

        if (previous == '\n')
            return true;

        if (std::isspace((unsigned char) previous) == 0)
            return false;

        --index;
    }

    return true;
}

struct Macro
{
    Vector<Token> replacement;
};

// Substitutes object-like macros until nothing expands, with a depth cap so a
// macro defined in terms of itself terminates instead of running away.
Vector<Token> expandMacros(const Vector<Token>& tokens,
                           const std::map<std::string, Macro>& macros)
{
    constexpr auto maxDepth = 8;

    auto current = tokens;

    for (auto depth = 0; depth < maxDepth; ++depth)
    {
        auto expanded = Vector<Token> {};
        auto changed = false;

        for (const auto& token: current)
        {
            auto found =
                token.isIdentifier() ? macros.find(token.text) : macros.end();

            if (found == macros.end())
            {
                expanded.add(token);
                continue;
            }

            changed = true;

            for (const auto& replacement: found->second.replacement)
                expanded.add({replacement.type, replacement.text, token.line});
        }

        current = std::move(expanded);

        if (!changed)
            break;
    }

    return current;
}
} // namespace

Vector<Token> tokenize(const std::string& source, Vector<Diagnostic>& diagnostics)
{
    auto raw = Vector<Token> {};
    auto macros = std::map<std::string, Macro> {};

    auto view = std::string_view(source);
    auto index = std::size_t {0};
    auto line = 1;
    auto chunkStart = std::size_t {0};

    auto flushChunk = [&](std::size_t end)
    {
        if (end > chunkStart)
            scanChunk(view.substr(chunkStart, end - chunkStart), line, raw);
    };

    auto countLines = [&](std::size_t from, std::size_t to)
    {
        for (auto i = from; i < to; ++i)
            if (view[i] == '\n')
                ++line;
    };

    while (index < view.size())
    {
        if (view[index] != '#' || !onlyBlankSinceLineStart(view, index))
        {
            ++index;
            continue;
        }

        flushChunk(index);
        countLines(chunkStart, index);

        auto directiveEnd = endOfDirective(view, index);
        auto directive = view.substr(index, directiveEnd - index);
        auto directiveLine = line;

        // Split into the directive word and whatever follows it.
        auto body = Vector<Token> {};
        scanChunk(directive.substr(1), directiveLine, body);

        auto isDefine =
            body.size() >= 2 && body[0].is("define") && body[1].isIdentifier();

        // A macro is function-like when its `(` touches the name; with a space
        // between them the paren opens the replacement list instead. Telling
        // them apart needs the raw text, since the token stream has dropped the
        // whitespace that carries the distinction.
        auto functionLike = false;

        if (isDefine)
        {
            auto nameAt = directive.find(body[1].text, directive.find("define") + 6);

            if (nameAt != std::string_view::npos)
            {
                auto after = nameAt + body[1].text.size();
                functionLike = after < directive.size() && directive[after] == '(';
            }
        }

        if (isDefine && !functionLike)
        {
            auto macro = Macro {};

            for (auto i = 2; i < body.size(); ++i)
                macro.replacement.add(body[i]);

            macros[body[1].text] = std::move(macro);
        }
        else
        {
            auto what = body.empty() ? std::string("#") : "#" + body[0].text;

            if (functionLike)
                what += " (function-like macro)";

            diagnostics.add({DiagnosticKind::Preprocessor, what, directiveLine});
        }

        countLines(index, directiveEnd);
        index = directiveEnd;
        chunkStart = directiveEnd;
    }

    flushChunk(view.size());

    auto tokens = expandMacros(raw, macros);
    tokens.add({TokenType::End, "", line});
    return tokens;
}
} // namespace Shadertoy::Glsl
