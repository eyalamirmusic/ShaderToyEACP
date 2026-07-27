// dt2yDK - iq
// https://www.shadertoy.com/view/dt2yDK
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Other closest point distances: https://www.shadertoy.com/playlist/ff2BRD


// Closest point on segment
vec2 cloSegment( in vec2 p, in vec2 a, in vec2 b, in float th )
{
    vec2 ba = b-a;
    vec2 pa = p-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    vec2  c = a + h*ba;
    return c + th*normalize(p-c);
}                    

/*
vec2 cloSegment( in vec2 p, in vec2 a, in vec2 b, in float th )
{
    vec2 ba = b-a;
    vec2 pa = p-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    vec2  q = pa-h*ba;
    float d = length(q); // distance
    vec2  g = q/d;       // gradient
    return p-(d-th)*g; // closest point
} 
*/

// distance to segment
float sdSegment( in vec2 p, in vec2 a, in vec2 b, in float th )
{
    vec2 ba = b-a;
    vec2 pa = p-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    vec2  q = pa-h*ba;
    return length(q) - th;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // normalized pixel coordinates
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    float px = 2.0/iResolution.y;
    
    if( iMouse.z<0.01 ) m = vec2(1.1,0.8)*cos(iTime*vec2(1.1,1.3)+vec2(0,2));

    vec2 v1 = 0.7*cos( 0.5*iTime*vec2(1.3,1.0) + vec2(2,4) );
    vec2 v2 = 0.7*cos( 0.5*iTime*vec2(0.9,1.2) + vec2(1,5) );
    float th = 0.2*(0.7+0.3*sin(iTime*1.2+2.0));


    vec3 col;
    
    // background color
    {
    float d = sdSegment(p,v1,v2,th);
    col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
    col *= 1.0 - exp2(-24.0*abs(d));
    col *= 0.8 + 0.2*cos(120.0*abs(d));
    col = mix( col, vec3(1.0), 1.0-smoothstep(-px,px,abs(d)-0.005) );
    }
    
    {
    // distance from pointer
    float d = sdSegment(m,v1,v2,th); 
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }
    
    // closest point
    {
    vec2 cl = cloSegment(m,v1,v2,th); 
    col = mix(col, vec3(1.0,0.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-cl)-0.025));
    }
    
    fragColor = vec4(col,1.0);
}
