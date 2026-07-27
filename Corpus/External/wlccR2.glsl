// wlccR2 - butadiene
// https://www.shadertoy.com/view/wlccR2
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.


// Description : GLSL 2D simplex noise function
//      Author : Ian McEwan, Ashima Arts
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License :
//  Copyright (C) 2011 Ashima Arts. All rights reserved.
//  Distributed under the MIT License. See LICENSE file.
//  https://github.com/ashima/webgl-noise
//
//////////////////////////////////////////////////////////////////////////////////////////////
// Some useful functions
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {

    // Precompute values for skewed triangular grid
    const vec4 C = vec4(0.211324865405187,
                        // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,
                        // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,
                        // -1.0 + 2.0 * C.x
                        0.024390243902439);
                        // 1.0 / 41.0

    // First corner (x0)
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);

    // Other two corners (x1, x2)
    vec2 i1 = vec2(0.0);
    i1 = (x0.x > x0.y)? vec2(1.0, 0.0):vec2(0.0, 1.0);
    vec2 x1 = x0.xy + C.xx - i1;
    vec2 x2 = x0.xy + C.zz;

    // Do some permutations to avoid
    // truncation effects in permutation
    i = mod289(i);
    vec3 p = permute(
            permute( i.y + vec3(0.0, i1.y, 1.0))
                + i.x + vec3(0.0, i1.x, 1.0 ));

    vec3 m = max(0.5 - vec3(
                        dot(x0,x0),
                        dot(x1,x1),
                        dot(x2,x2)
                        ), 0.0);

    m = m*m ;
    m = m*m ;

    // Gradients:
    //  41 pts uniformly over a line, mapped onto a diamond
    //  The ring size 17*17 = 289 is close to a multiple
    //      of 41 (41*7 = 287)

    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt(a0*a0 + h*h);
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0+h*h);

    // Compute final noise value at P
    vec3 g = vec3(0.0);
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * vec2(x1.x,x2.x) + h.yz * vec2(x1.y,x2.y);
    return 130.0 * dot(m, g);
}

#define OCTAVES 2

// Ridged multifractal
// See "Texturing & Modeling, A Procedural Approach", Chapter 12
float ridge(float h, float offset) {
    h = abs(h);     // create creases
    h = offset - h; // invert so creases are at top
    h = h * h;      // sharpen creases
    return h;
}

float ridgedMF(vec2 p) {
    float lacunarity = 2.0;
    float gain = 0.5;
    float offset = 0.9;

    float sum = 0.0;
    float freq = 1.0, amp = 0.5;
    float prev = 1.0;
    for(int i=0; i < OCTAVES; i++) {
        float n = ridge(snoise(p*freq), offset);
        sum += n*amp;
        sum += n*amp*prev;  // scale by previous octave
        prev = n;
        freq *= lacunarity;
        amp *= gain;
    }
    return sum;
}

/////////////////////////////////////////////////////////////////////////////////////////////
float PI = 3.1415926535;
vec3 MoonDirection = normalize(vec3(-0.5,0.4,-0.3));
vec3 MoonColor = vec3(0.6,0.7,1.2);
float random (vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}

mat2 rot(float r){
    return mat2(cos(r),sin(r),-sin(r),cos(r));
}

vec4 dist(vec3 p){
    //p.z *= 0.7;
    p.y -= 0.3;
	float d = 0.009;
    float no = ridgedMF(p.xz+0.3*snoise(p.xz+0.1*iTime));
    vec3 col = vec3(1,1,1)*0.02*exp(-no*3.);
    float thredy = 0.5;
    float thx = p.y-thredy;
    vec3 highems = vec3(1.3,1.0,1.0)*max(thx*8.0*exp(-3.5*vec3(2.,1.2,1.5)*thx),0.);
    col *= highems;
    return vec4(col,d);
}

vec4 ground(vec3 p){
    p.y -= 0.3;
    p.x -= -0.;
    float d = p.y - smoothstep(0.0,1.0,length(p.xz-vec2(-0.4,0.))*1.)*0.23*ridgedMF(vec2(0.9,1.)*(p.xz-vec2(-0.1,0.02*iTime)));
    //d = max(d,-(length(p-vec3(-0.4,0.65,-0.6))-0.8));
    vec3 col = vec3(0);
    return vec4(col,d);
}

vec3 getnormal(vec3 p)
{
	const vec2 e = vec2(0.5773,-0.5773)*0.0001;
	vec3 nor = normalize( e.xyy*ground(p+e.xyy).w +
 		e.yyx*ground(p+e.yyx).w + e.yxy*ground(p+e.yxy).w + e.xxx*ground(p+e.xxx).w);
	nor = normalize(vec3(nor));
	return nor ;
}


vec3 star(vec2 s){
    vec3 c = vec3(snoise(s));
    c = pow(c,vec3(5.));
    c = clamp(7.*clamp(c-0.7,0.0,1.0),0.0,1000.0);
  
    return c;
}

vec3 background(vec3 rd){
    vec2 rs = vec2(atan(length(rd.xy),rd.z),atan(rd.x,rd.y));
    vec3 moon = 0.5*clamp(MoonColor*0.07/length(MoonDirection-rd),0.0,1.0);
    return moon+star(rs*50.)*vec3(0.5)+vec3(0.7,0.5,0.5)*star(rs*50.+20.)+vec3(0.5,0.5,0.7)*star(rs*50.+70.);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iResolution.xy;
    vec2 p = uv;
    p = 2.0*(p-0.5);
    p.x *= iResolution.x/iResolution.y;

    vec3 offset = vec3(0,-0.4 ,0);
    vec3 ro = vec3(0,0,0)-offset;
    vec3 ta = vec3(0,1.6,-2)-offset;
    vec3 cdir = normalize(ta-ro);
    vec3 side = cross(cdir,vec3(0,1,0));
    vec3 up = cross(side,cdir);
    float fov = 0.4;
   
    vec3 rd = normalize(side*p.x+up*p.y+cdir*fov);
     //rd.xz *= rot(iTime);
    float d,t=0.;
    float gd = 0.;
    vec3 ac = vec3(0.);
    vec4 disres;
    float kset = 0.3;
    float sen = (1.0+1.5*pow(abs(sin(iTime*kset))*(1.0-fract(iTime*kset/(0.5*PI))),1.));
    
    for(int i = 0;i<139;i++){
    	disres = 2.0*dist(ro+rd*t)*sen;
        d = disres.w;
        gd = 0.5*ground(ro+rd*t).w;
        d = min(gd,d);
        t += d;
		ac += disres.xyz;
        if((ro+rd*t).z<-1.5)break;
    }

    vec3 col = vec3(0.);

   	col += ac;
    
    col += background(rd);
    
    if(gd<0.01){
        vec3 sp = ro+rd*t;
        vec3 normal = getnormal(sp);
        float snk = 1.;
        vec3 cnormal = normal + 0.1*(vec3(random(snk*sp.yz),random(snk*sp.zx),random(snk*sp.xy))-0.5);
        cnormal = normalize(cnormal);
        col = 1.5*vec3(193,157,121)/255.*MoonColor*vec3(max(dot(cnormal,MoonDirection),0.));
        col += MoonColor*0.02;
        ac = vec3(0.0);
        
        vec3 snormal;
        vec3 rrd;
        for(int i =0; i<8; i++){
            snormal =normal + 1.0*(vec3(random(snk*sp.yz+float(i)*100.),random(snk*sp.zx+float(i)*100.),random(snk*sp.xy+float(i)*100.))-0.5);
            snormal = normalize(snormal);
            t = 0.4;
            ro = sp;
            rrd =snormal;// reflect(rd,snormal);
            for(int i = 0;i<10;i++){
                disres = 6.0*dist(ro+rrd*t)*sen;
                d = disres.w;
                t += d;
                ac += disres.xyz;
            }
        }
        col += 0.1*ac;
    
    }
    
    // Output to screen
	col = pow(col,vec3(0.8));
    fragColor = vec4(col,1.0);
}