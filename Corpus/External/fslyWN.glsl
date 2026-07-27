// fslyWN - iq
// https://www.shadertoy.com/view/fslyWN
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Distance to a logarithmic spiral. It's inexact, mostly
// noticeable when the number of rotations is small.


// List of some other 2D distances: https://www.shadertoy.com/playlist/MXdSRf
//
// and iquilezles.org/articles/distfunctions2d


// w is the width / distance from center to tip
// k is the number of rotations
float sdSpiral( in vec2 p, float w, in float k )
{
    // body
    const float kTau = 6.283185307;
    float r = length(p);
    float a = atan(p.y,p.x);
    float n = floor( 0.5/w + (log2(r/w)*k-a)/kTau );
    float ra = w*exp2((a+kTau*(min(n+0.0,0.0)-0.5))/k);
    float rb = w*exp2((a+kTau*(min(n+1.0,0.0)-0.5))/k);
    float d = min( abs(r-ra), abs(r-rb) );

    // tip
    return min( d, length(p+vec2(w,0.0)) );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // normalized pixel coordinates
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    float px = 2.0/iResolution.y;
    
    // recenter
    p -= vec2(0.2,-0.09);
    m -= vec2(0.2,-0.09);
    
    // animation
    float sw = 1.0;
    float sk = 1.0 + 10.0*(0.5-0.5*cos(iTime+1.5));
    
    // distance
    float d = sdSpiral(p, sw, sk);
    
    // coloring
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
    col *= 1.0 - exp(-7.0*abs(d));
    col *= 0.8 + 0.2*cos(160.0*abs(d));
    col = mix( col, vec3(1.0), 1.0-smoothstep(-px,px,abs(d)-0.005) );

    if( iMouse.z>0.001 )
    {
    d = sdSpiral(m, sw, sk);
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(-px, px, abs(length(p-m)-abs(d))-0.005));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(-px, px, length(p-m)-0.015));
    }

	fragColor = vec4(col, 1.0);
}