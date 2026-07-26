// The wall after control flow. Shadertoy reaches for an array wherever a
// palette, a set of light positions or a small lookup table would otherwise be
// spelled out, and the EDSL has no array type - so the subscript has nothing to
// subscript. The integer index and the mask that keeps it in range are the same
// gap from the other side: after unrolling there is usually no integer left,
// and here there is.
const vec3 palette[4] = vec3[4](vec3(0.1, 0.1, 0.2),
                                vec3(0.9, 0.4, 0.2),
                                vec3(0.2, 0.8, 0.6),
                                vec3(1.0, 0.9, 0.7));

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    int index = int(uv.x * 4.0) & 3;
    vec3 col = palette[index] * (0.5 + 0.5 * sin(iTime));

    fragColor = vec4(col, 1.0);
}
