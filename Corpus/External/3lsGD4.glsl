// 3lsGD4 - tpfto
// https://www.shadertoy.com/view/3lsGD4
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 J. M.
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Basic domain coloring plot (https://en.wikipedia.org/wiki/Domain_coloring)
// of the Lambert W function w = W(z) (https://en.wikipedia.org/wiki/Lambert_W_function)

#define PI 3.14159265359
#define EE 2.71828182846
#define SCALE 5.0 // plot scale
#define SPACING 0.0625 // grid line spacing

// from Fabrice Neyret, 
#define cmul(A,B) ( mat2( A, -(A).y, (A).x ) * (B) )
#define cinv(Z) ( vec2( (Z).x, -(Z).y ) / dot(Z, Z) ) 
#define cdiv(A,B) cmul( A, cinv(B) )

// Schlick bias function, from http://dept-info.labri.u-bordeaux.fr/~schlick/DOC/gem2.ps.gz
float bias( float a, float x )
{
    return x/((1.0/a - 2.0) * (1.0 - x) + 1.0);
}

// biased sawtooth
float my_saw( float x, float p )
{
    float xs = mod(x, 1.0);
    float xh = clamp(xs, 0.0, p);
    return 0.5 + 0.5 * bias(0.95, xh) * (1.0 - smoothstep(p, 1.0, xs));
}

// modified version of Inigo Quilez's method at https://www.shadertoy.com/view/MsS3Wc
// using "rational smoothstep" from https://tpfto.wordpress.com/2019/03/28/on-a-rational-variant-of-smoothstep/
vec3 smooth_hue( float h )
{
    vec3 rgb = clamp( abs(mod(6.0 * h + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return rgb * rgb * rgb/(1.0 - 3.0 * rgb * (1.0 - rgb));
}

// modified DLMF coloring, adapted from https://www.shadertoy.com/view/WtXGWN
vec3 smooth_dlmf( float h )
{
    vec3 rgb = clamp( vec3(1., -1., -1.) * abs((vec3(8., 4., 8.) * mod(h, 1.0) - vec3(4.5, 1.5, 5.5))) + vec3(-1.5, 1.5, 2.5), 0.0, 1.0 );
	return rgb * rgb * rgb/(1.0 - 3.0 * rgb * (1.0 - rgb));
}

// complex square root, from Numerical Recipes

vec2 sqrtz( in vec2 z )
{
	float ar = abs(z.x);
    float ai = abs(z.y);

    float w = (dot(z, z) == 0.0) ? 0.0 : ( (ar >= ai) ? (sqrt(ar) * sqrt(0.5 * (1.0 + sqrt(1.0 + (ai * ai)/(ar * ar))))) : (sqrt(ai) * sqrt(0.5 * (ar/ai + sqrt(1.0 + (ar * ar)/(ai * ai))))));
    
    return ((w == 0.0) ? vec2(0.0) : ((z.x >= 0.0 ? vec2(w, 0.5 * z.y/w) : vec2(0.5*ai/w, ((z.y >= 0.0) ? w : -w)))));
}

// complex logarithm

vec2 logz( in vec2 z )
{
	return vec2(log(length(z)), atan(z.y, z.x));
}

// Lambert W function, Winitzki's approximation (https://doi.org/10.1007/3-540-44839-X_82)

vec2 LambertW( in vec2 z )
{
    vec2 v = sqrtz(2.0 * EE * z + 2.0);
    vec2 w = 2.0 * logz(vec2(1.0, 0.0) + 0.8842 * v);

    return cdiv(w - logz(vec2(1.0, 0.0) + 0.9294 * logz(vec2(1.0, 0.0) + 0.5106 * v)) - vec2(1.213, 0.0), vec2(1.0, 0.0) + cinv(w + vec2(4.69483568, 0.0)));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 aspect = iResolution.xy / iResolution.y;
    vec2 z = ( fragCoord.xy / iResolution.y ) - 0.5 * aspect;
    z *= SCALE;
    
    vec2 w = LambertW(z);
    float ph = atan(w.y, w.x);
    float lm = log(0.0001 + length(w));
    
    vec3 c = vec3(1.0);
    c = smooth_dlmf(0.5 * (ph / PI));
    // uncomment for HSV version 
    // c = smooth_hue(0.5 * (ph / PI));

    c *= mix(1.0, my_saw((0.5 * (lm/PI))/SPACING, 0.95) * my_saw((0.5 * (ph / PI))/SPACING, 0.95), 0.5 + 0.5 * cos(iTime));
    fragColor = vec4(c, 1.0);
}