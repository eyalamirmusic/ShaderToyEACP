#include <Raymarch.h>

using namespace eacp;

// The shader stage 5 was built for, running: a sphere marched with a loop whose
// length is a property of the pixel, from Corpus/Raymarch.glsl through the
// transpiler. The march stops when it arrives, so before the EDSL had
// statements there was no port of this to run at all.
namespace
{
struct MyApp
{
    MyApp()
    {
        window.setContentView(view);
        window.setTitle("Raymarch (transpiled)");
    }

    Shadertoy::Ports::Raymarch shader;
    Shadertoy::ShaderView view {shader};
    Graphics::Window window;
};
} // namespace

int main()
{
    return Apps::run<MyApp>();
}
