// The three ways a Shadertoy reads a texture channel, in one pass. texture()
// takes the filtered, wrapping sample the page gives a channel by default;
// textureLod() names the level itself, which is what a shader does where the
// coordinate jumps between neighbouring fragments and the level the derivatives
// imply is meaningless; and texelFetch() addresses texels rather than the unit
// square and goes past the sampler entirely, which is what iChannelResolution
// is there to make possible.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // A drifting warp, so that the wrapping a channel is sampled with shows.
    vec2 warped =
        uv + 0.03 * vec2(sin(uv.y * 12.0 + iTime), cos(uv.x * 9.0 - iTime * 0.7));

    vec3 base = texture(iChannel0, warped).rgb;

    // Four taps up the diagonal, each explicit about the level it reads.
    vec3 blur = vec3(0.0);

    for (int i = 0; i < 4; i++)
    {
        float offset = float(i) * 0.004;
        blur += textureLod(iChannel1, warped + vec2(offset, -offset), 0.0).rgb;
    }

    blur *= 0.25;

    // One texel, addressed in texels and read without the sampler, so it is the
    // stored colour rather than a blend of it with its neighbours.
    vec2 texel = iChannelResolution[0].xy * uv;
    vec3 exact = texelFetch(iChannel0, ivec2(texel), 0).rgb;

    vec3 col = mix(base, blur, 0.4) + exact * 0.15;

    fragColor = vec4(col, 1.0);
}
