// A sphere raymarch: the shape of shader stage 1 cannot reach at all. The march
// is a loop with a data-dependent break, and the scene is a helper function, so
// this one needs both the inlining of stage 2 and the real control flow of
// stage 5 before it converts.
float sdSphere(vec3 p, float r)
{
    return length(p) - r;
}

float march(vec3 origin, vec3 direction)
{
    float travelled = 0.0;

    for (int i = 0; i < 64; i++)
    {
        vec3 position = origin + direction * travelled;
        float distance = sdSphere(position, 1.0);

        if (distance < 0.001)
            break;

        travelled += distance;
    }

    return travelled;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    vec3 origin = vec3(0.0, 0.0, -3.0);
    vec3 direction = normalize(vec3(uv, 1.0));

    float hit = march(origin, direction);
    vec3 col = vec3(exp(-hit * 0.3));

    fragColor = vec4(col, 1.0);
}
