// A rotating kaleidoscope over a tiled field, written to exercise everything
// stage 3 added to the EDSL at once: a mat2 rotation built inline, polar
// coordinates through the two-argument atan, mod for the tiling, exp for the
// falloff, inversesqrt and sign in the shaping, and the swizzles - .yx, .zw,
// .bgr - that had no accessor before. It asks for no control flow beyond a
// constant-trip-count loop, so if any of it is missing the report says which.
#define SLICES 6.0

mat2 rotate(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return mat2(c, s, -s, c);
}

vec3 palette(float t)
{
    vec3 warm = vec3(0.85, 0.45, 0.2);
    vec3 cool = vec3(0.1, 0.3, 0.6);
    return mix(cool, warm, clamp(t, 0.0, 1.0));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Fold the plane into SLICES wedges: polar angle, mirrored within a wedge.
    float angle = atan(uv.y, uv.x);
    float radius = length(uv);

    float wedge = 6.2831853 / SLICES;
    float folded = abs(mod(angle + iTime * 0.15, wedge) - wedge * 0.5);

    vec2 cell = vec2(cos(folded), sin(folded)) * radius;

    vec3 col = vec3(0.0);
    float amplitude = 0.6;

    for (int i = 0; i < 3; i++)
    {
        cell = rotate(iTime * 0.2 + float(i)) * cell;

        vec2 tiled = mod(cell * 4.0, 1.0) - 0.5;
        float ring = exp(-8.0 * abs(length(tiled) - 0.25));

        col += palette(ring * sign(cell.x) * 0.5 + 0.5) * ring * amplitude;
        amplitude *= 0.6;
    }

    // A little rim light, and the channel swap the .bgr accessor now spells.
    float rim = inversesqrt(radius + 1.0);
    col = mix(col, col.bgr, 0.35) * rim;

    vec4 shaded = vec4(col, 1.0);
    fragColor = vec4(shaded.zw.yx, shaded.xy).wzyx;
}
