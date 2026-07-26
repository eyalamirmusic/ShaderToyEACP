#include "Common.h"

#include <Lattice.h>

#include <algorithm>

// The integer and boolean vectors are the fourth thing nothing on the CPU can
// observe. A grid counted without the truncation is a ramp rather than a
// lattice, and a box test collapsed with any() instead of all() lights three
// quarters of the frame instead of one - and both of those compile, report
// nothing, and are a perfectly plausible picture.
//
// So each shader below is built so its picture says which happened: a
// checkerboard whose cells only exist because the coordinate truncated, and a
// quarter that is only one quarter because every component of the mask had to
// hold.
//
// Every check here is written as a fraction of the frame rather than as a pixel
// count, because a view renders at the display's backing scale and the image
// read back is in points: a shader dividing fragCoord by a literal has more
// cells on a retina display than on a plain one, and the picture is the same
// picture either way.
//
// Self-skips without a GPU device.

using namespace nano;
using namespace eacp;

namespace
{
// The bottom-left quarter, and nothing else. Both components of the mask have
// to hold, which is exactly what any() would not require: that would light the
// three quarters where either one does.
struct BoxCorner final : Shadertoy::Program
{
    BoxCorner() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto inside = fragCoord < iResolution.xy() * 0.5f;
        auto lit = select(all(inside), 1.0f, 0.0f);

        return float4(lit, lit, lit, 1.0f);
    }
};

// Four cells across and two up, counted in integers and coloured by the parity
// of the pair. The truncation is what makes this a checkerboard: the same
// expression over floats is a ramp with no cells in it at all.
struct GridParity final : Shadertoy::Program
{
    GridParity() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto uv = fragCoord / iResolution.xy();
        auto cell = toInt(float2(uv.x() * 4.0f, uv.y() * 2.0f));
        auto shade = toFloat((cell.x() + cell.y()) & 1);

        return float4(shade, shade, shade, 1.0f);
    }
};

Graphics::Image render(Shadertoy::Program& program, float size)
{
    auto view = Shadertoy::ShaderView {program};
    view.setBounds({0.0f, 0.0f, size, size});

    return view.renderToImage(1.0f);
}

// The red channel a fraction of the way across and up the frame the shader
// drew, whose origin is at the bottom left where fragCoord's is - the image read
// back has its own at the top.
float shadeAt(const Graphics::Image& image, float across, float up)
{
    auto x = (int) (across * (float) image.width());
    auto y = image.height() - 1 - (int) (up * (float) image.height());

    return image.at(x, y).r;
}

// The extremes over a rectangle of it, given the same way.
struct Range
{
    float darkest = 1.0f;
    float brightest = 0.0f;
};

Range rangeOver(const Graphics::Image& image,
                float fromAcross,
                float toAcross,
                float fromUp,
                float toUp)
{
    constexpr auto steps = 32;

    auto at = [](float from, float to, int step)
    { return from + (to - from) * (float) step / (float) steps; };

    auto range = Range {};

    for (auto x = 0; x < steps; ++x)
        for (auto y = 0; y < steps; ++y)
        {
            auto shade =
                shadeAt(image, at(fromAcross, toAcross, x), at(fromUp, toUp, y));

            range.darkest = std::min(range.darkest, shade);
            range.brightest = std::max(range.brightest, shade);
        }

    return range;
}
} // namespace

// One quarter lit, three dark. Under any() the three would be lit and the count
// would be the other way round, which is the whole reason both collapses exist.
auto tMaskCollapsesWithAll = test("Vector/allRequiresEveryComponent") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = BoxCorner {};
    auto image = render(shader, 16.0f);

    check(image.isValid());
    check(shadeAt(image, 0.2f, 0.2f) > 0.5f);

    // The two quarters where exactly one component holds, which is what
    // separates all() from any(), and the one where neither does.
    check(shadeAt(image, 0.8f, 0.2f) < 0.5f);
    check(shadeAt(image, 0.2f, 0.8f) < 0.5f);
    check(shadeAt(image, 0.8f, 0.8f) < 0.5f);
};

// The lattice: neighbouring cells differ, cells a step apart on both axes agree,
// and each one is flat. A coordinate that never truncated would give none of the
// three.
auto tIntegerCellsTruncate = test("Vector/integerCellsMakeAGrid") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = GridParity {};
    auto image = render(shader, 16.0f);

    check(image.isValid());

    check(shadeAt(image, 0.1f, 0.2f) < 0.5f); // cell (0, 0)
    check(shadeAt(image, 0.4f, 0.2f) > 0.5f); // cell (1, 0)
    check(shadeAt(image, 0.1f, 0.8f) > 0.5f); // cell (0, 1)
    check(shadeAt(image, 0.4f, 0.8f) < 0.5f); // cell (1, 1)

    // And one cell is one colour all the way across, which is what says the
    // shade came from the cell rather than from the coordinate.
    check(rangeOver(image, 0.28f, 0.47f, 0.05f, 0.45f).darkest > 0.5f);
};

// The same two things over a port nobody wrote: Lattice.glsl through the
// transpiler, where the ivec2, the componentwise lessThan and the all() are all
// generated rather than typed. Sixteen-pixel cells, and a lit box covering three
// quarters of each axis.
auto tGeneratedPortCountsAndCompares = test("Vector/generatedPortCounts") = []
{
    if (!GPU::Device::shared().isValid())
        return;

    auto shader = Shadertoy::Ports::Lattice {};
    auto image = render(shader, 32.0f);

    check(image.isValid());

    // Inside the box: the even cells are black and the odd ones are lit, which
    // is the integer half - the cells exist at all only because the coordinate
    // truncated into them.
    auto inside = rangeOver(image, 0.02f, 0.72f, 0.02f, 0.72f);

    check(inside.darkest < 0.1f);
    check(inside.brightest > 0.4f);

    // Outside it on each axis separately: the same cells, dimmed. Each of these
    // bands still has one component of the mask inside the box, so collapsing it
    // with any() would leave them as bright as the region above.
    auto pastAcross = rangeOver(image, 0.78f, 0.98f, 0.02f, 0.72f);
    auto pastUp = rangeOver(image, 0.02f, 0.72f, 0.78f, 0.98f);

    check(pastAcross.brightest < inside.brightest * 0.5f);
    check(pastUp.brightest < inside.brightest * 0.5f);

    // And dimmed rather than extinguished, so this is reading the lighting and
    // not an empty corner of the frame.
    check(pastAcross.brightest > 0.05f);
    check(pastUp.brightest > 0.05f);
};
