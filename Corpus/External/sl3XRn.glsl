// sl3XRn - iq
// https://www.shadertoy.com/view/sl3XRn
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2021 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Intersecting two line segments.

float cro( in vec2 a, in vec2 b ) { return a.x*b.y - a.y*b.x; }

bool intersect( vec2 a1, vec2 b1, vec2 a2, vec2 b2, out vec2 point )
{
    float d = cro(b2-a2,b1-a1);
    float s = cro(a1-a2,b1-a1) / d;
    float t = cro(a1-a2,b2-a2) / d;
    point = a1 + (b1-a1)*t; // or point = a2 + (b2-a2)*s;
    return s>=0.0 && t>=0.0 && t<=1.0 && s<=1.0;
}

/*
// same math as above, alternative writing by mla (see comments)
bool intersect( vec2 a1, vec2 b1, vec2 a2, vec2 b2, out vec2 point )
{
    vec2 st = inverse(mat2(b1-a1,a2-b2))*(a2-a1);
    point = a1 + (b1-a1)*st.x;
    return s>=0.0 && t>=0.0 && t<=1.0 && s<=1.0;
    // alternative range test with single comparison
    // st = abs(st-0.5); return max(st.x,st.y)<0.5;
}
*/

// https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float sdLine( in vec2 p, in vec2 a, in vec2 b)
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp(dot(pa,ba)/(dot(ba,ba)),0.0, 1.0);
    return length(pa-ba*h);
}

// https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float sdDisk( in vec2 p, in vec2 c, in float r )
{
    return length(p-c)-r;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // animate
    vec2 a1 = vec2(-2.0+vec2(1.5,1.0)*sin(iTime*1.1+vec2(0.0,0.5)));
    vec2 b1 = vec2( 2.0+vec2(1.5,1.0)*sin(iTime*1.2+vec2(5.0,2.0)));
    vec2 a2 = vec2(-2.0+vec2(1.5,1.0)*sin(iTime*1.3+vec2(3.0,1.0)));
    vec2 b2 = vec2( 2.0+vec2(1.5,1.0)*sin(iTime*1.4+vec2(1.5,4.5)));

    // NDC coords
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    
    // background
    vec3 col = vec3(0.15) - 0.04*length(p);

    p *= 3.5;
        
    // segment 1
    {
    float    d = sdLine(p,a1,b1)-0.02;
    d = min( d,  sdDisk(p,a1,0.06) );
    d = min( d,  sdDisk(p,b1,0.06) );
    col = mix(col, vec3(0.0,0.7,0.7), smoothstep(0.01,0.0,d) );
    }
    
    // segment 2
    {
    float    d = sdLine(p,a2,b2)-0.02;
    d = min( d,  sdDisk(p,a2,0.06) );
    d = min( d,  sdDisk(p,b2,0.06) );
    col = mix(col, vec3(0.2,0.5,1.0), smoothstep(0.01,0.0,d) );
    }

    // intersection
    vec2 pos;
    if( intersect(a1, b1, a2, b2, pos) )
    {
        float d = sdDisk(p,pos,0.03);
        d = min( d, abs(d-0.2) ) - 0.01; // onion, see https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
        col = mix(col, vec3(1.0,0.7,0.0), smoothstep(0.01,0.0,d));
    }    

    // cheap dither (color banding removal)
    col += (1.0/512.0)*sin(fragCoord.x*2.0+13.0*fragCoord.y);
    
    fragColor = vec4(col,1.0);
}
