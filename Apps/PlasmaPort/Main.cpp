#include <Plasma.h>

using namespace eacp;

// The same plasma as Apps/Plasma, except that no C++ was written for it: the
// struct this runs comes from Plasma.glsl through the transpiler, generated
// into the build tree by shadertoy_add_port.
namespace
{
struct MyApp
{
    MyApp()
    {
        window.setContentView(view);
        window.setTitle("Plasma (transpiled)");
    }

    Shadertoy::Ports::Plasma shader;
    Shadertoy::ShaderView view {shader};
    Graphics::Window window;
};
} // namespace

int main()
{
    return Apps::run<MyApp>();
}
