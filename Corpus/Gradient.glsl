// The floor of the corpus: straight-line arithmetic over the standard uniforms,
// nothing else. If this ever stops converting, something basic has broken.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    vec3 top = vec3(0.15, 0.18, 0.35);
    vec3 bottom = vec3(0.85, 0.45, 0.25);

    vec3 col = mix(bottom, top, uv.y);
    col += 0.05 * sin(uv.x * 40.0 + iTime * 2.0);

    fragColor = vec4(col, 1.0);
}
