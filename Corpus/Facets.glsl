// The rest of the aggregate, which Surface.glsl does not reach: a struct with a
// struct inside it, one passed to a helper as well as handed back from one, and
// a ternary choosing between two whole values of it.
//
// It is also built so a rendered frame says whether the scalarisation kept the
// fields apart. The two candidates differ in every field at once - distance,
// colour and shine - and which of them wins flips at the middle of the frame, so
// a leaf read out of the wrong slot, a field that never escaped the helper, or a
// choice made once for the whole struct instead of per field all come out as a
// different picture rather than as nothing.
struct Material
{
    vec3 albedo;
    float shine;
};

struct Hit
{
    float distance;
    Material material;
};

Hit closer(Hit a, Hit b)
{
    return a.distance < b.distance ? a : b;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    Hit left = Hit(uv.x, Material(vec3(1.0, 0.0, 0.0), 1.0));
    Hit right = Hit(1.0 - uv.x, Material(vec3(0.0, 1.0, 0.0), 0.5));

    Hit best = closer(left, right);

    fragColor = vec4(best.material.albedo * best.material.shine, 1.0);
}
