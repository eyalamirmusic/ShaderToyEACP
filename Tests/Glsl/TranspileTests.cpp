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

int countOccurrences(const std::string& haystack, const std::string& needle)
{
    auto count = 0;

    for (auto found = haystack.find(needle); found != std::string::npos;
         found = haystack.find(needle, found + needle.size()))
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

// GLSL's three component sets all mean x/y/z/w, and stage 3 gave the EDSL an
// accessor for every ordering of up to four of them - so a reordered or offset
// swizzle is now one call, and stays one node in the graph behind it.
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

    auto reordered = convert("    fragColor = vec4(iMouse.zw, iMouse.yx);");
    check(reordered.ok());
    check(contains(reordered.code, "iMouse.zw()"));
    check(contains(reordered.code, "iMouse.yx()"));

    auto wide = convert("    fragColor = iMouse.bgra;");
    check(wide.ok());
    check(contains(wide.code, "iMouse.zyxw()"));
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
// the first. A loop that will not unroll does not stop the determinant below it
// from being counted, because the coverage table is only useful if it sees
// everything.
auto tCollectsEveryGap = test("Glsl/collectsEveryGap") = []
{
    auto result =
        convert("    vec3 col = vec3(0.0);\n"
                "    for (float t = 0.0; t < iTime; t += 1.0)\n"
                "        col += determinant(mat2(t, 0.0, 0.0, t));\n"
                "    if (col.x > 1.0) { col += transpose(mat2(col.x))[0]; }\n"
                "    fragColor = vec4(col, 1.0);");

    check(!result.ok());
    check(
        reports(result, Glsl::DiagnosticKind::UnsupportedIntrinsic, "determinant"));
    check(reports(result, Glsl::DiagnosticKind::UnsupportedIntrinsic, "transpose"));

    // Recovery left the surrounding shader intact.
    check(contains(result.code, "auto fragColor = float4(col(), 1.0f);"));
};

// The intrinsics stage 3 closed, and the two places GLSL and the EDSL disagree
// on how to spell one: atan picks its name by argument count, and inversesqrt
// is rsqrt, the way both shading languages have it.
auto tStageThreeIntrinsics = test("Glsl/stageThreeIntrinsics") = []
{
    auto result = convert("    float a = atan(fragCoord.y, fragCoord.x);\n"
                          "    float b = atan(a) + tan(a) + asin(a) + acos(a);\n"
                          "    float c = exp(b) + log(b) + exp2(b) + log2(b);\n"
                          "    float d = mod(c, 2.0) + sign(c) + inversesqrt(c);\n"
                          "    float e = ceil(d) + round(d) + trunc(d);\n"
                          "    vec3 n = normalize(vec3(a, b, c));\n"
                          "    vec3 f = reflect(n, n) + refract(n, n, 0.5);\n"
                          "    float g = distance(n, f) + fwidth(e) + dFdx(e);\n"
                          "    fragColor = vec4(f * g, 1.0);");

    check(result.ok());
    check(contains(result.code, "atan2(fragCoord.y(), fragCoord.x())"));
    check(contains(result.code, "atan(a)"));
    check(contains(result.code, "rsqrt(c)"));
    check(contains(result.code, "mod(c, 2.0f)"));
    check(contains(result.code, "dfdx(e)"));
    check(contains(result.code, "refract(n, n, 0.5f)"));
};

// GLSL fills a matrix column by column, so mat2(c, s, -s, c) - the rotation
// every second procedural shader opens with - is the columns (c, s) and
// (-s, c), and the EDSL's constructor takes exactly those.
auto tMatrixConstructors = test("Glsl/matrixConstructors") = []
{
    auto rotation = convert("    float c = cos(iTime);\n"
                            "    float s = sin(iTime);\n"
                            "    mat2 m = mat2(c, s, -s, c);\n"
                            "    fragColor = vec4(m * fragCoord, 0.0, 1.0);");

    check(rotation.ok());
    check(contains(rotation.code, "float2x2(float2(c, s), float2(-s, c))"));
    check(contains(rotation.code, "m * fragCoord"));

    // Column vectors pass straight through, and a lone scalar is the diagonal.
    auto columns = convert("    mat3 m = mat3(vec3(iTime), vec3(0.0), vec3(1.0));\n"
                           "    fragColor = vec4(m * vec3(fragCoord, 1.0), 1.0);");
    check(columns.ok());
    check(contains(columns.code, "float3x3(float3(iTime, iTime, iTime)"));

    auto diagonal = convert("    mat2 m = mat2(iTime);\n"
                            "    fragColor = vec4(m * fragCoord, 0.0, 1.0);");
    check(diagonal.ok());
    check(contains(diagonal.code,
                   "float2x2(float2(iTime, 0.0f), float2(0.0f, iTime))"));
};

// GLSL reads `vector * matrix` as the row vector on the left, which is the
// transposed product - a different value from the one the EDSL spells, so it is
// reported rather than quietly emitted the other way round.
auto tVectorTimesMatrix = test("Glsl/vectorTimesMatrixIsReported") = []
{
    auto result = convert("    mat2 m = mat2(iTime, 0.0, 0.0, iTime);\n"
                          "    vec2 v = fragCoord * m;\n"
                          "    fragColor = vec4(v, 0.0, 1.0);");

    check(!result.ok());
    check(reports(result, Glsl::DiagnosticKind::UnsupportedType, "vector * matrix"));
};

// A loop bounded by a constant becomes that many copies of its body, with the
// counter substituted as a literal - so nothing about `int` survives to be a
// gap, and the locals the body declares are renamed to share one C++ scope.
auto tUnrollsConstantLoop = test("Glsl/unrollsConstantLoop") = []
{
    auto result = convert("    vec3 col = vec3(0.0);\n"
                          "    for (int i = 0; i < 3; i++)\n"
                          "    {\n"
                          "        float wave = sin(fragCoord.x + float(i));\n"
                          "        col += wave;\n"
                          "    }\n"
                          "    fragColor = vec4(col, 1.0);");

    check(result.ok());
    check(contains(result.code, "auto wave = sin(fragCoord.x() + 0.0f);"));
    check(contains(result.code, "auto wave_2 = sin(fragCoord.x() + 1.0f);"));
    check(contains(result.code, "auto wave_3 = sin(fragCoord.x() + 2.0f);"));
    check(contains(result.code, "col = col + wave_3;"));
    check(!contains(result.code, "for"));
};

// A loop the transpiler cannot count is a loop the port runs: the init above
// it, the condition tested each time round, and the step as the last thing the
// body does. What the body needs is counted the same as anywhere else.
auto tDynamicLoop = test("Glsl/dynamicLoopBecomesALoop") = []
{
    auto result = convert("    vec3 col = vec3(0.0);\n"
                          "    for (float t = 0.0; t < iTime; t += 1.0)\n"
                          "        col += inverse(mat2(t, 0.0, 0.0, t))[0].x;\n"
                          "    fragColor = vec4(col, 1.0);");

    check(countOf(result, Glsl::DiagnosticKind::ControlFlow) == 0);
    check(reports(result, Glsl::DiagnosticKind::UnsupportedIntrinsic, "inverse"));

    check(contains(result.code, "auto t = var(0.0f);"));
    check(contains(result.code, "loop(t() < iTime, [&]"));
    check(contains(result.code, "t = t() + 1.0f;"));
};

// The counter of a loop the port kept counts in the type the shader wrote it
// in. Both sides of its header have to agree, and here the bound is a
// truncation of a uniform - so a float counter would be comparing across the
// two vocabularies, which neither GLSL nor the EDSL will do.
auto tIntegerCounter = test("Glsl/integerCounterStaysAnInteger") = []
{
    auto result = convert("    float total = 0.0;\n"
                          "    for (int i = 0; i < int(iTime); i++)\n"
                          "        total += 1.0;\n"
                          "    fragColor = vec4(total, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "auto i = var(0);"));
    check(contains(result.code, "loop(i() < toInt(iTime), [&]"));
    check(contains(result.code, "i = i() + 1;"));
};

// A while is the loop with nothing to unroll at all, and it lowers to the same
// statement a for does.
auto tWhileLoop = test("Glsl/whileConverts") = []
{
    auto result = convert("    float d = 0.0;\n"
                          "    while (d < iTime)\n"
                          "        d += 0.1;\n"
                          "    fragColor = vec4(d, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "auto d = var(0.0f);"));
    check(contains(result.code, "loop(d() < iTime, [&]"));
    check(contains(result.code, "d = d() + 0.1f;"));
};

// Nested loops multiply out, the inner one unrolling once per copy of the
// outer.
auto tUnrollsNestedLoops = test("Glsl/unrollsNestedLoops") = []
{
    auto result = convert("    float total = 0.0;\n"
                          "    for (int y = 0; y < 2; y++)\n"
                          "        for (int x = 0; x < 2; x++)\n"
                          "            total += float(x) * float(y);\n"
                          "    fragColor = vec4(total, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(countOf(result, Glsl::DiagnosticKind::ControlFlow) == 0);

    // Four copies, and the products of the two counters folded away with them.
    auto assignments = std::size_t {0};

    for (auto at = result.code.find("total = total"); at != std::string::npos;
         at = result.code.find("total = total", at + 1))
        ++assignments;

    check(assignments == 4);
};

// A jump is what an unrollable loop cannot have: the copies would each need to
// know whether an earlier one had already stopped. So a loop holding one stays
// a loop, however countable its header is.
auto tLoopWithBreak = test("Glsl/loopWithBreakIsNotUnrolled") = []
{
    auto result = convert("    float d = 0.0;\n"
                          "    for (int i = 0; i < 8; i++)\n"
                          "    {\n"
                          "        d += 0.1;\n"
                          "        if (d > 0.5) break;\n"
                          "        d += 0.2;\n"
                          "    }\n"
                          "    fragColor = vec4(d, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "loop(i() < 8, [&]"));
    check(contains(result.code, "breakLoop();"));

    // Once, not eight times.
    check(countOccurrences(result.code, "d = d() + 0.1f;") == 1);
};

// A continue in a for goes to the step, and the loop the port emits keeps its
// step at the end of the body - so the jump has to take the step with it or the
// counter stops moving.
auto tContinueRunsTheStep = test("Glsl/continueRunsTheStep") = []
{
    auto result = convert("    float d = 0.0;\n"
                          "    for (int i = 0; i < 8; i++)\n"
                          "    {\n"
                          "        if (d > 0.5) continue;\n"
                          "        d += 0.1;\n"
                          "    }\n"
                          "    fragColor = vec4(d, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "continueLoop();"));
    check(countOccurrences(result.code, "i = i() + 1;") == 2);
};

// A branch is a statement, and each side records into a body of its own.
auto tBranches = test("Glsl/branchesConvert") = []
{
    auto result = convert("    vec3 col = vec3(0.0);\n"
                          "    if (fragCoord.x > iTime)\n"
                          "        col = vec3(1.0, 0.0, 0.0);\n"
                          "    else\n"
                          "        col = vec3(0.0, 0.0, 1.0);\n"
                          "    fragColor = vec4(col, 1.0);");

    check(result.ok());
    check(contains(result.code, "ifThen(fragCoord.x() > iTime, [&]"));
    check(contains(result.code, "col = float3(constant(1.0f), 0.0f, 0.0f);"));
    check(contains(result.code, "col = float3(constant(0.0f), 0.0f, 1.0f);"));
    check(contains(result.code, "auto fragColor = float4(col(), 1.0f);"));
};

// A condition the transpiler can settle is not a branch at all - the shape a
// `#define`d quality switch has - so only the side that runs is emitted.
auto tConstantCondition = test("Glsl/constantConditionIsNotABranch") = []
{
    auto result = convert("#define QUALITY 2\n"
                          "    vec3 col = vec3(0.0);\n"
                          "    if (QUALITY > 1)\n"
                          "        col = vec3(1.0);\n"
                          "    else\n"
                          "        col = vec3(0.5);\n"
                          "    fragColor = vec4(col, 1.0);");

    check(result.ok());
    check(!contains(result.code, "ifThen"));
    check(!contains(result.code, "var("));

    // Only the side that runs: the other one costs the port nothing, not even
    // a binding it never reads.
    check(contains(result.code, "col = float3(constant(1.0f), 1.0f, 1.0f);"));
    check(!contains(result.code, "0.5f"));
};

// The comparisons, the connectives and the ternary: what a branch tests, and
// the branchless way to pick between two values that are both already there.
auto tComparisons = test("Glsl/comparisonsConvert") = []
{
    auto result = convert("    float a = fragCoord.x;\n"
                          "    float b = a > 1.0 && a < 8.0 ? 1.0 : 0.0;\n"
                          "    float c = !(a == 2.0) || a != 3.0 ? b : a;\n"
                          "    fragColor = vec4(b, c, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "select(a > 1.0f && a < 8.0f, 1.0f, 0.0f)"));
    check(contains(result.code, "select(!(a == 2.0f) || a != 3.0f, b, a)"));
};

// The names a loop or a branch writes from outside its own scope are the ones
// the port has to hold in a variable: a C++ handle rebound inside a lambda is a
// new handle that dies at the closing brace. Everything else stays a plain
// binding, which is what keeps an unrolled shader reading the way it did.
auto tVariablePromotion = test("Glsl/writtenNamesBecomeVariables") = []
{
    auto result = convert("    float outer = 0.0;\n"
                          "    float once = 2.0;\n"
                          "    while (outer < iTime)\n"
                          "    {\n"
                          "        float inner = once * 2.0;\n"
                          "        outer += inner;\n"
                          "    }\n"
                          "    fragColor = vec4(outer, once, 0.0, 1.0);");

    check(result.ok());

    // Written by the body, declared outside it.
    check(contains(result.code, "auto outer = var(0.0f);"));

    // Only read by the body, and declared inside it: neither needs a variable.
    check(contains(result.code, "auto once = constant(2.0f);"));
    check(contains(result.code, "auto inner = once * 2.0f;"));
    check(contains(result.code,
                   "auto fragColor = float4(outer(), once, 0.0f, 1.0f);"));
};

// A bool is a value the EDSL now has, so a flag a shader sets and later tests
// converts rather than naming the type as a gap.
auto tBoolLocals = test("Glsl/boolLocalsConvert") = []
{
    auto result = convert("    bool hit = false;\n"
                          "    if (fragCoord.x > iTime)\n"
                          "        hit = true;\n"
                          "    fragColor = hit ? vec4(1.0) : vec4(0.0);");

    check(result.ok());
    check(contains(result.code, "auto hit = var(boolean(false));"));
    check(contains(result.code, "hit = boolean(true);"));
    check(contains(result.code, "select(hit()"));
};

// An integer local that will not fold is an integer, and so is every literal
// standing beside it: `index & 3` needs a 3, while the truncation it was built
// from still needs its 4.0f. Where a literal sits is what decides which it is.
auto tIntegerLocals = test("Glsl/integerLocalsConvert") = []
{
    auto result =
        convert("    vec2 uv = fragCoord / iResolution.xy;\n"
                "    int index = int(uv.x * 4.0) & 3;\n"
                "    int mixed = (index << 2 | index >> 1) ^ ~index;\n"
                "    fragColor = vec4(float(mixed % 5) * 0.2, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "auto index = toInt(uv.x() * 4.0f) & 3;"));
    check(contains(result.code, "auto mixed = (index << 2 | index >> 1) ^ ~index;"));
    check(contains(result.code, "toFloat(mixed % 5) * 0.2f"));
};

// iFrame is an int on the Shadertoy page, and now an Int in the port: it was a
// float only for as long as there was nothing else for it to be. A shader
// cycling on the frame count is the shape that cared.
auto tFrameCounterIsAnInteger = test("Glsl/frameCounterIsAnInteger") = []
{
    auto result = convert("    float phase = float(iFrame % 120) / 120.0;\n"
                          "    fragColor = vec4(phase, 0.0, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "auto phase = toFloat(iFrame % 120) / 120.0f;"));
};

// A `uint` is still the gap it was - the EDSL's unsigned type belongs to a
// compute kernel - and so does every operator reached over floats, which is
// what keeps the report honest about what the integer type did and did not buy.
auto tIntegerGaps = test("Glsl/integerGapsReported") = []
{
    auto unsignedLocal =
        convert("    uint bits = uint(iTime) + 1u;\n"
                "    fragColor = vec4(float(bits), 0.0, 0.0, 1.0);");

    check(reports(unsignedLocal, Glsl::DiagnosticKind::UnsupportedType, "uint"));

    auto overFloats = convert("    float t = iTime * 8.0;\n"
                              "    fragColor = vec4(t % 3.0, 0.0, 0.0, 1.0);");

    check(reports(overFloats, Glsl::DiagnosticKind::UnsupportedType, "int %"));
};

// A constant array is one declaration and one subscript, which is the whole of
// what a palette needs. The index is an integer, so the literal in it is one.
auto tConstantArray = test("Glsl/constantArrayConverts") = []
{
    auto result = transpile("const vec3 tint[3] = vec3[3](vec3(1.0, 0.0, 0.0),\n"
                            "                             vec3(0.0, 1.0, 0.0),\n"
                            "                             vec3(0.0, 0.0, 1.0));\n"
                            "void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                            "{\n"
                            "    int index = int(fragCoord.x) % 3;\n"
                            "    fragColor = vec4(tint[index] + tint[0], 1.0);\n"
                            "}\n",
                            "TestShader");

    check(result.ok());
    check(contains(result.code, "auto tint = array(float3(constant(1.0f)"));
    check(contains(result.code, "tint[index] + tint[0]"));

    // The size in the brackets is dropped on both sides, so the two spellings
    // of it cannot disagree.
    check(!contains(result.code, "[3]"));
};

// The integer vector: a whole coordinate crossing at once rather than a
// component at a time, and a component of the result crossing back. Which
// vocabulary a number is spelled in is still decided by where it sits, so the
// mask literal beside a cell is an integer and the divisor beside a coordinate
// is not.
auto tIntegerVectors = test("Glsl/integerVectorsConvert") = []
{
    auto result = convert("    ivec2 cell = ivec2(fragCoord / 16.0);\n"
                          "    ivec2 wrapped = cell & 7;\n"
                          "    int sum = wrapped.x + wrapped.y;\n"
                          "    fragColor = vec4(vec3(float(sum) * 0.05), 1.0);");

    check(result.ok());
    check(contains(result.code, "auto cell = toInt(fragCoord / 16.0f);"));
    check(contains(result.code, "auto wrapped = cell & 7;"));
    check(contains(result.code, "auto sum = wrapped.x() + wrapped.y();"));
    check(contains(result.code, "toFloat(sum) * 0.05f"));

    // Built from components rather than converted, which is the constructor
    // proper - and it anchors itself, having no name in it to take a graph from.
    auto built =
        convert("    ivec2 fixed = ivec2(3, 4);\n"
                "    fragColor = vec4(float(fixed.x + fixed.y), 0.0, 0.0, 1.0);");

    check(built.ok());
    check(contains(built.code, "auto fixed = int2(integer(3), 4);"));
};

// The boolean vector, which is only ever what comparing two vectors yields.
// GLSL spells the comparison as a call because it reserves the operators for
// scalars; both languages the EDSL emits into give the operator itself to a
// pair of vectors, so the port writes the operator - and all() is what turns
// what it yields back into something a select can test.
auto tVectorComparisons = test("Glsl/vectorComparisonsConvert") = []
{
    auto result =
        convert("    bvec2 inside = lessThan(fragCoord, iResolution.xy * 0.75);\n"
                "    bvec2 far = greaterThanEqual(fragCoord, iResolution.xy);\n"
                "    float lit = all(inside) ? 1.0 : 0.25;\n"
                "    float edge = any(not(far)) ? 0.5 : 0.0;\n"
                "    fragColor = vec4(lit, edge, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code,
                   "auto inside = fragCoord < iResolution.xy() * 0.75f;"));
    check(contains(result.code, "auto far = fragCoord >= iResolution.xy();"));
    check(contains(result.code, "select(all(inside), 1.0f, 0.25f)"));
    check(contains(result.code, "any(!(far))"));
};

// What the vectors do not reach. The unsigned ones go with the unsigned scalar,
// whose EDSL counterpart is the compute thread id and which nothing in a
// fragment shader gets at.
auto tVectorGaps = test("Glsl/unsignedVectorsReported") = []
{
    auto result = convert("    uvec2 bits = uvec2(fragCoord);\n"
                          "    fragColor = vec4(float(bits.x), 0.0, 0.0, 1.0);");

    check(reports(result, Glsl::DiagnosticKind::UnsupportedType, "uvec2"));
};

namespace
{
// Wraps a body in a struct declaration and the mainImage signature, which is
// the shape every one of the struct tests below takes.
TranspileResult convertWithHit(const std::string& body)
{
    return transpile("struct Hit\n"
                     "{\n"
                     "    float distance;\n"
                     "    vec3 albedo;\n"
                     "};\n"
                         + body,
                     "TestShader");
}
} // namespace

// A struct is not a capability the EDSL is missing after all: it is a name for
// its fields, and lowering already renames every local into one flat scope. So
// one becomes a local per field and nothing about it reaches the emitter.
//
// It is also the shape that used to hang the parser outright, which the second
// half of this pins: recovery skips to a semicolon and stops at a closing brace
// without consuming it, so the brace a struct body leaves behind was reported,
// skipped to, and reported again forever.
auto tStructScalarises = test("Glsl/structScalarisesIntoItsFields") = []
{
    auto result =
        convertWithHit("void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                       "{\n"
                       "    Hit hit = Hit(fragCoord.x, vec3(1.0, 0.0, 0.0));\n"
                       "    fragColor = vec4(hit.albedo * hit.distance, 1.0);\n"
                       "}\n");

    check(result.diagnostics.empty());
    check(contains(result.code, "auto hit_distance = fragCoord.x();"));
    check(contains(result.code, "auto hit_albedo = float3(constant(1.0f), 0.0f,"));
    check(contains(result.code, "float4(hit_albedo * hit_distance, 1.0f)"));

    // No aggregate reaches the generated file - the type is gone with the
    // grammar that spelled it.
    check(!contains(result.code, "Hit"));

    auto empty =
        convertWithHit("void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                       "{\n"
                       "    fragColor = vec4(fragCoord, 0.0, 1.0);\n"
                       "}\n");

    check(countOf(empty, Glsl::DiagnosticKind::ParseError) == 0);
    check(contains(empty.code, "auto fragColor = float4(fragCoord, 0.0f, 1.0f);"));
};

// A struct written inside a loop and read after it needs each of its fields to
// be a variable, for exactly the reason one field on its own would: a C++ handle
// rebound inside a lambda is a new handle that dies at the closing brace. The
// pass that decides that runs on the scalarised output, so it needs to know
// nothing about aggregates to get this right.
auto tStructEscapesALoop = test("Glsl/structFieldsEscapeALoopSeparately") = []
{
    auto result =
        convertWithHit("Hit scene(vec3 p)\n"
                       "{\n"
                       "    return Hit(length(p) - 1.0, vec3(0.9, 0.4, 0.2));\n"
                       "}\n"
                       "void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                       "{\n"
                       "    float travelled = 0.0;\n"
                       "    Hit hit = scene(vec3(0.0));\n"
                       "    while (travelled < 8.0)\n"
                       "    {\n"
                       "        hit = scene(vec3(fragCoord, travelled));\n"
                       "        if (hit.distance < 0.001)\n"
                       "            break;\n"
                       "        travelled += hit.distance;\n"
                       "    }\n"
                       "    fragColor = vec4(hit.albedo, 1.0);\n"
                       "}\n");

    check(result.diagnostics.empty());
    check(contains(result.code, "auto hit_distance = var("));
    check(contains(result.code, "auto hit_albedo = var("));

    // And both are written where the loop wrote the struct, and read where the
    // shading read it.
    check(contains(result.code, "hit_distance = length("));
    check(contains(result.code, "hit_albedo = float3("));
    check(contains(result.code, "float4(hit_albedo(), 1.0f)"));
};

// Writing to one field is an assignment to a local like any other once the
// struct is scalarised, and it must not come out as the component write the
// EDSL genuinely has no spelling for. The two are told apart by what sits at
// the root of the path, which is the only thing that distinguishes them.
auto tStructFieldWrite = test("Glsl/structFieldWriteIsNotAComponentWrite") = []
{
    auto result =
        convertWithHit("void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                       "{\n"
                       "    Hit hit = Hit(0.0, vec3(0.0));\n"
                       "    hit.distance = fragCoord.x;\n"
                       "    hit.albedo = vec3(1.0, 0.5, 0.0);\n"
                       "    fragColor = vec4(hit.albedo * hit.distance, 1.0);\n"
                       "}\n");

    check(result.diagnostics.empty());
    check(contains(result.code, "hit_distance = fragCoord.x();"));

    // A component of a vector still is one, and still says so.
    auto component = convert("    vec3 col = vec3(0.0);\n"
                             "    col.x = 1.0;\n"
                             "    fragColor = vec4(col, 1.0);");

    check(reports(component, Glsl::DiagnosticKind::ComponentAssignment, ".x"));
};

// A struct through an out parameter, which is the write-back path a field at a
// time. Every field the helper left something in has to arrive back at the
// caller's own local, or the shader reads what it had before the call.
auto tStructOutParameter = test("Glsl/structWritesBackThroughAnOutParameter") = []
{
    auto result =
        convertWithHit("void nearest(vec2 p, inout Hit best)\n"
                       "{\n"
                       "    best.distance = length(p);\n"
                       "    best.albedo = vec3(p, 0.5);\n"
                       "}\n"
                       "void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                       "{\n"
                       "    Hit best = Hit(1000.0, vec3(0.0));\n"
                       "    nearest(fragCoord, best);\n"
                       "    fragColor = vec4(best.albedo * best.distance, 1.0);\n"
                       "}\n");

    check(result.diagnostics.empty());
    check(countOf(result, Glsl::DiagnosticKind::UserFunction) == 0);
    check(contains(result.code, "best_distance = "));
    check(contains(result.code, "best_albedo = "));
    check(contains(result.code, "float4(best_albedo * best_distance, 1.0f)"));
};

// What is left of the aggregate once the fields are ordinary locals: an array
// of them, which would need an array per leaf and a subscript that agreed
// across all of them, and a struct holding an array, which has no single value
// per field to become. Both name one capability rather than scattering the
// fields they could not keep across every line that touches one.
auto tStructGapsThatRemain = test("Glsl/theAggregateGapsThatRemain") = []
{
    auto array =
        convertWithHit("void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                       "{\n"
                       "    Hit hits[2];\n"
                       "    fragColor = vec4(fragCoord, 0.0, 1.0);\n"
                       "}\n");

    check(reports(array, Glsl::DiagnosticKind::UnsupportedType, "array of structs"));
    check(countOf(array, Glsl::DiagnosticKind::ParseError) == 0);

    auto field = transpile("struct Table\n"
                           "{\n"
                           "    float weights[4];\n"
                           "};\n"
                           "void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                           "{\n"
                           "    Table t = Table(fragCoord.x);\n"
                           "    fragColor = vec4(fragCoord, 0.0, 1.0);\n"
                           "}\n",
                           "TestShader");

    check(countOf(field, Glsl::DiagnosticKind::UnsupportedType) == 1);
    check(reports(field, Glsl::DiagnosticKind::UnsupportedType, "struct"));
    check(countOf(field, Glsl::DiagnosticKind::ParseError) == 0);
};

// A subscript of something the port never declared as an array is the gap it
// was: iChannelResolution is the one a Shadertoy reads without declaring, and
// it needs no array type because only a literal ever indexes it.
auto tSubscriptGap = test("Glsl/nonArraySubscriptIsReported") = []
{
    auto result = convert("    mat2 m = mat2(1.0, 0.0, 0.0, 1.0);\n"
                          "    fragColor = vec4(m[0], 0.0, 1.0);");

    check(reports(result, Glsl::DiagnosticKind::UnsupportedType, "indexing"));
};

// A return that is not the last thing a body does leaves early, which a ported
// mainImage cannot: it is one expression returned at the end.
auto tEarlyReturn = test("Glsl/earlyReturnIsReported") = []
{
    auto result = convert("    if (fragCoord.x > iTime)\n"
                          "        return;\n"
                          "    fragColor = vec4(1.0);");

    check(reports(result, Glsl::DiagnosticKind::ControlFlow, "early return"));
};

// However many copies a loop makes of a gap, it is one gap at one place in the
// file: a count that grew with the trip count would rank a shader by how long
// its loops are.
auto tUnrollingDoesNotInflate = test("Glsl/unrollingCountsGapsOnce") = []
{
    auto result = convert("    float total = 0.0;\n"
                          "    for (int i = 0; i < 16; i++)\n"
                          "        total += determinant(mat2(float(i)));\n"
                          "    fragColor = vec4(total, 0.0, 0.0, 1.0);");

    check(countOf(result, Glsl::DiagnosticKind::UnsupportedIntrinsic) == 1);
};

// Named so the report groups two shaders blocked by the same builtin together.
// What is left after stage 3 is the matrix vocabulary: the EDSL can build a
// Float2x2 and multiply one, and that is where it stops.
auto tIntrinsicNames = test("Glsl/intrinsicsAreNamed") = []
{
    for (auto builtin: {"transpose", "inverse", "determinant"})
    {
        auto result = convert(std::string("    fragColor = vec4(") + "float("
                              + builtin + "(mat2(iTime))), 0.0, 0.0, 1.0);");

        check(reports(result, Glsl::DiagnosticKind::UnsupportedIntrinsic, builtin));
    }
};

// A helper whose body is one expression is replaced by that expression. An
// argument that is a name or a literal is substituted; anything the body would
// otherwise evaluate twice is bound to a local of its own first.
auto tInlinesHelpers = test("Glsl/inlinesHelpers") = []
{
    auto result =
        transpile("float sdBox(vec2 p, float r) { return length(p) - r; }\n"
                  "void mainImage(out vec4 o, in vec2 c)\n"
                  "{\n"
                  "    float d = sdBox(c, 0.5);\n"
                  "    float e = sdBox(c * 2.0, 0.5);\n"
                  "    o = vec4(d, e, 0.0, 1.0);\n"
                  "}\n",
                  "TestShader");

    check(result.ok());
    check(contains(result.code, "auto d = length(c) - 0.5f;"));
    check(contains(result.code, "auto p = c * 2.0f;"));
    check(contains(result.code, "auto e = length(p) - 0.5f;"));
};

// Helpers calling helpers unwind all the way down.
auto tInlinesNestedHelpers = test("Glsl/inlinesNestedHelpers") = []
{
    auto result = transpile("float inner(float x) { return x * x; }\n"
                            "float outer(float x) { return inner(x) + 1.0; }\n"
                            "void mainImage(out vec4 o, in vec2 c)\n"
                            "{\n"
                            "    o = vec4(outer(c.x), 0.0, 0.0, 1.0);\n"
                            "}\n",
                            "TestShader");

    check(result.ok());
    check(contains(result.code, "auto x = c.x();"));
    check(contains(result.code, "float4(x * x + 1.0f, 0.0f, 0.0f, 1.0f)"));
};

// An inout parameter is the other way a helper hands a value back, and the
// caller sees the write.
auto tInlinesOutParameters = test("Glsl/inlinesOutParameters") = []
{
    auto result = transpile("void twice(inout vec2 p) { p = p * 2.0; }\n"
                            "void mainImage(out vec4 o, in vec2 c)\n"
                            "{\n"
                            "    vec2 uv = c;\n"
                            "    twice(uv);\n"
                            "    o = vec4(uv, 0.0, 1.0);\n"
                            "}\n",
                            "TestShader");

    check(result.ok());
    check(contains(result.code, "uv = p;"));
    check(contains(result.code, "auto o = float4(uv, 0.0f, 1.0f);"));
};

// A helper the port cannot flatten is reported by name rather than silently
// emitted as an unresolved call - and what is inside it is counted too, so the
// table never promises that inlining alone would turn the shader green.
auto tUserFunctions = test("Glsl/userFunctionsReported") = []
{
    auto result = transpile("float sdBox(vec2 p)\n"
                            "{\n"
                            "    if (p.x > 0.0) return 1.0;\n"
                            "    return determinant(mat2(p.y));\n"
                            "}\n"
                            "void mainImage(out vec4 o, in vec2 p)\n"
                            "{\n"
                            "    o = vec4(sdBox(p), 0.0, 0.0, 1.0);\n"
                            "}\n",
                            "TestShader");

    check(reports(result, Glsl::DiagnosticKind::UserFunction, "sdBox"));
    check(reports(result, Glsl::DiagnosticKind::ControlFlow, "early return"));
    check(
        reports(result, Glsl::DiagnosticKind::UnsupportedIntrinsic, "determinant"));
};

// A channel read is a sample, and the port declares the channel it read. The
// declaration is the point: every texture a port declares is one the draw has
// to bind, so a shader that samples one channel must not carry four.
auto tChannels = test("Glsl/channelsConvert") = []
{
    auto result = convert("    vec2 uv = fragCoord / iResolution.xy;\n"
                          "    fragColor = texture(iChannel2, uv);");

    check(result.ok());
    check(contains(result.code, "Channel iChannel2;"));
    check(contains(result.code, "SHADERTOY_UNIFORMS(iChannel2)"));
    check(contains(result.code, "sample(iChannel2, uv)"));
    check(!contains(result.code, "iChannel0"));
};

// The other two reads. textureLod names the level rather than taking the one
// the derivatives imply; texelFetch addresses texels rather than the unit
// square, which is what iChannelResolution is there to make possible - and the
// ivec2 it is spelled with is the type the coordinate keeps, since the EDSL has
// an integer vector for it to arrive in.
auto tChannelReads = test("Glsl/levelAndFetchConvert") = []
{
    auto result =
        convert("    vec2 uv = fragCoord / iResolution.xy;\n"
                "    vec2 texel = iChannelResolution[0].xy * uv;\n"
                "    vec4 near = textureLod(iChannel0, uv, 0.0);\n"
                "    vec4 exact = texelFetch(iChannel0, ivec2(texel), 0);\n"
                "    fragColor = near + exact;");

    check(result.ok());
    check(contains(result.code, "auto texel = iChannel0.resolution.xy() * uv;"));
    check(contains(result.code, "sample(iChannel0, uv, 0.0f)"));
    check(contains(result.code, "fetch(iChannel0, toInt(texel))"));

    // Two scalars rather than a vector to convert, which is the other spelling
    // of the same coordinate - and there both numbers are integer literals.
    auto pair = convert("    fragColor = texelFetch(iChannel0, ivec2(4, 9), 0);");

    check(pair.ok());
    check(contains(pair.code, "fetch(iChannel0, int2(integer(4), 9))"));
};

// What the channels do not reach. A texture with one level cannot be read at
// another, and neither backend is handed the gradients or the dimensions
// through an expression, so each stays a row in the report rather than emitting
// something that would compile and be wrong.
auto tChannelGaps = test("Glsl/channelGapsReported") = []
{
    auto biased = convert("    fragColor = texture(iChannel0, fragCoord, 1.0);");
    check(reports(biased, Glsl::DiagnosticKind::UnsupportedTexture, "texture bias"));

    auto gradient = convert("    fragColor = textureGrad(iChannel0, fragCoord, "
                            "fragCoord, fragCoord);");
    check(
        reports(gradient, Glsl::DiagnosticKind::UnsupportedTexture, "textureGrad"));

    auto size =
        convert("    fragColor = vec4(textureSize(iChannel0, 0), 0.0, 1.0);");
    check(reports(size, Glsl::DiagnosticKind::UnsupportedTexture, "textureSize"));

    auto level =
        convert("    fragColor = texelFetch(iChannel0, ivec2(fragCoord), 2);");
    check(reports(
        level, Glsl::DiagnosticKind::UnsupportedTexture, "texelFetch level"));
};

// A channel only a statement lowering threw away reads is not one the port
// declares: it would be a texture every draw has to bind and the shader never
// looks at. The gap inside that statement is still counted, the way every other
// gap in dropped code is.
auto tDroppedChannels = test("Glsl/droppedChannelsAreNotDeclared") = []
{
    auto result = transpile("vec4 pick(vec2 p)\n"
                            "{\n"
                            "    if (p.x > 0.0)\n"
                            "        return texture(iChannel1, p);\n"
                            "    return vec4(0.0);\n"
                            "}\n"
                            "void mainImage(out vec4 fragColor, in vec2 fragCoord)\n"
                            "{\n"
                            "    fragColor = texture(iChannel0, fragCoord)\n"
                            "              + pick(fragCoord);\n"
                            "}\n",
                            "TestShader");

    check(contains(result.code, "Channel iChannel0;"));
    check(!contains(result.code, "Channel iChannel1;"));
    check(reports(result, Glsl::DiagnosticKind::UserFunction, "pick"));
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

// Wrapping re-walks the argument nodes rather than the text the call already
// emitted, so it has to reach the same name a second time. Every builtin the
// EDSL spells differently from GLSL is a chance to lose that: a wrapped
// inversesqrt that came back as inversesqrt would not compile, and neither
// would a two-argument atan that came back without its 2.
auto tWrappedCallsKeepTheirName = test("Glsl/wrappedCallsKeepEdslName") = []
{
    auto result = convert(
        "    float v = inversesqrt(fragCoord.x * 8.0 + iTime * 1.25 + 1.0);\n"
        "    float w = atan(fragCoord.y * 8.0 + iTime, fragCoord.x - 4.0);\n"
        "    fragColor = vec4(v, w, 0.0, 1.0);");

    check(result.ok());
    check(contains(result.code, "rsqrt("));
    check(!contains(result.code, "inversesqrt("));
    check(contains(result.code, "atan2("));

    // A matrix constructor regroups its arguments into columns, so it has no
    // name(args...) form to wrap into and stays whole.
    auto matrix = convert("    mat2 m = mat2(cos(iTime) * 1.5, sin(iTime) * 1.5,\n"
                          "                  -sin(iTime) * 1.5, cos(iTime) * 1.5);\n"
                          "    fragColor = vec4(m * fragCoord, 0.0, 1.0);");

    check(matrix.ok());
    check(contains(matrix.code, "float2x2(float2("));
    check(!contains(matrix.code, "mat2("));
};
