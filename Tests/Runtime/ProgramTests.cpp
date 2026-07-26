#include "Common.h"

using namespace nano;
using namespace eacp;

namespace
{
// The smallest thing a port can be: a body over fragCoord and the standard
// uniforms, with compile() run from the most-derived constructor.
struct UvShader final : Shadertoy::Program
{
    UvShader() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();
        return float4(uv, 0.5f + 0.5f * sin(iTime), 1.0f);
    }
};

// A port that needs a uniform Shadertoy does not supply, declared as a member
// and listed with SHADERTOY_UNIFORMS.
struct TintedShader final : Shadertoy::Program
{
    GPU::Uniform<GPU::Float3> tint;

    SHADERTOY_UNIFORMS(tint)

    TintedShader() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();
        return float4(tint * uv.x(), 1.0f);
    }
};

bool contains(const std::string& haystack, std::string_view needle)
{
    return haystack.find(needle) != std::string::npos;
}
} // namespace

// The base pulls both attributes out of FullscreenVertex, so the layout it
// publishes is the one the covering triangle is actually uploaded with. If these
// drift, every port draws garbage geometry - which is why it is asserted here
// rather than left to a demo looking right.
auto tFullscreenLayout = test("Runtime/fullscreenVertexLayout") = []
{
    auto shader = UvShader {};
    const auto& layout = shader.vertexLayout();

    check(layout.attributes.size() == 2);
    check(layout.attributes[0].format == GPU::VertexFormat::Float2);
    check(layout.attributes[0].offset == 0);
    check(layout.attributes[1].format == GPU::VertexFormat::Float2);
    check(layout.attributes[1].offset == (int) (sizeof(float) * 2));
    check(layout.stride == (int) sizeof(Shadertoy::FullscreenVertex));
};

// The uniform block follows MSL struct rules, and the offsets the CPU packs to
// are derived from the same helpers the emitters spell the struct with. Pinning
// the total size pins the whole set: a member added, reordered or retyped moves
// it. iResolution takes a full 16-byte slot as a float3, the three floats pack
// into the next 16, and iMouse starts a third.
auto tUniformBlockSize = test("Runtime/uniformBlockLayout") = []
{
    auto shader = UvShader {};

    check(shader.hasUniforms());
    check(shader.uniformByteSize() == 48);

    // An extra uniform lands after the Shadertoy set rather than among it, so
    // adding one cannot shift what the standard members pack to.
    auto tinted = TintedShader {};
    check(tinted.uniformByteSize() == 64);
};

// Both stages are generated, and the fragment stage is where the ported body
// lands: it reads the uniform block (mainImage scales uv by iResolution) while
// the vertex stage only passes the triangle through.
auto tGeneratedStages = test("Runtime/generatedStages") = []
{
    auto shader = UvShader {};
    const auto& source = shader.source();

    check(!source.source.empty());
    check(source.vertexEntry == "vertexMain");
    check(source.fragmentEntry == "fragmentMain");
    check(!source.isCompute());

    check(contains(source.source, source.vertexEntry));
    check(contains(source.source, source.fragmentEntry));
    check(contains(source.source, "Uniforms"));
};
