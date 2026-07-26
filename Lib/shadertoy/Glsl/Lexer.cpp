#include "Lexer.h"

#include <algorithm>
#include <cctype>
#include <map>
#include <set>

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

bool isNumberSuffix(char c)
{
    return c == 'f' || c == 'F' || c == 'u' || c == 'U' || c == 'l' || c == 'L';
}

// The multi-character operators, longest first so that `<=` never lexes as `<`
// followed by `=`.
constexpr std::string_view multiCharacterOperators[] = {
    "<<=", ">>=", "==", "!=", "<=", ">=", "&&", "||", "^^", "+=",
    "-=",  "*=",  "/=", "%=", "++", "--", "<<", ">>", "##",
};

// One pass over a chunk of source with no directive handling: the shader body, a
// macro's replacement list and the joined halves of a `##` are scanned by the
// same code, which is what makes a macro expand into real tokens rather than a
// re-lexed string.
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

        // A number, including the leading-dot form (.5), exponents (1e-3) and
        // hexadecimal - which is how every hash constant a shader multiplies by
        // is written, and which lexed as `0` followed by a name until the base
        // was read here.
        if (std::isdigit((unsigned char) c) != 0
            || (c == '.' && index + 1 < text.size()
                && std::isdigit((unsigned char) text[index + 1]) != 0))
        {
            auto start = index;
            auto hexadecimal = c == '0' && index + 1 < text.size()
                               && (text[index + 1] == 'x' || text[index + 1] == 'X');

            if (hexadecimal)
            {
                index += 2;

                while (index < text.size()
                       && std::isxdigit((unsigned char) text[index]) != 0)
                    ++index;
            }
            else
            {
                while (index < text.size()
                       && (std::isdigit((unsigned char) text[index]) != 0
                           || text[index] == '.'))
                    ++index;

                if (index < text.size()
                    && (text[index] == 'e' || text[index] == 'E'))
                {
                    ++index;

                    if (index < text.size()
                        && (text[index] == '+' || text[index] == '-'))
                        ++index;

                    while (index < text.size()
                           && std::isdigit((unsigned char) text[index]) != 0)
                        ++index;
                }
            }

            // GLSL's float and unsigned suffixes carry no meaning here; the
            // emitter re-spells every literal for C++ anyway.
            while (index < text.size() && isNumberSuffix(text[index]))
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
    bool functionLike = false;
    Vector<std::string> parameters;
    Vector<Token> replacement;
};

using MacroTable = std::map<std::string, Macro>;

// The macros being expanded right now, so a macro that mentions its own name
// stops at it. This is C's rule rather than a depth cap, and the difference
// matters: a cap truncates an expansion that was going to terminate, while the
// name in flight leaves a self-reference standing exactly where the language
// says it should.
using ActiveMacros = std::set<std::string>;

// The parenthesised argument list of one invocation, with index left on the
// closing parenthesis. A comma inside a nested bracket belongs to the argument
// it sits in, which is what lets `MAX(f(a, b), c)` be two arguments and not
// three. Returns false when the closing parenthesis never arrives, so the name
// is left unexpanded rather than swallowing the rest of the file.
bool readArguments(const Vector<Token>& tokens,
                   int& index,
                   Vector<Vector<Token>>& arguments)
{
    auto depth = 0;
    auto argument = Vector<Token> {};
    auto sawComma = false;

    for (auto i = index; i < tokens.size(); ++i)
    {
        const auto& token = tokens[i];

        if (token.is("(") || token.is("["))
        {
            ++depth;

            if (depth == 1)
                continue;
        }
        else if (token.is(")") || token.is("]"))
        {
            --depth;

            if (depth == 0)
            {
                if (sawComma || !argument.empty())
                    arguments.add(argument);

                index = i;
                return true;
            }
        }
        else if (token.is(",") && depth == 1)
        {
            arguments.add(argument);
            argument.clear();
            sawComma = true;
            continue;
        }

        argument.add(token);
    }

    return false;
}

// `a ## b` is one token spelled from both halves, which is how a macro builds a
// name out of what it was handed. Re-lexing the joined text is what decides
// which kind of token that is.
Vector<Token> pasteTokens(const Vector<Token>& tokens)
{
    auto out = Vector<Token> {};

    for (auto i = 0; i < tokens.size(); ++i)
    {
        if (!tokens[i].is("##") || out.empty() || i + 1 >= tokens.size())
        {
            out.add(tokens[i]);
            continue;
        }

        auto joined = out.back().text + tokens[i + 1].text;
        auto line = out.back().line;

        out.pop_back();
        scanChunk(joined, line, out);
        ++i;
    }

    return out;
}

Vector<Token>
    substitute(const Macro& macro, const Vector<Vector<Token>>& arguments, int line)
{
    auto out = Vector<Token> {};

    for (const auto& token: macro.replacement)
    {
        auto parameter = -1;

        for (auto i = 0; token.isIdentifier() && i < macro.parameters.size(); ++i)
            if (macro.parameters[i] == token.text)
                parameter = i;

        if (parameter < 0 || parameter >= arguments.size())
        {
            out.add({token.type, token.text, line});
            continue;
        }

        for (const auto& argumentToken: arguments[parameter])
            out.add({argumentToken.type, argumentToken.text, line});
    }

    return pasteTokens(out);
}

Vector<Token> expandMacros(const Vector<Token>& tokens,
                           const MacroTable& macros,
                           ActiveMacros& active)
{
    auto out = Vector<Token> {};

    for (auto i = 0; i < tokens.size(); ++i)
    {
        const auto& token = tokens[i];
        auto found = token.isIdentifier() ? macros.find(token.text) : macros.end();

        if (found == macros.end() || active.count(token.text) != 0)
        {
            out.add(token);
            continue;
        }

        const auto& macro = found->second;
        auto arguments = Vector<Vector<Token>> {};
        auto last = i;

        if (macro.functionLike)
        {
            // Without the parentheses the name is only a name, as it is in C:
            // `#define S(a, b) ...` leaves a bare `S` alone.
            if (i + 1 >= tokens.size() || !tokens[i + 1].is("("))
            {
                out.add(token);
                continue;
            }

            last = i + 1;

            if (!readArguments(tokens, last, arguments))
            {
                out.add(token);
                continue;
            }

            // An argument is expanded before it is substituted, which is what
            // lets a macro be handed its own invocation - `MAX(MAX(a, b), c)`
            // would otherwise meet its own name painted over during the rescan.
            for (auto& argument: arguments)
                argument = expandMacros(argument, macros, active);
        }

        active.insert(token.text);

        auto body = substitute(macro, arguments, token.line);

        for (const auto& expanded: expandMacros(body, macros, active))
            out.add(expanded);

        active.erase(token.text);
        i = last;
    }

    return out;
}

long long integerValue(std::string_view text)
{
    auto base = 10LL;
    auto index = std::size_t {0};

    if (text.size() > 2 && text[0] == '0' && (text[1] == 'x' || text[1] == 'X'))
    {
        base = 16;
        index = 2;
    }

    auto value = 0LL;

    for (; index < text.size(); ++index)
    {
        auto c = text[index];
        auto digit = -1;

        if (c >= '0' && c <= '9')
            digit = c - '0';
        else if (base == 16 && c >= 'a' && c <= 'f')
            digit = c - 'a' + 10;
        else if (base == 16 && c >= 'A' && c <= 'F')
            digit = c - 'A' + 10;
        else
            break;

        value = value * base + digit;
    }

    return value;
}

// `#if` takes an integer constant expression, which is a language of its own:
// no floats, no calls, and every name that is not a macro standing for zero.
// It is small enough to parse by precedence in one descent.
struct ConditionEvaluator
{
    const Vector<Token>& tokens;
    int index = 0;

    bool at(std::string_view text) const
    {
        return index < tokens.size() && tokens[index].is(text);
    }

    bool take(std::string_view text)
    {
        if (!at(text))
            return false;

        ++index;
        return true;
    }

    long long primary()
    {
        if (index >= tokens.size())
            return 0;

        if (take("("))
        {
            auto value = logicalOr();
            take(")");
            return value;
        }

        const auto& token = tokens[index++];

        if (token.type == TokenType::Number)
            return integerValue(token.text);

        // An identifier that survived expansion names no macro, and an
        // undefined name is zero - which is what makes `#if UNSET` false
        // rather than an error.
        return 0;
    }

    long long unary()
    {
        if (take("!"))
            return unary() == 0 ? 1 : 0;

        if (take("~"))
            return ~unary();

        if (take("-"))
            return -unary();

        if (take("+"))
            return unary();

        return primary();
    }

    long long multiplicative()
    {
        auto value = unary();

        while (true)
        {
            if (take("*"))
                value *= unary();
            else if (take("/"))
            {
                auto divisor = unary();
                value = divisor == 0 ? 0 : value / divisor;
            }
            else if (take("%"))
            {
                auto divisor = unary();
                value = divisor == 0 ? 0 : value % divisor;
            }
            else
                return value;
        }
    }

    long long additive()
    {
        auto value = multiplicative();

        while (true)
        {
            if (take("+"))
                value += multiplicative();
            else if (take("-"))
                value -= multiplicative();
            else
                return value;
        }
    }

    long long shift()
    {
        auto value = additive();

        while (true)
        {
            if (take("<<"))
                value <<= additive();
            else if (take(">>"))
                value >>= additive();
            else
                return value;
        }
    }

    long long relational()
    {
        auto value = shift();

        while (true)
        {
            if (take("<="))
                value = value <= shift();
            else if (take(">="))
                value = value >= shift();
            else if (take("<"))
                value = value < shift();
            else if (take(">"))
                value = value > shift();
            else
                return value;
        }
    }

    long long equality()
    {
        auto value = relational();

        while (true)
        {
            if (take("=="))
                value = value == relational();
            else if (take("!="))
                value = value != relational();
            else
                return value;
        }
    }

    long long bitwiseAnd()
    {
        auto value = equality();

        while (take("&"))
            value &= equality();

        return value;
    }

    long long bitwiseXor()
    {
        auto value = bitwiseAnd();

        while (take("^"))
            value ^= bitwiseAnd();

        return value;
    }

    long long bitwiseOr()
    {
        auto value = bitwiseXor();

        while (take("|"))
            value |= bitwiseXor();

        return value;
    }

    long long logicalAnd()
    {
        auto value = bitwiseOr();

        while (take("&&"))
            value = (bitwiseOr() != 0 && value != 0) ? 1 : 0;

        return value;
    }

    long long logicalOr()
    {
        auto value = logicalAnd();

        while (take("||"))
            value = (logicalAnd() != 0 || value != 0) ? 1 : 0;

        return value;
    }
};

// `defined X` and `defined(X)` are answered before the line is expanded, since
// expanding first would replace the very name being asked about.
Vector<Token> resolveDefined(const Vector<Token>& tokens, const MacroTable& macros)
{
    auto out = Vector<Token> {};

    for (auto i = 0; i < tokens.size(); ++i)
    {
        if (!tokens[i].is("defined"))
        {
            out.add(tokens[i]);
            continue;
        }

        auto at = i + 1;
        auto parenthesised = at < tokens.size() && tokens[at].is("(");

        if (parenthesised)
            ++at;

        auto known = at < tokens.size() && tokens[at].isIdentifier()
                     && macros.count(tokens[at].text) != 0;

        out.add({TokenType::Number, known ? "1" : "0", tokens[i].line});

        if (parenthesised && at + 1 < tokens.size() && tokens[at + 1].is(")"))
            ++at;

        i = at;
    }

    return out;
}

// One `#if` chain. `active` is whether the tokens here reach the shader,
// `taken` whether any branch of the chain already did - which is what makes an
// `#elif` after a true branch inactive however true its own condition is.
struct Conditional
{
    bool active = true;
    bool taken = true;
    bool enclosingActive = true;
};

// The directives that describe the compilation rather than the program. A
// Shadertoy is pasted into a page that supplies its own `#version`, so these
// say nothing about what the EDSL can express and would only add noise to a
// report that is counted.
bool isIgnorableDirective(std::string_view word)
{
    return word == "version" || word == "extension" || word == "line"
           || word == "pragma";
}
} // namespace

Vector<Token> tokenize(const std::string& source, Vector<Diagnostic>& diagnostics)
{
    auto tokens = Vector<Token> {};
    auto macros = MacroTable {};
    auto conditionals = Vector<Conditional> {};

    auto view = std::string_view(source);
    auto index = std::size_t {0};
    auto line = 1;
    auto chunkStart = std::size_t {0};

    auto active = [&] { return conditionals.empty() || conditionals.back().active; };

    auto evaluate = [&](const Vector<Token>& condition)
    {
        auto expanding = ActiveMacros {};
        auto expanded =
            expandMacros(resolveDefined(condition, macros), macros, expanding);

        return ConditionEvaluator {expanded}.logicalOr() != 0;
    };

    auto flushChunk = [&](std::size_t end)
    {
        if (end <= chunkStart || !active())
            return;

        auto scanned = Vector<Token> {};
        scanChunk(view.substr(chunkStart, end - chunkStart), line, scanned);

        auto expanding = ActiveMacros {};

        for (const auto& token: expandMacros(scanned, macros, expanding))
            tokens.add(token);
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

        auto word = body.empty() ? std::string {} : body[0].text;

        auto rest = Vector<Token> {};

        for (auto i = 1; i < body.size(); ++i)
            rest.add(body[i]);

        // The `#if` family runs whether or not the branch it sits in is taken,
        // because it is what tracks the nesting: a skipped `#if` still owns the
        // `#endif` that closes it.
        if (word == "if" || word == "ifdef" || word == "ifndef")
        {
            auto enclosing = active();
            auto value = false;

            if (enclosing)
            {
                if (word == "if")
                {
                    value = evaluate(rest);
                }
                else
                {
                    auto defined = !rest.empty() && rest[0].isIdentifier()
                                   && macros.count(rest[0].text) != 0;

                    value = word == "ifdef" ? defined : !defined;
                }
            }

            conditionals.add({enclosing && value, enclosing && value, enclosing});
        }
        else if (word == "elif" || word == "else")
        {
            if (conditionals.empty())
            {
                diagnostics.add(
                    {DiagnosticKind::Preprocessor, "#" + word, directiveLine});
            }
            else
            {
                auto& top = conditionals.back();
                auto open = top.enclosingActive && !top.taken;

                top.active = open && (word == "else" || evaluate(rest));
                top.taken = top.taken || top.active;
            }
        }
        else if (word == "endif")
        {
            if (conditionals.empty())
                diagnostics.add(
                    {DiagnosticKind::Preprocessor, "#endif", directiveLine});
            else
                conditionals.pop_back();
        }
        else if (!active())
        {
            // A definition inside a branch that was not taken defines nothing,
            // and a directive there is not a gap in anything.
        }
        else if (word == "define" && body.size() >= 2 && body[1].isIdentifier())
        {
            // A macro is function-like when its `(` touches the name; with a
            // space between them the paren opens the replacement list instead.
            // Telling them apart needs the raw text, since the token stream has
            // dropped the whitespace that carries the distinction.
            auto functionLike = false;
            auto nameAt = directive.find(body[1].text, directive.find("define") + 6);

            if (nameAt != std::string_view::npos)
            {
                auto after = nameAt + body[1].text.size();
                functionLike = after < directive.size() && directive[after] == '(';
            }

            auto macro = Macro {};
            auto first = 2;

            if (functionLike)
            {
                macro.functionLike = true;
                first = 3;

                while (first < body.size() && !body[first].is(")"))
                {
                    if (body[first].isIdentifier())
                        macro.parameters.add(body[first].text);

                    ++first;
                }

                ++first;
            }

            for (auto i = first; i < body.size(); ++i)
                macro.replacement.add(body[i]);

            macros[body[1].text] = std::move(macro);
        }
        else if (word == "undef" && !rest.empty())
        {
            macros.erase(rest[0].text);
        }
        else if (!isIgnorableDirective(word))
        {
            diagnostics.add({DiagnosticKind::Preprocessor,
                             body.empty() ? std::string("#") : "#" + word,
                             directiveLine});
        }

        countLines(index, directiveEnd);
        index = directiveEnd;
        chunkStart = directiveEnd;
    }

    flushChunk(view.size());

    tokens.add({TokenType::End, "", line});
    return tokens;
}
} // namespace Shadertoy::Glsl
