// Stage 9: a colour built one component at a time.
//
// GLSL lets a shader write part of a value; neither shading language under the
// EDSL does, and neither does the EDSL. So each write here is the whole value
// rebuilt from what the write names and what it leaves alone - which is what a
// shader would have had to spell out if GLSL had not offered the shorthand.
//
// The frame says whether it was rebuilt correctly. Every component lands in a
// channel of its own and they are ordered r > g > b wherever the shader is lit,
// so a component written into the wrong slot, or a target read back after the
// write rather than before it, comes out as a different ordering rather than as
// a compile error.

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // Two of three at once, and out of order: green takes the first component
    // of the pair and red the second.
    vec3 col = vec3(0.0);
    col.gr = vec2(0.02, 0.85);

    // One on its own, and a compound one that has to read what is there.
    col.b = 0.1;
    col.r += 0.05 * step(0.5, uv.x);

    // A loop accumulating into one component, as many times as the pixel's own
    // column says - so green comes out a staircase of four steps across the
    // frame. It is a staircase only if reading the variable inside its own
    // assignment sees what the iteration before left there: a read taken once
    // outside the loop makes every column the same, and one taken after the
    // write makes each column the wrong height.
    float steps = 0.0;
    float bands = floor(uv.x * 4.0) + 1.0;

    while (steps < bands)
    {
        col.g += 0.12;
        steps += 1.0;
    }

    // And the out parameter filled a piece at a time, with no whole value ever
    // assigned to it.
    fragColor.rgb = col;
    fragColor.a = 1.0;
}
