// Stage 11: what a shader writes before it has written anything.
//
// A local declared without an initialiser is undefined in GLSL and has to be
// something here, because a name can be read before it is ever assigned: a
// write to part of a value rebuilds the whole of it out of the components it
// is not writing, and reads every one of them. Deferring the declaration to the
// assignment that follows was the alternative, and it produced C++ that named
// the value in its own initialiser.
//
// Three more things a real shader does that a port has to spell differently sit
// beside it. A scalar written into two components at once, which GLSL
// broadcasts across both - and the frame is what says it reached both, since
// red and green carry one component each and are equal only if it did. An
// equality between two whole vectors, which GLSL answers with one bool and both
// languages under the EDSL answer with a mask, so what says what the shader
// said is that mask collapsed. And a local called `cos`, which is an ordinary
// name in GLSL - its builtins are not names in a scope - and is the name of the
// very thing the next line here calls.

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // Declared and not initialised. The first thing that happens to it is a
    // write to one component, so the other three still hold whatever a
    // declaration with no value left there.
    vec4 q;
    q.x = uv.x;

    // A scalar into two components at once, which GLSL broadcasts across both.
    vec2 p = vec2(0.0);
    p.xy += 0.2 + 0.4 * uv.y;

    float cos = cos(uv.x * 3.0);

    bool inTheCorner = (floor(uv * 2.0) == vec2(0.0, 0.0));

    fragColor = vec4(p.x + q.y,
                     p.y + q.z,
                     0.1 + 0.4 * float(inTheCorner) + 0.2 * cos + q.w,
                     1.0);
}
