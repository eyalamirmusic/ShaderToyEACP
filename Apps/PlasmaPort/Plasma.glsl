// The sum-of-sines plasma, as it would be written on Shadertoy. Apps/Plasma is
// the same shader ported by hand; this one is converted at build time, so the
// two windows side by side are the transpiler's own regression test.
#define WAVES 8.0

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float v = sin(uv.x * WAVES + iTime)
            + sin(uv.y * WAVES + iTime * 1.3)
            + sin((uv.x + uv.y) * 6.0 + iTime * 0.7)
            + sin(length(uv) * 12.0 - iTime * 1.7);

    vec3 col = 0.5 + 0.5 * cos(vec3(v, v + 2.1, v + 4.2));

    vec2 mouse = (iMouse.xy - 0.5 * iResolution.xy) / iResolution.y;
    float glow = 1.0 - smoothstep(0.0, 0.35, length(uv - mouse));
    col += glow * step(0.0, iMouse.z) * vec3(0.6, 0.35, 0.1);

    fragColor = vec4(col, 1.0);
}
