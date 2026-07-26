// Polar coordinates and a sampled channel: the two gaps that have nothing to do
// with control flow. atan is missing from the EDSL's intrinsic set, and texture
// channels are not wired up at all yet.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float angle = atan(uv.y, uv.x);
    float radius = length(uv);

    vec2 polar = vec2(angle / 6.2831853 + 0.5, 0.3 / radius + iTime * 0.2);

    vec3 col = texture(iChannel0, polar).rgb;
    col *= smoothstep(0.0, 0.6, radius);

    fragColor = vec4(col, 1.0);
}
