// Stage 9: the two matrix operations both shading languages have.
//
// A matrix could be built and multiplied and that was all, which is enough for
// an inline 2D rotation and not enough for a shader that carries an orientation
// around. `transpose` is what inverts one of those - an orthonormal basis is
// transposed rather than inverted, which is why a shader wanting to go the
// other way through a frame asks for exactly this.
//
// `inverse` is the one that stays a gap, and it is a gap in the languages
// rather than in the EDSL: GLSL has it, MSL and HLSL do not.

mat3 basis(vec3 forward)
{
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);

    return mat3(right, up, forward);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y;

    float angle = iTime * 0.3;
    mat2 spin = mat2(cos(angle), sin(angle), -sin(angle), cos(angle));

    vec3 forward = normalize(vec3(sin(angle) * 0.4, 0.2, 1.0));
    mat3 frame = basis(forward);

    // Into the frame with the matrix and back out of it with its transpose,
    // which for an orthonormal basis is the inverse the languages have no
    // spelling for.
    vec3 ray = frame * normalize(vec3(spin * uv, 1.0));
    vec3 back = transpose(frame) * ray;

    // The determinant of an orthonormal basis is one, so this scales nothing
    // and is here because it is the other operation both languages have.
    float unit = determinant(frame);

    vec3 col = 0.5 + 0.5 * cos(vec3(back.z, back.x, back.y) * 6.0 + iTime);

    fragColor = vec4(col * unit, 1.0);
}
