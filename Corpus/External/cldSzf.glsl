// cldSzf - iq
// https://www.shadertoy.com/view/cldSzf
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Closest point on box
//
//   For points inside the box where 3 or 4 closest points exist (p.y=0 or p.x=0) or 
//   where 2 solutions exit (the diagonals |p.x-p.y|=|b.x-b.y|, you need to take
//   extra precautions, for example:
//
//   if( g<0.0 )
//   {
//     if( w.x==w.y ) return vec2(1e20);                                          // 2 solutions
//     if( (b.x>b.y) && abs(p.x)<=(b.x-b.y) && abs(p.y)==0.0 ) return vec2(1e20); // 3 solutions
//     if( (b.x<b.y) && abs(p.y)<=(b.y-b.x) && abs(p.x)==0.0 ) return vec2(1e20); // 3 solutions
//   }
//
// Other closest point distances: https://www.shadertoy.com/playlist/ff2BRD

vec2 cloBox( in vec2 p, in vec2 b )
{
    vec2   s = sign(p);
    vec2   w = abs(p) - b;
    float  g = max(w.x,w.y);
    float  m = min(0.0,g);
    return p - vec2(w.x>=m?w.x:0.0,w.y>=m?w.y:0.0)*s;
}


// distance to box
float sdBox( in vec2 p, in vec2 b )
{
    vec2 w = abs(p)-b;
    float g = max(w.x,w.y);
    return (g>0.0)?length(max(w,0.0)):g;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // normalized pixel coordinates
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    float px = 2.0/iResolution.y;
    
    if( iMouse.z<0.01 ) m = vec2(1.2,0.8)*cos(iTime*vec2(1.1,1.3)+vec2(0,2));
    
    vec2 b1 = vec2(0.7,0.5);

    vec3 col;
    
    // background color
    {
    float d = sdBox(p,b1); 
    col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
    col *= 1.0 - exp2(-24.0*abs(d));
    col *= 0.8 + 0.2*cos(120.0*abs(d));
    col = mix( col, vec3(1.0), 1.0-smoothstep(-px,px,abs(d)-0.005) );
    }
    
    {
    // distance from pointer
    float d = sdBox(m,b1); 
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }
    
    // closest point
    {
    vec2 cl = cloBox(m,b1); 
    col = mix(col, vec3(1.0,0.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-cl)-0.025));
    }
    
    fragColor = vec4(col,1.0);
}
