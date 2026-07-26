// A checkerboard with a swept highlight. Reachable except for mod, which the
// EDSL has no spelling for, and the .yx swizzle, which has no accessor - two
// small gaps rather than a structural one, and between them exactly the kind of
// shader that stage 3 turns green.
#define SQUARES 12.0

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;
    vec2 cell = floor(uv * SQUARES);

    float checker = mod(cell.x + cell.y, 2.0);
    vec3 col = mix(vec3(0.12), vec3(0.88), checker);

    vec2 swept = uv.yx;
    col *= 0.7 + 0.3 * sin(swept.x * 6.0 + iTime);

    fragColor = vec4(col, 1.0);
}
