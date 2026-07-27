// The escape-time loop stage 5 exists for: how many steps a pixel takes is a
// property of the pixel, so nothing decided on paper reaches this however small
// the bound is. Around it, the rest of what statements buy - a bool the loop sets and the
// shading reads, a colour written by both sides of an if/else and read after
// it, a ternary, and two comparisons joined by a connective.
vec2 square(vec2 z)
{
    return vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 c = uv * 2.0 - vec2(0.5, 0.0);

    vec2 z = vec2(0.0);
    float steps = 0.0;
    bool escaped = false;

    while (steps < 96.0)
    {
        z = square(z) + c;
        steps += 1.0;

        if (dot(z, z) > 4.0)
        {
            escaped = true;
            break;
        }
    }

    float shade = steps / 96.0;
    vec3 col;

    if (escaped)
        col = vec3(shade, shade * shade, sqrt(shade));
    else
        col = vec3(0.02, 0.0, 0.06);

    float glow = shade > 0.25 && shade < 0.9 ? 0.3 : 0.0;
    col += glow * vec3(0.4, 0.2, 0.0);

    fragColor = vec4(col, 1.0);
}
