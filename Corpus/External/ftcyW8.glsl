// ftcyW8 - iq
// https://www.shadertoy.com/view/ftcyW8
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Distance to the y(x)=1/x curve. 


// Minimizing the distance squared D² = (x-t)²+(y-1/t)² produces
//
// t⁴ - xt³ + yt - 1 = 0
//
// which can be solved with the quartic formula, as described in Wikipedia:
// https://en.wikipedia.org/wiki/Quartic_equation. I followed the 
// section "Summary of Ferrari's method" and simplified a lot of things
// (complex branches to reals, trigonometrics, constant unfolding, etc)
// until I got this expression.
//
// I wrote the shader for comparison with the numerically computed version
// of the SDF implemented here: https://www.shadertoy.com/view/sttyWr


// List of some other 2D distances: https://www.shadertoy.com/playlist/MXdSRf
//
// and iquilezles.org/articles/distfunctions2d


// distance to y=1/x
float sdOOX( in vec2 p )
{
    p = (p.x>p.y) ? p.yx : p.xy;
    
    float x2 = p.x*p.x/16.0;
    float y2 = p.y*p.y/16.0;
    float r = (4.0-p.x*p.y)/12.0;
    float q = x2 - y2;
    float h = q*q + r*r*r;
    float u;
    if( h<0.0 )
    {
        float m = sqrt(-r);
        u = m*cos( acos(q/(r*m))/3.0 );
    }
    else
    {
        float m = pow(sqrt(h)-q,1.0/3.0);
        u = (m - r/m)/2.0;
    }
    float w = sqrt( u + x2 );
    float b = p.y - x2*p.x*2.0;
    float t = p.x/4.0 - w + sqrt( 2.0*x2 - u + b/w/4.0 );
    
    float d = length( p-vec2(t,1.0/t) );
    
    return p.x*p.y < 1.0 ? d : -d;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    const float scale = 3.0;
    
	vec2  p = scale*fragCoord/iResolution.y;
    vec2  m = scale*iMouse.xy/iResolution.y;
    float px = scale/iResolution.y;
    
    float d = sdOOX(p);
    
    // colorize
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
	col *= 1.0 - exp(-6.0*abs(d));
	col *= 0.7 + 0.2*cos(73.33*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,3.0*px,abs(d)) );
    
    // mouse
    if( iMouse.z>0.001 )
    {
        float d = sdOOX(m);
        float l = length(p-m);
        col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 2.0*px, abs(l-abs(d))));
        col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 2.0*px, l-px*3.0));
    }
    
	fragColor = vec4(col,1.0);
}