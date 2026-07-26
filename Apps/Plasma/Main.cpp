#include <shadertoy/Shadertoy.h>

using namespace eacp;

// A hand port of the classic sum-of-sines plasma, written in the shape the
// transpiler is being built to emit: the body of mainImage and nothing else.
// The GLSL it stands in for is:
//
//   void mainImage(out vec4 fragColor, in vec2 fragCoord)
//   {
//       vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
//
//       float v = sin(uv.x * 8.0 + iTime)
//               + sin(uv.y * 8.0 + iTime * 1.3)
//               + sin((uv.x + uv.y) * 6.0 + iTime * 0.7)
//               + sin(length(uv) * 12.0 - iTime * 1.7);
//
//       vec3 col = 0.5 + 0.5 * cos(vec3(v, v + 2.1, v + 4.2));
//
//       vec2 mouse = (iMouse.xy - 0.5 * iResolution.xy) / iResolution.y;
//       float glow = 1.0 - smoothstep(0.0, 0.35, length(uv - mouse));
//       col += glow * step(0.0, iMouse.z) * vec3(0.6, 0.35, 0.1);
//
//       fragColor = vec4(col, 1.0);
//   }
//
// Every construct in it is reachable with today's EDSL - it is straight-line
// code over intrinsics that already exist. That is exactly the class of shader
// stage 1 of the transpiler targets, and why this one was picked to prove the
// runtime.
namespace
{
struct PlasmaShader final : Shadertoy::Program
{
    PlasmaShader() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto resolution = iResolution.xy();
        auto uv = (fragCoord - resolution * 0.5f) / resolution.y();

        auto waves = sin(uv.x() * 8.0f + iTime) + sin(uv.y() * 8.0f + iTime * 1.3f)
                     + sin((uv.x() + uv.y()) * 6.0f + iTime * 0.7f)
                     + sin(length(uv) * 12.0f - iTime * 1.7f);

        auto color = 0.5f + 0.5f * cos(float3(waves, waves + 2.1f, waves + 4.2f));

        // The pointer lights the surface where it is held down. iMouse.z is
        // negative until the first click and while the button is up, so the
        // step() gate reads zero then.
        auto mouse = (iMouse.xy() - resolution * 0.5f) / resolution.y();
        auto falloff = 1.0f - smoothstep(0.0f, 0.35f, length(uv - mouse));
        auto glow = falloff * step(0.0f, iMouse.z());

        auto lit = color + float3(glow * 0.6f, glow * 0.35f, glow * 0.1f);

        return float4(lit, 1.0f);
    }
};

struct MyApp
{
    MyApp()
    {
        window.setContentView(view);
        window.setTitle("Plasma");
    }

    PlasmaShader shader;
    Shadertoy::ShaderView view {shader};
    Graphics::Window window;
};
} // namespace

int main()
{
    return Apps::run<MyApp>();
}
