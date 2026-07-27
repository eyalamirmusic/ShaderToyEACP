#include "Transpile.h"

#include "Glsl/Lower.h"
#include "Glsl/Parser.h"
#include "Glsl/Returns.h"

#include <set>
#include <tuple>

namespace Shadertoy
{
namespace
{
// One gap at one place in the file is one occurrence, however many times the
// lowering walks past it: a helper inlined at five call sites is one gap and
// not five, and a count that grew with the inlining would rank a shader by how
// often it calls something rather than by what it needs.
Glsl::Vector<Glsl::Diagnostic> distinct(const Glsl::Vector<Glsl::Diagnostic>& all)
{
    auto seen = std::set<std::tuple<int, std::string, int>> {};
    auto result = Glsl::Vector<Glsl::Diagnostic> {};

    for (const auto& diagnostic: all)
        if (seen.insert({(int) diagnostic.kind, diagnostic.detail, diagnostic.line})
                .second)
            result.add(diagnostic);

    return result;
}
} // namespace

TranspileResult transpile(const std::string& source, const std::string& structName)
{
    auto parsed = Glsl::parse(source);

    // Before flattening rather than during it: what this changes is the shape
    // of a body, and every pass after it - inlining included - wants the shape
    // it leaves rather than the one the shader was written with.
    Glsl::rewriteEarlyReturns(parsed.shader);

    auto lowered = Glsl::lower(parsed.shader);
    auto emitted = Cpp::emit(lowered.shader, structName);

    auto all = std::move(parsed.diagnostics);

    for (const auto& diagnostic: lowered.diagnostics)
        all.add(diagnostic);

    for (const auto& diagnostic: emitted.diagnostics)
        all.add(diagnostic);

    auto result = TranspileResult {};
    result.code = std::move(emitted.code);
    result.diagnostics = distinct(all);
    return result;
}
} // namespace Shadertoy
