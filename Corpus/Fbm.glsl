// Value noise summed over four octaves: two helper functions and a
// constant-trip-count loop, which is the shape a very large slice of Shadertoy
// has and the one stage 2 was built for. Nothing here asks the EDSL for
// anything the loop and the inlined helpers do not already give it.
float hash(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p)
{
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(cell);
    float b = hash(cell + vec2(1.0, 0.0));
    float c = hash(cell + vec2(0.0, 1.0));
    float d = hash(cell + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    vec2 p = uv * 4.0;
    float total = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < 4; i++)
    {
        total += amplitude * noise(p + iTime * 0.1);
        p *= 2.0;
        amplitude *= 0.5;
    }

    vec3 col = mix(vec3(0.05, 0.08, 0.15), vec3(0.9, 0.75, 0.5), total);
    fragColor = vec4(col, 1.0);
}
