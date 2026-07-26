// The wall on the far side of the integer. Closing `int`, the array and the
// subscript left the vector half of the same row open: a shader working on a
// grid counts its cell in ivec2, and a shader testing a point against a box
// compares two vectors componentwise and collapses the bool vector that yields.
// Neither has a type in the EDSL to land in - and there is no any()/all()
// either, which is the only thing that would make one useful if there were.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 cell = ivec2(fragCoord / 16.0);
    float checker = fract(float(cell.x + cell.y) * 0.5);

    bvec2 inside = lessThan(fragCoord, iResolution.xy * 0.75);
    float lit = all(inside) ? 1.0 : 0.25;

    fragColor = vec4(vec3(checker * lit), 1.0);
}
