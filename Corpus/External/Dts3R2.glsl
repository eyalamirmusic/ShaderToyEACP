// Dts3R2 - piyushslayer
// https://www.shadertoy.com/view/Dts3R2
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

/**
* Creative Commons CC0 1.0 Universal (CC-0)
*
* A simple christmas tree made from 2D points.
*
*/

#define PI 3.1415926535
#define TAU 6.2831853071
#define ROTATE(v, x) mat2(cos(x), sin(x), -sin(x), cos(x)) * v
#define REMAP_HALF_NDC(x, c, d) (((x + 0.5) * (d - c)) + c) // Remap from [-0.5, 0.5] domain to [c, d]

#define N 512.0
#define N_ONE_QUARTER N * 0.25
// This is mostly to cull any points at the bottom that are too close to the "camera".
#define N_OFFSET 1.0
#define STAR_N 7.0
#define STAR_BEAM_THICKNESS 3.0

const vec3 LIGHT_COLORS[3] = vec3[3](
                                        vec3(1.0,  0.05,  0.05), 
                                        vec3(0.05, 1.0,   0.05), 
                                        vec3(1.0,  0.25,  0.05)
                                    );

// https://www.shadertoy.com/view/4djSRW
float Hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 Hash21(float p)
{
	vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);

}

// Signed distance to an n-star polygon with external angle en by iq: https://www.shadertoy.com/view/3tSGDy
float SignedDistanceNStar2D(in vec2 p, in float r, in float an, in float bn, in vec2 acs, in float m) // m=[2,n]
{
    float en = PI / m;
    vec2  ecs = vec2(cos(en), sin(en));
    p = length(p) * vec2(cos(bn), abs(sin(bn)));

    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}

void DrawStar(in vec2 uv, in float time, inout vec3 outColor)
{
    uv -= vec2(0.001, 0.225);
    uv = ROTATE(uv, time * 0.75);
    // Some common pre-calculation in order to avoid duplication
    float an = PI / STAR_N;
    float bn = mod(atan(uv.x, uv.y), 2.0 * an) - an;
    vec2 acs = vec2(cos(an), sin(an));
    // Top star
    outColor += 5e-4 / pow(abs(SignedDistanceNStar2D(uv, 0.01, an, bn, acs, STAR_N * 0.5)), 1.23) * LIGHT_COLORS[2];
    // Star beams
    outColor += smoothstep(STAR_BEAM_THICKNESS / max(iResolution.x, iResolution.y), 0.0, SignedDistanceNStar2D(uv, 1.5, an, bn, acs, STAR_N)) * 
        LIGHT_COLORS[2] * smoothstep(0.75, -5.0, length(uv));
}

void DrawTree(in vec2 uv, in float time, inout vec3 outColor)
{
    float u, theta, pointHeight, invN = 1.0 / N;
    vec2 st, hash, layer;
    vec3 pointOnCone, pointColor = vec3(1.0);
    const vec2 radius = vec2(1.5, 3.2);
    uvec3 colorThreshold;
    for (float i = N_OFFSET; i < N; ++i)
    {
        // Modify this to change the tree pattern
        hash = Hash21(2.0 * TAU * i);
        
        // Some basic light color based on hash
        colorThreshold.x = uint(hash.x < 0.45); // red;
        colorThreshold.y = 1u - colorThreshold.x; // green
        colorThreshold.z = uint(hash.x > 0.9); // white;
        pointColor = vec3(colorThreshold | colorThreshold.z);
        
        // Calculate point on cone based on: https://mathworld.wolfram.com/Cone.html
        u = i * invN;
        theta = 1609.0 * hash.x + time * 0.5;
        pointHeight = 1.0 - u;
        
        // Split the cone into layers to make it look more like a christmas tree
        layer = vec2(3.2 * mod(i, N_ONE_QUARTER) * invN, 0.0);
        pointOnCone = 0.5 * (radius.xyx - layer.xyx) * vec3(pointHeight * cos(theta), u - 0.5, pointHeight * sin(theta)); // [-0.5, 0.5]
        
        // Scale uv based on depth of the point
        st = uv * (REMAP_HALF_NDC(pointOnCone.z, 0.5, 1.0) + hash.y) * 4.5;
        
        // outColor += smoothstep(0.01, 0.0, length(st - pointOnCone.xy));
        outColor += REMAP_HALF_NDC(pointOnCone.z, 3.0, 0.6) * // Slightly adjust the size of the point based on distance to "camera" 
            2e-5 / pow(length(st - pointOnCone.xy), 1.7) * pointColor;
    }
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y; // [-0.5, 0.5] adjusted for aspect ratio
    vec3 outColor = vec3(0.005, 0.01, 0.03); // Background color
    vec4 m = iMouse / iResolution.yyyy;
    float t = 0.0;
    
    if (m.z > 0.0)
    {
        t = m.x * TAU;
    }
    else
    {
        t = iTime * 0.5;
    }
    
    DrawTree(uv, t, outColor);
    DrawStar(uv, t, outColor);
    
    float vignette = dot(uv, uv);
    vignette *= vignette;
    vignette = 1.0 / (vignette * vignette + 1.0);
    
    fragColor = vec4(pow(outColor * vignette, vec3(0.4545)), 1.0) - Hash12(fragCoord.xy * t + iResolution.yy) * 0.04;
}