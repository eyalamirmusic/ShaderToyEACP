// dtGyWw - fishy
// https://www.shadertoy.com/view/dtGyWw
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2015 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Using Newtown's root solver to compute the distance to
// an ellipse, instead of using the analytical solution in
// https://www.shadertoy.com/view/4sS3zz.
//
// In retrospect, it's the same as Antonalog's https://www.shadertoy.com/view/MtXXW7
//
// More information here:
//
// https://iquilezles.org/articles/ellipsedist
//
//
// Ellipse distances related shaders:
//
// Analytical     : https://www.shadertoy.com/view/4sS3zz
// Newton Trig    : https://www.shadertoy.com/view/4lsXDN
// Newton No-Trig : https://www.shadertoy.com/view/tttfzr 
// ?????????????? : https://www.shadertoy.com/view/tt3yz7

// List of some other 2D distances: https://www.shadertoy.com/playlist/MXdSRf
//
// and iquilezles.org/articles/distfunctions2d

#define rot(t) mat2(cos(t), -sin(t), sin(t), cos(t))

// for visualization purposes only
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 ba = b-a;
    vec2 pa = p-a;
    float h =clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length(pa-h*ba);
}

float sdEllipse( vec2 p, vec2 a, vec2 b )
{
    // do transformations and get the minor/major radii
    float la = length(a);
    float lb = length(b);
    p *= mat2(a/la, b/lb);
    vec2 ab = vec2(la, lb);
    
    // everything past this point is by iq
    
    // symmetry
	p = abs( p );

    // find root with Newton solver
    vec2 q = ab*(p-ab);
	float w = (q.x<q.y)? 1.570796327 : 0.0;
    for( int i=0; i<4; i++ )
    {
        vec2 cs = vec2(cos(w),sin(w));
        vec2 u = ab*vec2( cs.x,cs.y);
        vec2 v = ab*vec2(-cs.y,cs.x);
        w = w + dot(p-u,v)/(dot(p-u,u)+dot(v,v));
    }
    
    // compute final point and distance
    float d = length(p-ab*vec2(cos(w),sin(w)));
    
    // return signed distance
    return (dot(p/ab,p/ab)>1.0) ? d : -d;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;

    vec2 a = vec2(sin(iTime*2.5)*0.1 + 0.5, 0);
    vec2 b = vec2(0, sin(iTime*1.5)*0.1 + 0.5);
    a *= rot(iTime*0.25);
    b *= rot(iTime*0.25);
    if(iMouse.z > 0.001)
    {
        a = m;
        b = (normalize(a)*(sin(iTime*1.5)*0.1+0.5))*rot(1.57);
    }
	
	float d = sdEllipse( p, a, b );
    vec3 col = vec3(1.0) - sign(d)*vec3(0.1,0.4,0.7);
	col *= 1.0 - exp(-2.0*abs(d));
	col *= 0.8 + 0.2*cos(120.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );
    // added these lines to show the vectors
    col = mix( col, vec3(1.0, 1.0, 0.0), 1.0-smoothstep(0.0,0.01,sdSegment(p, vec2(0), a)) );
    col = mix( col, vec3(0.0, 1.0, 1.0), 1.0-smoothstep(0.0,0.01,sdSegment(p, vec2(0), b)) );

	fragColor = vec4( col, 1.0 );;
}