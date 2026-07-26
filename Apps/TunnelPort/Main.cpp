#include <Tunnel.h>

#include <shadertoy/Runtime/ChannelImages.h>

using namespace eacp;
using namespace Shadertoy;

// A textured Shadertoy, converted from Tunnel.glsl at build time: polar
// coordinates into a channel, which is the shape most of the corpus's textured
// shaders have. The port is the body of mainImage, as ever; the one thing the
// app supplies on top of it is the image that channel reads - generated rather
// than shipped, since Shadertoy's own textures are not ours to redistribute.
namespace
{
struct MyApp
{
    MyApp()
    {
        // Assigning the texture also publishes its size as the channel's
        // iChannelResolution, which is what a shader fetching texels reads.
        shader.iChannel0 = bricks;

        window.setContentView(view);
        window.setTitle("Tunnel (transpiled)");
    }

    // The program holds a pointer to the bound texture, so the texture is
    // declared first and outlives every draw that reads it.
    GPU::Texture bricks = ChannelImages::bricks();
    Ports::Tunnel shader;
    ShaderView view {shader};
    Graphics::Window window;
};
} // namespace

int main()
{
    return Apps::run<MyApp>();
}
