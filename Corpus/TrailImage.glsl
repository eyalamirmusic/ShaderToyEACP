// The image pass of the same two-pass Shadertoy: it reads Buffer A and shows it,
// scaled down far enough that what the buffer accumulated stays inside the range
// a screen can show.
//
// The scale is what turns the buffer's range into something a frame says out
// loud: at a tenth, a buffer that saturated at 1 can never come back brighter
// than 0.1 however many frames it ran, and one that kept counting does.
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    fragColor = vec4(texture(iChannel0, uv).rgb * 0.1, 1.0);
}
