// The nearest of nine feature points, over a rotated grid. Two things here that
// Fbm.glsl does not have: loops nested inside each other, so the inner one
// unrolls once per copy of the outer, and a helper that writes through an inout
// parameter rather than returning.
const float SCALE = 6.0;

void rotate(inout vec2 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

vec2 featurePoint(vec2 cell)
{
    float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(cell, vec2(269.5, 183.3))) * 43758.5453);
    return cell + vec2(a, b);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    rotate(uv, iTime * 0.15);

    vec2 point = uv * SCALE;
    vec2 cell = floor(point);
    float closest = 8.0;

    for (int y = -1; y <= 1; y++)
    {
        for (int x = -1; x <= 1; x++)
        {
            vec2 neighbour = featurePoint(cell + vec2(float(x), float(y)));
            closest = min(closest, length(neighbour - point));
        }
    }

    vec3 col = mix(vec3(0.9, 0.95, 1.0), vec3(0.1, 0.15, 0.3), closest);
    col *= 0.6 + 0.4 * smoothstep(0.0, 0.2, closest);

    fragColor = vec4(col, 1.0);
}
