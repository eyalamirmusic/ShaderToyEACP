// cs2yzG - iq
// https://www.shadertoy.com/view/cs2yzG
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Signed distance to a vesica given by two points and a (semi)width, using
// two square roots per evaluation.

// See also https://www.shadertoy.com/view/XtVfRW for an axis aligned vesica

// List of some other 2D distances:
//     https://www.shadertoy.com/playlist/MXdSRf
// and
//     iquilezles.org/articles/distfunctions2d


float sdVesicaSegment( in vec2 p, in vec2 a, in vec2 b, float w )
{
    // shape constants
    float r = 0.5*length(b-a);
    float d = 0.5*(r*r-w*w)/w;
    
    // center, orient and mirror
    vec2 v = (b-a)/r;
    vec2 c = (b+a)*0.5;
    vec2 q = 0.5*abs(mat2(v.y,v.x,-v.x,v.y)*(p-c));
    
    // feature selection (vertex or body)
    vec3 h = (r*q.x < d*(q.y-r)) ? vec3(0.0,r,0.0) : vec3(-d,0.0,d+w);
 
    // distance
    return length(q-h.xy) - h.z;
}


// iquilezles.org/articles/distfunctions2d
float udSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 ba = b-a;
    vec2 pa = p-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length(pa-h*ba);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // coordinates
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    p *= 1.4;
    m *= 1.4;
    
    // animation
    vec2  v1 = cos( iTime*0.5 + vec2(0.0,1.00) + 0.0 );
	vec2  v2 = cos( iTime*0.5 + vec2(0.0,3.00) + 1.5 );
    float th = 0.40*(0.5+0.495*cos(iTime*1.1+2.0));
    float ra = 0.15*(0.5+0.495*cos(iTime*1.3+1.0));
    float al = smoothstep( -0.5, 0.5,sin(iTime+0.1) );
    ra *= 1.0-al;
    
    // distance
    float d = sdVesicaSegment( p, v1, v2, th ) - ra;
    
    // color
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
	col *= 1.0 - exp2(-10.0*abs(d));
	col *= 0.8 + 0.2*cos(100.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.015,abs(d)) );

    // mouse
    if( iMouse.z>0.001 )
    {
    d = sdVesicaSegment( m, v1, v2, th ) - ra;
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }

    // geometry
    {
    vec2 c = (v1+v2)/2.0;
    vec2 u = normalize( vec2(v2.y-v1.y,v1.x-v2.x) );
    vec2 v3 = c + u*(th+ra);
    vec2 v4 = c - u*(th+ra);
    d = min(min(min(length(p-v1),
                    length(p-v2)),
                min(length(p-v3),
                    length(p-v4))) - 0.015,
                min(udSegment(p,v1,v2),
                    udSegment(p,v3,v4)) - 0.004 );
                  
    col = mix(col, vec3(1.0,1.0,0.0), al*(1.0-smoothstep(0.0, 0.005, d)));
    }
    
	fragColor = vec4(col,1.0);
}