// Nt3yDH - iq
// https://www.shadertoy.com/view/Nt3yDH
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Distance to the a cross made of four y(x) = 1/x curves. Minimizing the
// distance squared d²(x,y) = (x-t)²+(y-1/t)² produces a 4th degree
// polyonomial in t, which I'm solving with Ferrari's Method as described
// here: https://en.wikipedia.org/wiki/Quartic_equation
//
// I added a paramter k in the open range (0,1) to control its shape.
// Compare to negative squircle here: https://www.shadertoy.com/view/7stcR4

// List of some other 2D distances: https://www.shadertoy.com/playlist/MXdSRf
//
// and iquilezles.org/articles/distfunctions2d


// k in (0,1) range
float sdHyperbolicCross( in vec2 p, float k )
{
    // scale
    float s = 1.0/k - k;
    p = p*s;
    // symmetry
    p = abs(p);
    p = (p.x>p.y) ? p.yx : p.xy;
    // offset
    p += k;
    
    // solve quartic (for details see https://www.shadertoy.com/view/ftcyW8)
    float x2 = p.x*p.x/16.0;
    float y2 = p.y*p.y/16.0;
    float r = (p.x*p.y-4.0)/12.0;
    float q = y2-x2;
    float h = q*q-r*r*r;
    float u;
    if( h<0.0 )
    {
        float m = sqrt(r);
        u = m*cos( acos(q/(r*m) )/3.0 );
    }
    else
    {
        float m = pow(sqrt(h)+q,1.0/3.0);
        u = (m+r/m)/2.0;
    }
    float w = sqrt(u+x2);
    float x = p.x/4.0-w+sqrt(2.0*x2-u+(p.y-x2*p.x*2.0)/w/4.0);
    
    // clamp arm
    x = max(x,k);
    
    // compute distance to closest point
    float d = length( p-vec2(x,1.0/x) ) / s;

    // sign
    return p.x*p.y < 1.0 ? -d : d;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    const float scale = 1.5;
    
	vec2  p = scale*(2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2  m = scale*(2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    float px = scale*2.0/iResolution.y;
    
    float k = 0.5 + 0.45*sin(3.14159*iTime);
    
    float d = sdHyperbolicCross(p, k);
    
    // colorize
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
	col *= 1.0 - exp2(-10.0*abs(d));
	col *= 0.7 + 0.2*cos(70.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,4.0*px,abs(d)) );
    
    // mouse
    if( iMouse.z>0.001 )
    {
        float d = sdHyperbolicCross(m, k);
        float l = length(p-m);
        col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 2.0*px, abs(l-abs(d))));
        col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 2.0*px, l-px*3.0));
    }
    
	fragColor = vec4(col,1.0);
}