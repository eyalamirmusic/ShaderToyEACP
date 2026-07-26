// Stage 11: a literal wherever the shader writes one, and the products a
// matrix has.
//
// Every intrinsic below mixes literals and values in one call - one edge of a
// smoothstep computed and the other written down, the literal first in a min
// and second in a step, two constants mixed by something the pixel worked out,
// a literal base under a power. All of it is legal GLSL and all of it has a
// spelling in both languages under the EDSL, so none of it is a capability:
// it is which argument positions eacp had a form for, which was the largest
// single row the coverage table has ever had.
//
// Beside it, the two products GLSL reads differently. A vector on the left of a
// matrix goes through its rows and one on the right through its columns, so the
// two turn opposite ways - and the frame says which happened rather than merely
// compiling either way: red carries what the row-wise product left and green
// what the column-wise one did, and on the +x axis the two have opposite signs.

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    mat2 turn = mat2(0.8, 0.6, -0.6, 0.8);

    vec2 rowWise = uv * turn;
    vec2 columnWise = turn * uv;

    // A matrix scaled by a scalar, which is neither of those: it multiplies
    // every element, so halving one halves what it does to whatever goes
    // through it.
    mat2 halved = turn * 0.5;
    float shrunk = length(halved * uv);

    float d = length(uv);

    float edge = smoothstep(0.0, 0.15 + 0.2 * shrunk, d);
    float lowest = min(0.25, d);
    float gate = step(d, 0.9);
    float blend = mix(0.2, 0.8, edge);
    float curve = pow(2.0, -3.0 * d);
    float held = clamp(blend * curve, 0.0, max(-1.0, 0.8));

    // And the crossing GLSL spells with a constructor rather than with a
    // choice: int(a > b) is 1 or 0, and both languages under the EDSL cast a
    // bool the same way.
    float side = float(int(uv.x > 0.0));

    fragColor = vec4(0.5 + 0.5 * rowWise.y,
                     0.5 + 0.5 * columnWise.y,
                     held * gate + 0.1 * side + 0.2 * lowest,
                     1.0);
}
