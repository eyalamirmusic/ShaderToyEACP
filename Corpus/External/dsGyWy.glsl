// dsGyWy - Zavie
// https://www.shadertoy.com/view/dsGyWy
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc-by-4.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

/*

This shader visualises the relative solid angle of the texels
of the face of a cubemap (compared to the center texel).

A very simple approximation is proposed. The approximation is
too crude for very low resolutions, but beyond 8x8 it seems
to result in under 1% error.

Maybe a fitting or offset could correct the error for the
very low resolutions as well?


Top center: texels of the cubemap face.
Bottom left: relative solid angle of the texels.
Bottom right: approximation of the relative solid angle.
Center: (200x exaggerated) error of the approximation.

The bottom histogram shows the error accross the diagonal, on
a squeezed scale. The short dashed graduations indicate the
0.125%, 0.25%, 0.5%, 1% and 2% error. The longer dashed
graduations indicate the 10%, 20%, 40% and 80% error.

License: CC BY 4.0

-- 
Zavie
*/

float approximateRelativeSolidAngle(vec2 uv, float resolution)
{
    vec2 p = uv * 2. - 1.;

#if 0
    // Verbose version:

    // The more off-center the texel, the further the distance.
    // So we scale by the inverse square distance.
    float invSqrDist = 1. / (dot(p, p) + 1.);

    // The more off-center the texel, the more it's facing away.
    // So we scale by the cosine.
    float cos_factor = 1. / sqrt(dot(p, p) + 1.);

    // Combine the two factors:
    return invSqrDist * cos_factor;
#else
    // Short version:

    // After derivation, the whole thing becomes just
    float sqrDist = dot(p, p) + 1.;
    return 1. / sqrt(sqrDist * sqrDist * sqrDist);
#endif
}

//
// areaElement and texelSolidAngle are adapted from
// AMD cubemapgen source code:
// https://code.google.com/archive/p/cubemapgen/
//
// See the derivation here:
// https://www.rorydriscoll.com/2012/01/15/cubemap-texel-solid-angle/
//
float areaElement(float x, float y)
{
    return atan(x * y, sqrt(x * x + y * y + 1.));
}

float texelSolidAngle(vec2 uv, float resolution)
{
    vec2 p = uv * 2. - 1.;

    float invResolution = 1. / resolution;
 
    // p is the -1..1 texture coordinate on the current face.
    // Get projected area for this texel
    vec2 pmin = p - invResolution;
    vec2 pmax = p + invResolution;
    float solidAngle = (
        areaElement(pmin.x, pmin.y) -
        areaElement(pmin.x, pmax.y) -
        areaElement(pmax.x, pmin.y) +
        areaElement(pmax.x, pmax.y));
 
    return solidAngle;
}

float exactRelativeSolidAngle(vec2 uv, float resolution)
{
    return texelSolidAngle(uv, resolution) / texelSolidAngle(vec2(0.5), resolution);
}

// ----------------------------------------------------------

vec2 remap(vec2 a, vec2 b, vec2 u)
{
    return (u - a) / (b - a);
}

vec2 getMask(vec2 uv)
{
    vec2 du = 2.*vec2(dFdx(uv.x), dFdy(uv.y));
    return smoothstep(vec2(0.), du, uv) * (1. - smoothstep(vec2(1.) - du, vec2(1.), uv));
}

vec2 getRectangle(vec2 uv, float x, float y, float width, float height)
{
    vec2 p = vec2(x, y);
    vec2 size = vec2(width, height);
    return remap(p - size/2., p + size/2., uv);
}

vec2 getSquare(vec2 uv, float x, float y, float size)
{
    vec2 p = vec2(x, y);
    return remap(p - size/2., p + size/2., uv);
}

vec2 discretise(vec2 uv, float resolution)
{
    return (floor(uv * resolution) + 0.5) / resolution;
}

vec3 errorToColor(float error)
{
    // Colours picked from:
    // https://www.kennethmoreland.com/color-advice/
    // The publication explains how to properly interpolate,
    // but I was too lazy to implement it.
    vec3 midPoint = vec3(0.865, 0.865, 0.865);
    vec3 positive = vec3(0.230, 0.299, 0.754);
    vec3 negative = vec3(0.706, 0.016, 0.150);

    if (error > 0.)
    {
        if (error <= 1.)
            return mix(midPoint, positive, error);
        // Saturate to blue above 1:
        return vec3(0., 0., 1.);
    }
    else
    {
        if (error >= -1.)
            return mix(midPoint, negative, -error);
        // Saturate to red below -1:
        return vec3(1., 0., 0.);
    }
}

float logScale(float x)
{
    float scale = 9.;
    return (exp(scale * x) - 1.) / (exp(scale) - 1.);
}

vec4 errorHistogram(vec2 uvPlot, vec2 uvFace, float error)
{
    float x = uvPlot.x;
    float dx = dFdy(x);
    float y = logScale(uvPlot.y);
    float dy = dFdy(y);
    vec4 color = vec4(errorToColor(0.), 0.1);
    if (error > 0.)
    {
        float e = (error);
        color = mix(color, vec4(errorToColor(200. * error), 1.), smoothstep(y, y + dy, e));
    }
    else if (error < 0.)
    {
        float e = (-error);
        color = mix(color, vec4(errorToColor(200. * -error), 1.), smoothstep(y, y + dy, e));
    }

    // Draw graduations at 0.125%, 0.25%, 0.5%, 1% and 2%
    for (float graduation = 0.00125; graduation <= 0.02; graduation *= 2.)
    {
        float line = smoothstep(y - dy, y, graduation) * (1. - smoothstep(y, y + dy, graduation));
        float dotted = fract(100. * x);
        float dottedLine = line * smoothstep(0., dx, dotted) * (1. - smoothstep(0.75, 0.75 + dx, dotted));
        color = mix(color, vec4(1. - color.rgb, 1.), 0.5*dottedLine);
    }

    // Draw graduations at 10%, 20%, 40% and 80%
    for (float graduation = 0.1; graduation < 1.0; graduation *= 2.0)
    {
        float line = smoothstep(y - dy, y, graduation) * (1. - smoothstep(y, y + dy, graduation));
        float dotted = fract(25. * x);
        float dottedLine = line * smoothstep(0., dx, dotted) * (1. - smoothstep(0.85, 0.85 + dx, dotted));
        color = mix(color, vec4(1. - color.rgb, 1.), 0.5*dottedLine);
    }

    return color;
}

// ----------------------------------------------------------

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float evolution = abs(fract(iTime * 0.05) * 2. - 1.);
    float cubeMapResolution = pow(2., 1. + floor(evolution * 10.));

    vec2 uv = fragCoord/iResolution.x;
    vec3 color = vec3(0.2);

    // Visualise the texels depending on the cubemap resolution
    {
        vec2 uvFace = getSquare(uv, 0.5, 0.45, 0.22);
        vec2 mask = getMask(uvFace);
        uvFace = discretise(uvFace, cubeMapResolution);

        vec3 texels = vec3(uvFace, 0.);
        color = mix(color, texels, mask.x * mask.y);
    }

    // Visualise the texel relative solid angle
    {
        vec2 uvFace = getSquare(uv, 0.2, 0.32, 0.35);
        vec2 mask = getMask(uvFace);
        uvFace = discretise(uvFace, cubeMapResolution);

        float ersa = exactRelativeSolidAngle(uvFace, cubeMapResolution);
        color = mix(color, vec3(ersa), mask.x * mask.y);
    }

    // Visualise the approximated texel relative solid angle
    {
        vec2 uvFace = getSquare(uv, 1. - 0.2, 0.32, 0.35);
        vec2 mask = getMask(uvFace);
        uvFace = discretise(uvFace, cubeMapResolution);

        float arsa = approximateRelativeSolidAngle(uvFace, cubeMapResolution);
        color = mix(color, vec3(arsa), mask.x * mask.y);
    }

    // Visualise the difference between the texel relative
    // solid angle and the approximation
    {
        vec2 uvFace = getSquare(uv, 0.5, 0.22, 0.22);
        vec2 mask = getMask(uvFace);
        uvFace = discretise(uvFace, cubeMapResolution);

        float arsa2 = approximateRelativeSolidAngle(uvFace, cubeMapResolution);
        float ersa2 = exactRelativeSolidAngle(uvFace, cubeMapResolution);
        float error = ersa2 - arsa2;
        color = mix(color, errorToColor(200. * error), mask.x * mask.y);
    }
    
    // Visualise more precisely the error across the diagonal
    {
        vec2 uvPlot = getRectangle(uv, 0.5, 0.05, 1., 0.1);
        vec2 mask5 = getMask(uvPlot);
        vec2 uvFace = vec2(uvPlot.x);
        uvFace = discretise(uvFace, cubeMapResolution);

        float arsa2 = approximateRelativeSolidAngle(uvFace, cubeMapResolution);
        float ersa2 = exactRelativeSolidAngle(uvFace, cubeMapResolution);
        float error = ersa2 - arsa2;

        vec4 histogram = errorHistogram(uvPlot, uvFace, error);
        color = mix(color, histogram.rgb, mask5.x * mask5.y * histogram.a);
    }

    fragColor = vec4(color, 1.0);
}