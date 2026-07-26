#include "Common.h"

using namespace nano;
using namespace Shadertoy;

namespace
{
bool contains(const std::string& haystack, std::string_view needle)
{
    return haystack.find(needle) != std::string::npos;
}

int countOf(const TranspileResult& result, Glsl::DiagnosticKind kind)
{
    auto count = 0;

    for (const auto& diagnostic: result.diagnostics)
        if (diagnostic.kind == kind)
            ++count;

    return count;
}

bool reports(const TranspileResult& result,
             Glsl::DiagnosticKind kind,
             std::string_view detail)
{
    for (const auto& diagnostic: result.diagnostics)
        if (diagnostic.kind == kind && diagnostic.detail == detail)
            return true;

    return false;
}

// Wraps a body in the mainImage signature the corpus uses, so each test below
// is only the lines it is actually about.
TranspileResult convert(const std::string& body)
{
    return transpile("void mainImage(out vec4 fragColor, in vec2 fragCoord)\n{\n"
                         + body + "\n}\n",
                     "TestShader");
}
} // namespace

// Straight-line code is the whole of stage 1: locals, arithmetic, swizzles and
// the supported builtins convert with nothing left over.
auto tStraightLine = test("Glsl/straightLineConverts") = []
{
    auto result = convert("    vec2 uv = fragCoord / iResolution.xy;\n"
                          "    float d = length(uv) * 2.0;\n"
                          "    fragColor = vec4(uv, d, 1.0);");

    check(result.ok());
    check(contains(result.code, "auto uv = fragCoord / iResolution.xy();"));
    check(contains(result.code, "auto d = length(uv) * 2.0f;"));
    check(contains(result.code, "auto fragColor = float4(uv, d, 1.0f);"));
    check(contains(result.code, "return fragColor;"));

    // The port lands in its own namespace, where the Shadertoy alias for
    // eacp::GPU and the Program base are both already in scope.
    check(contains(result.code, "namespace Shadertoy::Ports"));
    check(contains(result.code, "struct TestShader final : Program"));
};

// GLSL's three component sets all mean x/y/z/w, and the EDSL exposes the
// single components plus the two leading runs. Anything reordered or offset -
// .zw, .yx - has no accessor, and saying so is more useful than emitting a
// call that will not compile without explanation.
auto tSwizzles = test("Glsl/swizzleMapping") = []
{
    auto colours = convert("    fragColor = vec4(iMouse.xy, iResolution.z, 1.0);");
    check(colours.ok());
    check(contains(colours.code, "iMouse.xy()"));
    check(contains(colours.code, "iResolution.z()"));

    auto named = convert("    vec3 c = iResolution.rgb;\n"
                         "    fragColor = vec4(c, 1.0);");
    check(named.ok());
    check(contains(named.code, "iResolution.xyz()"));

    auto reordered = convert("    fragColor = vec4(iMouse.zw, 0.0, 1.0);");
    check(!reordered.ok());
    check(reports(reordered, Glsl::DiagnosticKind::UnsupportedSwizzle, ".zw"));
};

// A vector built only from literals has no value handle to take a graph from,
// so the EDSL rejects it outright. Anchoring the first component with
// constant() is what makes `vec3(0.0)` expressible at all.
auto tLiteralConstructors = test("Glsl/literalConstructorsAnchor") = []
{
    auto result = convert("    vec3 c = vec3(0.0);\n"
                          "    fragColor = vec4(c, 1.0);");

    check(result.ok());
    check(contains(result.code, "float3(constant(0.0f), 0.0f, 0.0f)"));

    // With a name anywhere in the arguments there is already a graph to record
    // into, and the anchor would be noise.
    auto mixed = convert("    fragColor = vec4(iTime, 0.0, 0.0, 1.0);");
    check(mixed.ok());
    check(contains(mixed.code, "float4(iTime, 0.0f, 0.0f, 1.0f)"));
};

// A scalar spreads across every component in GLSL; the EDSL's constructors take
// one argument each.
auto tBroadcast = test("Glsl/scalarBroadcast") = []
{
    auto result = convert("    vec3 c = vec3(iTime);\n"
                          "    fragColor = vec4(c, 1.0);");

    check(result.ok());
    check(contains(result.code, "float3(iTime, iTime, iTime)"));
};

// Compound assignment is just a rebind, since a C++ local holding a handle
// takes a new node on assignment - the same property that lets GLSL locals
// convert one for one.
auto tCompoundAssignment = test("Glsl/compoundAssignment") = []
{
    auto result = convert("    vec3 c = vec3(iTime);\n"
                          "    c += 0.5;\n"
                          "    fragColor = vec4(c, 1.0);");

    check(result.ok());
    check(contains(result.code, "c = c + 0.5f;"));
};

// `col -= a + b` must not become `col = col - a + b`.
auto tCompoundKeepsGrouping = test("Glsl/compoundAssignmentGrouping") = []
{
    auto result = convert("    float v = iTime;\n"
                          "    v -= iTime + 1.0;\n"
                          "    fragColor = vec4(v, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "v = v - (iTime + 1.0f);"));
};

// Object-like macros are resolved in the lexer: leaving them to the parser
// would fail shaders over notation rather than over any missing capability.
// Function-like ones are a real gap and say so.
auto tPreprocessor = test("Glsl/objectLikeDefines") = []
{
    auto expanded = transpile("#define SCALE 8.0\n"
                              "void mainImage(out vec4 o, in vec2 p)\n"
                              "{\n"
                              "    o = vec4(p * SCALE, 0.0, 1.0);\n"
                              "}\n",
                              "TestShader");

    check(expanded.ok());
    check(contains(expanded.code, "p * 8.0f"));

    auto functionLike = transpile("#define SQ(x) ((x) * (x))\n"
                                  "void mainImage(out vec4 o, in vec2 p)\n"
                                  "{\n"
                                  "    o = vec4(p, 0.0, 1.0);\n"
                                  "}\n",
                                  "TestShader");

    check(countOf(functionLike, Glsl::DiagnosticKind::Preprocessor) == 1);
};

// The parameter names carry through, so a port reads like its source rather
// than like the transpiler's idea of what things should be called.
auto tParameterNames = test("Glsl/keepsParameterNames") = []
{
    auto result = transpile("void mainImage(out vec4 O, in vec2 I)\n"
                            "{\n"
                            "    O = vec4(I / iResolution.xy, 0.0, 1.0);\n"
                            "}\n",
                            "TestShader");

    check(result.ok());
    check(contains(result.code, "mainImage(const GPU::Float2& I)"));
    check(contains(result.code, "auto O = "));
    check(contains(result.code, "return O;"));
};

// The point of the whole exercise: one shader reports every wall it hits, not
// the first. A `for` loop does not stop the atan below it from being counted,
// because the coverage table is only useful if it sees everything.
auto tCollectsEveryGap = test("Glsl/collectsEveryGap") = []
{
    auto result = convert("    vec3 col = vec3(0.0);\n"
                          "    for (int i = 0; i < 8; i++) { col += 0.1; }\n"
                          "    col += atan(fragCoord.x);\n"
                          "    if (col.x > 1.0) { col = vec3(1.0); }\n"
                          "    fragColor = vec4(col, 1.0);");

    check(!result.ok());
    check(reports(result, Glsl::DiagnosticKind::ControlFlow, "for"));
    check(reports(result, Glsl::DiagnosticKind::ControlFlow, "if"));
    check(reports(result, Glsl::DiagnosticKind::UnsupportedIntrinsic, "atan"));

    // Recovery left the surrounding shader intact.
    check(contains(result.code, "auto fragColor = float4(col, 1.0f);"));
};

// Named so the report groups two shaders blocked by the same builtin together.
auto tIntrinsicNames = test("Glsl/intrinsicsAreNamed") = []
{
    for (auto builtin: {"exp", "log", "mod", "sign", "reflect", "fwidth"})
    {
        auto result = convert(std::string("    fragColor = vec4(") + builtin
                              + "(fragCoord.x, 1.0), 0.0, 0.0, 1.0);");

        check(reports(result, Glsl::DiagnosticKind::UnsupportedIntrinsic, builtin));
    }
};

// A helper function is stage 2 work, and until then it is reported by name
// rather than silently emitted as an unresolved call.
auto tUserFunctions = test("Glsl/userFunctionsReported") = []
{
    auto result = transpile("float sdBox(vec2 p) { return length(p); }\n"
                            "void mainImage(out vec4 o, in vec2 p)\n"
                            "{\n"
                            "    o = vec4(sdBox(p), 0.0, 0.0, 1.0);\n"
                            "}\n",
                            "TestShader");

    check(reports(result, Glsl::DiagnosticKind::UserFunction, "sdBox"));
};

// Texture channels arrive with stage 4; until then they are their own category
// in the report rather than an unresolved name.
auto tChannels = test("Glsl/channelsReported") = []
{
    auto result = convert("    fragColor = texture(iChannel0, fragCoord);");

    check(reports(result, Glsl::DiagnosticKind::UnsupportedTexture, "texture"));
};

// Generated headers sit in a project built to eacp's style, so they hold to its
// column limit instead of arriving as one line per statement.
auto tColumnLimit = test("Glsl/respectsColumnLimit") = []
{
    auto result = convert("    float v = sin(fragCoord.x * 8.0 + iTime)\n"
                          "            + sin(fragCoord.y * 8.0 + iTime * 1.3)\n"
                          "            + sin(length(fragCoord) * 12.0 - iTime);\n"
                          "    fragColor = vec4(v, v, v, 1.0);");

    check(result.ok());

    auto longest = std::size_t {0};
    auto start = std::size_t {0};

    while (start <= result.code.size())
    {
        auto end = result.code.find('\n', start);

        if (end == std::string::npos)
            end = result.code.size();

        longest = std::max(longest, end - start);
        start = end + 1;
    }

    check(longest <= 85);
};
