// The last of the type row. A shader that marches a scene wants to carry more
// than one thing back from a hit - how far away it was and what it was made of
// - and GLSL gives it a struct to do that with. Every value the EDSL names is
// one node, so a pair of them has nowhere to live: no aggregate type, no
// constructor for one, and no way to read a field back out.
struct Hit
{
    float distance;
    vec3 albedo;
};

Hit scene(vec3 p)
{
    return Hit(length(p) - 1.0, vec3(0.9, 0.4, 0.2));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y;

    vec3 origin = vec3(0.0, 0.0, -3.0);
    vec3 direction = normalize(vec3(uv, 1.0));

    float travelled = 0.0;
    Hit hit = scene(origin);

    while (travelled < 8.0)
    {
        hit = scene(origin + direction * travelled);

        if (hit.distance < 0.001)
            break;

        travelled += hit.distance;
    }

    float shade = 1.0 - travelled / 8.0;

    fragColor = vec4(hit.albedo * shade, 1.0);
}
