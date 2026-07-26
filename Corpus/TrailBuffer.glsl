// Buffer A of a two-pass Shadertoy: the shape a buffer exists for, which is the
// one that reads itself. iChannel0 is this same buffer, so what it samples is
// what it left there last frame, and every frame adds a little more.
//
// It adds more than eight bits can hold on purpose. After a handful of frames
// the right-hand side is past 1, which is exactly the point an 8-bit target
// stops being able to say anything - the accumulation flattens and the buffer
// can never leave the colour it saturated at.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    vec3 previous = texture(iChannel0, uv).rgb;
    vec3 added = vec3(0.25 + uv.x * 0.5);

    fragColor = vec4(previous + added, 1.0);
}
