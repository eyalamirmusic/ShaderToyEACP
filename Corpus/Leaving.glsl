// Stage 14: the three shapes a body leaves early in.
//
// A ported body is one expression returned after the last statement runs, so a
// `return` anywhere else was the largest gap the corpus named - 71 of the 204
// shaders measured, most of them in a helper of two lines. Nothing about it is
// a gap in the EDSL, which has the branch, the loop, the `break` and the
// mutable variable all three of these become; what it needed was a body
// rewritten before it is flattened.
//
// Nothing on the CPU can tell whether the rewrite kept the meaning. All three
// convert, all three compile, and a body that ran the code it was supposed to
// skip differs from one that did not only in the pixels - so each shape here
// puts its answer in a channel of its own and the frame is what says it.
//
// Red is a guard clause: the value the body leaves with, chosen by a branch
// that leaves before the rest of it. Green is a return out of a loop, with the
// fallback underneath that the loop falls through to when it never fires -
// both halves matter, since a rewrite that always took one of them would still
// draw something. Blue is mainImage's own: a return that is not the last thing
// it does, after which nothing else may write the colour.

// The guard clause, which is the common one: the shape a helper takes when the
// interesting case is the one that does not happen.
float clipped(float x)
{
    if (x < 0.5)
        return 0.0;

    return x;
}

// The one that needs the flag: what runs after the loop cannot be a branch
// away from what left it, so something has to say the loop was left.
float reached(float x)
{
    for (int i = 0; i < 16; i++)
        if (float(i) * 0.0625 > x)
            return float(i) / 16.0;

    return 1.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    if (uv.x < 0.25)
    {
        fragColor = vec4(0.0, 0.0, 1.0, 1.0);
        return;
    }

    fragColor = vec4(clipped(uv.x), reached(uv.x), 0.0, 1.0);
}
