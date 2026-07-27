// dtGBRG - Dain
// https://www.shadertoy.com/view/dtGBRG
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// https://www.shadertoy.com/view/dtGBDz orthogonal circles grassy plant, 2023 jt
// based on https://www.shadertoy.com/view/ctyBzm orthogonal circles flower sdf 3d
// based on https://www.shadertoy.com/view/clGBzm orthogonal circles flower sdf 2
// based on https://www.shadertoy.com/view/dldBWl orthogonal circles flower sdf
// exact sdf for shape related to https://www.shadertoy.com/view/cltfW2 orthogonal circles flower
// SDF exactness using https://www.shadertoy.com/view/DdX3WH Interior Distance Detect Errors

// Circle arcs orthogonal to unit sphere
// with circle segment endpoints at equidistant latitude / longitude.
// Reminds me of a clumpy grass variant I like.

// TODO: Can something similar be done with spherical fibonacci instead?
//       (see e.g. https://www.shadertoy.com/view/lllXz4 )

// tags: sdf, flower, circle, grass, distance, conformal, disk, plant, loopless, exact, orthogonal

// The MIT License
// Copyright (c) 2023 Jakob Thomsen
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//succulent makes DF not so precise, so set to 0 if you want exact SDF
//It doesn't appear to miss the surface, but it will jump further into the grass rather than landing on the 0 contour
#define SUCCULENT_RADIUS .08

//exact SDF radius, if somewhat boring looking
#define GRASS_RADIUS 0.01

#define pi 3.1415926

float ortho_circle_flower_sdf(float n, vec2 p) // https://www.shadertoy.com/view/dldBWl orthogonal circle flower sdf (jt)
{
    p.x = abs(p.x);
 
    n = 2.01+ abs(sin(iTime*.5)*10.0);//Any N > 2 will work now

    float slice2 = (pi*2.0)/float(n);
    
    // endpoints
    float phiReal = atan(p.x,p.y);

    float endPtRound = fract(n*.5);
    
   //quantized phi--but do it so it works with any N value not just odd
    float phi = (round(phiReal/slice2 - endPtRound)+endPtRound)*slice2;
    
    vec2 c = vec2(sin(phi),cos(phi));
    
    float d = length(p-c);//distance to endpoint
    

    bool wantCircle = dot(p,c)<1.0 
                    ||  phi <0.0; //Without this sometimes you get a floating tip at center/top with non odd N :/
    
    
    //we can skip this circle stuff when outside the shape
    if(wantCircle){
    
        float slice = slice2*.5;
        float a = (p.y*p.y+2.0*p.y+p.x*p.x+1.0);
        float b = p.x*2.0;
    
        float ang1 = floor(atan(a,b)/slice)*slice;
    
        float r0 = tan(ang1);         // quantize floor angle
        float r1 = tan(ang1 + slice); // quantize ceil angle
 
        d =  min(abs(length(p-vec2(r0,-1))-r0),
                 abs(length(p-vec2(r1,-1))-r1));
    }
    return d;
 }

float dot2(vec2 a){
   // return length(a);
    return dot(a,a);
}
float fade(float f){
   // return sin(f*pi);
    f = 1.0-f*f;
    f = 1.0-f*f;
    return f;
}
float ortho_circle_flower_sdf(float m, float n, vec3 p) // https://www.shadertoy.com/view/dtGBDz orthogonal circles grassy plant (jt)
{
    float phi = round(atan(p.y,p.x)/(2.0*pi/float(m)))*(2.0*pi/float(m)); // polar & quantize
  //  phi  = abs(phi);
    p.xy = mat2(cos(phi),-sin(phi),sin(phi),cos(phi))*p.xy;
   // p.x = abs(p.x);
//    return length(vec2(ortho_circle_flower_sdf(n, vec2(p.xz)),p.y));
    
    float q = ortho_circle_flower_sdf(float(n), vec2(p.x,p.z));

    return length(vec2(q,p.y))-SUCCULENT_RADIUS*fade(1.0-min(dot2(p.xz),1.0));;
    
}

mat3 yaw_pitch_roll(float yaw, float pitch, float roll)
{
    mat3 R = mat3(vec3(cos(yaw), sin(yaw), 0.0), vec3(-sin(yaw), cos(yaw), 0.0), vec3(0.0, 0.0, 1.0));
    mat3 S = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(pitch), sin(pitch)), vec3(0.0, -sin(pitch), cos(pitch)));
    mat3 T = mat3(vec3(cos(roll), 0.0, sin(roll)), vec3(0.0, 1.0, 0.0), vec3(-sin(roll), 0.0, cos(roll)));

    return R * S * T;
}

float map(vec3 p)
{
    float n = float(mix(3.0, 11.0, 0.5+0.5*cos(2.0*pi*iTime/10.0))); // animate number of leafs
   // n = 5.0;
    float m =2.01 + cos(iTime*.2)*10.0;
   // m =3;
    return ortho_circle_flower_sdf(m, n, p)-GRASS_RADIUS;
}

#define EPSILON 0.001
#define DIST_MAX 50.0
#define ITER_MAX 200u

// https://iquilezles.org/articles/normalsSDF tetrahedron normals
vec3 normal( vec3 p )
{
    const float h = EPSILON;
    const vec2 k = vec2(1,-1);
    return normalize( k.xyy*map( p + k.xyy*h ) +
                      k.yyx*map( p + k.yyx*h ) +
                      k.yxy*map( p + k.yxy*h ) +
                      k.xxx*map( p + k.xxx*h ) );
}

float trace(vec3 ro, vec3 rd, float t0, float t1) // pass on running out of iterations
{
    // NOTE: Limited number of iterations to avoid stalling
    //       when ray passes closely (just above EPSILON)
    //       in parallel to a surface.
    uint i;
    float t;
    for(t = t0, i = 0u; t < t1 && i < ITER_MAX; i++)
    {
        float h = map(ro + rd * t);
        if(h < EPSILON)
            return t;
        t += h;
    }

    return t; // stop on running out of iterations
    //return t1; // pass on running out of iterations
}

// NOTE: Don't forget to add +normal*EPSILON to the starting position
//       to avoid artifacts caused by getting stuck in the surface
//       due to starting at distance < EPSILON from the surface.
//       (normal could be calculated here but that would most likely be redundant)
float shadow(vec3 ro, vec3 rd, float t0, float t1)
{
    return trace(ro, rd, t0, t1) < t1 ? 0.0 : 1.0;
}

// https://iquilezles.org/articles/rmshadows
float softshadow(vec3 ro, in vec3 rd, float t0, float t1, float k)
{
    float res = 1.0;
    float ph = 1e20;
    uint i;
    float t;
    for(t = t0, i = 0u; t < t1 && i < ITER_MAX; i++)
    {
        float h = map(ro + rd*t);
        if( h < EPSILON )
            return 0.0;
        float y = h*h/(2.0*ph);
        float d = sqrt(h*h-y*y);
        res = min( res, k*d/max(0.0,t-y) );
        ph = h;
        t += h;
    }
    return res;
}

// https://www.shadertoy.com/view/Xds3zN raymarching primitives
float calcAO( in vec3 pos, in vec3 nor )
{
    float occ = 0.0;
    float sca = 1.0;
    for( int i=0; i<5; i++ )
    {
        float h = 0.01 + 0.12*float(i)/4.0;
        float d = map( pos + h*nor );
        occ += (h-d)*sca;
        sca *= 0.95;
        if( occ>0.35 ) break;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 ) ;
}

vec3 material(vec3 p)
{
    return vec3(0.1,1.0,0.0);
}

void mainImage(out vec4 fragColor, vec2 I)
{
    bool demo = all(lessThan(iMouse.xy, vec2(10.0)));
    vec2 R = iResolution.xy;
    I = (2.0 * I - R) / R.y; // concise scaling thanks to Fabrice
    float yaw = 2.0 * pi * float(iMouse.x) / float(R.x);
    float pitch = pi - pi / 2.0 * float(iMouse.y) / float(R.y);
    yaw = !demo ? yaw : 2.0 * pi * fract(iTime * 0.01);
    pitch = !demo ? pitch : 4.0/3.0 * pi / 2.0;

    vec3 ro = vec3(0.0, 0.0,-2.5);
    vec3 rd = normalize(vec3(I.xy, 2.0)); // NOTE: omitting normalization results in clipped edges artifact

    mat3 M = yaw_pitch_roll(yaw, pitch, 0.0);
    ro = M * ro;
    rd = M * rd;
    //ro.z += 1.0;

    vec3 color = vec3(1);
    float dist = trace(ro, rd, 0.0, DIST_MAX);
    if(dist < DIST_MAX)
    {
        vec3 dst = ro + rd * dist;
        vec3 n = normal(dst);

        //color *= (n * 0.5 + 0.5);
        color *= material(dst);

        vec3 lightdir = normalize(vec3(1.0, 1.0, 1.0));
        vec3 ambient = vec3(0.4);
        float brightness = max(dot(lightdir, n), 0.0);
        if(brightness > 0.0)
            brightness *= shadow(ro + rd * dist + n * 0.01, lightdir, 0.0, DIST_MAX);
            //brightness *= softshadow(ro + rd * dist + n * 0.01, lightdir, 0.0, DIST_MAX, 20.0);
        color *= (ambient * calcAO(dst, n) + brightness);

        if(brightness > 0.0)
        {
            float specular = pow(max(0.0, dot(n, normalize(-rd + lightdir))), 250.0);
            color += specular;
        }

        vec3 fog_color = vec3(0.2);
        color = mix(fog_color, vec3(color), exp(-pow(dist/20.0, 2.0))); // fog
    }
    else
    {
        //color *= mix(vec3(0,0.5,0.5),vec3(0,0,1),abs(-rd.z)); // sky
        color *= 0.0;
    }

    color = tanh(color); // roll-off overly bright colors
    color = sqrt(color); // approximate gamma
    fragColor = vec4(color, 1);
}
