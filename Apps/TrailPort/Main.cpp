#include <TrailBuffer.h>
#include <TrailImage.h>

using namespace eacp;

// The shape stage 8 was built for: a Shadertoy with a buffer, from two .glsl
// files rather than one. Buffer A reads itself, so what it shows is what it has
// been accumulating since the window opened - which is the whole class of
// shaders a single pass cannot express at all, however much of the language it
// has.
//
// The wiring below is all a multi-buffer page amounts to once the runtime has
// the passes: point each channel at what it reads, and say which pass runs
// before the image. The trail here saturates the screen quickly, since it only
// ever adds - a real one subtracts as well, which is what makes it a trail.
namespace
{
struct MyApp
{
    MyApp()
    {
        bufferShader.iChannel0 = buffer;
        imageShader.iChannel0 = buffer;

        view.addBuffer(buffer);

        window.setContentView(view);
        window.setTitle("Trail (transpiled, two passes)");
    }

    Shadertoy::Ports::TrailBuffer bufferShader;
    Shadertoy::Ports::TrailImage imageShader;

    Shadertoy::Buffer buffer {bufferShader};
    Shadertoy::ShaderView view {imageShader};

    Graphics::Window window;
};
} // namespace

int main()
{
    return Apps::run<MyApp>();
}
