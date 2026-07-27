// flXBzB - blackle
// https://www.shadertoy.com/view/flXBzB
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

//excluding the function cubicRoot:
//CC0 1.0 Universal https://creativecommons.org/publicdomain/zero/1.0/
//To the extent possible under law, Blackle Mori has waived all copyright and related or neighboring rights to this work.

//this works by exploiting the fact that there exist polynomials T_n
//such that T_n(cos(x)) = cos(n*x). these are chebyshev polynomials
//of the first kind. T_2 is a parabola, and we can estimate the
//distance to the cosine curve by using the analytic distance to this
//parabola.
//
//to get the distance from p to the sine curve, we first do
//p.x = sin(p.x*frequency)/frequency
//then we produce the closest point on the parabola
//T_2(x) = 2x^2 - 1
//call this point "q". we undo the mapping we made to p with
//q.x = asin(q.x*frequency)/frequency
//we do need to clamp it between -1 and 1 before passing into asin
//but that is the gist of the method.
//
//this estimate only works for one half of the principal half cycle,
//so we need to use two estimates for either side, and take the closest
//point to p. finally we do a single newton's method update to finalize
//the estimate. I'm not sure how accurate this is, but it looks extremely
//close to the ground truth.
//
// article: https://suricrasia.online/demoscene/sine-distance/
//
//other solutions:
//  iq:        https://www.shadertoy.com/view/3t23WG
//  fabrice:   https://www.shadertoy.com/view/tsXXRM
//  blackle 2: https://www.shadertoy.com/view/3lSyDG

#define PI 3.141592653

//perform one step of netwon's method to finalize the estimate
#define ONE_NEWTON_STEP

// of equation x^3+c1*x+c2=0
/* Stolen from http://perso.ens-lyon.fr/christophe.winisdoerffer/INTRO_NUM/NumericalRecipesinF77.pdf,
   page 179 */
// subsequently stolen from https://www.shadertoy.com/view/MdfSDn
float cubicRoot(float c1, float c2) {
	float q = -c1/3.;
	float r = c2/2.;
	float q3_r2 = q*q*q - r*r;
	if(q3_r2 < 0.) {
		float a = -sign(r)*pow(abs(r)+sqrt(-q3_r2),.333333);
		float b = a == 0. ? 0. : q/a;
		return a+b;
	}
	float theta = acos(r/pow(q,1.5));
	return -2.*pow(q,.5)*cos(theta/3.);
}

vec2 cls_one(vec2 p, float f) {
    //sorry this is unreadable
    float f2 = f*f; //sq
    float cmn = 8.*f2*f2;
    float x = sin(p.x*f)/f;
    float pp = ((-4.*p.y-4.)*f2 + 1.)/cmn;
    float qq = -x/cmn;
    float sol = cubicRoot(pp, qq);
    
    x = asin(clamp(sol*f,-1.,1.))/f;
    return vec2(x,-cos(f*2.*x));
}

vec3 sine_SDF(vec2 p, float freq) {
    float wavelen = PI/freq;

    //map p to be within the principal half cycle
    float cell = round(p.x/wavelen)*wavelen;
    float sgn = sign(cos(p.x*freq));
    p.x = (p.x-cell)*sgn;
    
    vec2 off = vec2(-PI/freq/2.,0);
    //approximate either side of the principal half cycle with
    //the distance to the 2nd chebyshev polynomial of the 1st kind
    vec2 a = -off+cls_one(off+p, freq/2.);
    vec2 b =  off-cls_one(off-p, freq/2.);

    //pick closest, comment out to see how the one-sided approximation looks
    if (length(p-b) < length(p-a)) a = b;

#ifdef ONE_NEWTON_STEP
    //newton's method update via lagrange multipliers
    //visually very close after one step, but more increases accuracy quadratically
    vec3 K = vec3(a,p.x-p.y);
    
    //it might be possible to simplify this a lot...
    vec3 lagrange = vec3(2.*(K.x-p.x)+K.z*-cos(K.x*freq)*freq,
        2.*(K.y-p.y)-K.z,
        K.y+sin(K.x*freq));
    K -= (inverse(mat3(2.-K.z*-sin(K.x*freq)*freq*freq,0,cos(K.x*freq)*freq,0,2,1,-cos(K.x*freq)*freq,-1,0))*lagrange);
    a = K.xy;
    a.y = -sin(a.x*freq);
#endif

    float dist = length(p-a)*sign(p.y+sin(p.x*freq));
    //map the closest point back to global coordinates
    a.x *= sgn; a.x += cell;
    return vec3(dist,a);
}

vec3 shadeDistance(float d) {
    d *= .5;
    float dist = d*120.;
    float banding = max(sin(dist), 0.0);
    float strength = sqrt(1.-exp(-abs(d)*2.));
    float pattern = mix(strength, banding, (0.6-abs(strength-0.5))*0.3);
    
    vec3 color = vec3(pattern);
    
    color *= d > 0.0 ? vec3(1.0,0.56,0.4) : vec3(0.4,0.9,1.0);

    return color;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-0.5*iResolution.xy)/iResolution.y;
    vec2 mouse = (iMouse.xy-0.5*iResolution.xy)/iResolution.y;
	float scale = 5.;
    uv*=scale; mouse*=scale;
    float pixel_size = scale/iResolution.y;
    
    float t = sin(iTime)*.5+.5;
    float freq = mix(20.,.1,sqrt(t));

    vec3 mousedist = sine_SDF(mouse, freq);
    vec3 col = shadeDistance(sine_SDF(uv, freq).x);
    if (iMouse.z > 0.) {
        col *= smoothstep(-pixel_size,pixel_size, distance(mouse, uv) - abs(mousedist.x)) *.5 +.5;
        col = mix(vec3(.8,.9,.4), col, smoothstep(-pixel_size,pixel_size, distance(mousedist.yz, uv) - .05));
    }
    float sn = abs(uv.y+cos(uv.x*freq))-.01;
    float snl = 0.*smoothstep(fwidth(sn),0.,sn);

    fragColor = vec4(col,1.0) + snl;
}