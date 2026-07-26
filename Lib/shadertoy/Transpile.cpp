#include "Transpile.h"

#include "Glsl/Parser.h"

namespace Shadertoy
{
TranspileResult transpile(const std::string& source, const std::string& structName)
{
    auto parsed = Glsl::parse(source);
    auto emitted = Cpp::emit(parsed.shader, structName);

    auto result = TranspileResult {};
    result.code = std::move(emitted.code);

    for (const auto& diagnostic: parsed.diagnostics)
        result.diagnostics.add(diagnostic);

    for (const auto& diagnostic: emitted.diagnostics)
        result.diagnostics.add(diagnostic);

    return result;
}
} // namespace Shadertoy
