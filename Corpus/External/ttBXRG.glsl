// ttBXRG - iq
// https://www.shadertoy.com/view/ttBXRG
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



// Staircase function y=f(x)
//
// k>1 : flat horizontals
// k<1 : flat verticals
//
// The inverse function x=f^-1(x) is just the function itselft
// with parameter 1/k instead of k.
float staircase( in float x, in float k )
{
    float i = floor(x);
    float f = fract(x);
    
    float a = 0.5*pow(2.0*((f<0.5)?f:1.0-f), k);
    f = (f<0.5)?a:1.0-a;
    
    return i+f;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{	
    // coordinates    
    float dx = 3.0/iResolution.y;
    vec2  p = fragCoord.xy*dx;
    
    // animate staircase curve
    float k = pow( 2.0, 4.0*sin(3.1415927*iTime));
    
    // background
    vec3 col = vec3( 0.2 + 0.02*mod(floor(p.x)+floor(p.y),2.0) );

    // draw curve y=f(x)
    float y = staircase( p.x, k );
    col = mix( col, vec3(1.0,0.8,0.3), 1.0-smoothstep(0.0, 2.0*dx, abs(p.y-y) ) );
    
    // draw curve x=f^-1(x)
    float x = staircase( p.y, 1.0/k );
    col = mix( col, vec3(1.0,0.8,0.3), 1.0-smoothstep(0.0, 2.0*dx, abs(p.x-x) ) );
    
    fragColor = vec4( col, 1.0 );
}