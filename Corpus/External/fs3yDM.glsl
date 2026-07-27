// fs3yDM - iq
// https://www.shadertoy.com/view/fs3yDM
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org

// Correct SDF and gradient to a Squircle. NOTE - this is a brite force
// way to do this, it has tesselation artifacts and is slow. But it is exact
// (in the limit). Not also this is NOT a great way go blend between a circle
// and a square btw; for that you can use https://www.shadertoy.com/view/7sdXz2


// .x = f(p)
// .y = ∂f(p)/∂x
// .z = ∂f(p)/∂y
// .yz = ∇f(p) with ‖∇f(p)‖ = 1
vec3 sdSquircle(vec2 p, float n)
{
    // symmetries
    vec2 k = sign(p); p = abs(p);
    bool m = p.y>p.x; if( m ) p=p.yx;
   
    const int num = 16; // tesselate into 8x16=128 segments, more denselly at the corners
    float s = 1.0;
    float d = 1e20;
    vec2 oq = vec2(1.0,0.0);
    vec2  g = vec2(0.0,0.0);
    for( int i=1; i<=num; i++ )
    {
        float h = (6.283185/8.0)*float(i)/float(num);
        vec2  q = pow(vec2(cos(h),sin(h)),vec2(2.0/n));
        vec2  pa = p-oq;
        vec2  ba = q-oq;
        vec2  z = pa - ba*clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
        float d2 = dot(z,z);
        if( d2<d )
        {
            d = d2;
            s = pa.x*ba.y - pa.y*ba.x;
            g = z;
        }
        oq = q;
    }
    
    // undo symmetries
    if( m ) g=g.yx; g*=k; 
    
    d = sign(s)*sqrt(d);
    return vec3( d, g/d );
}

float incorrect_sdSquircle(vec2 p, float n)
{
    return pow(pow(abs(p.x),n) + pow(abs(p.y),n),1.0/n) - 1.0;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // normalized pixel coordinates
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    p *= 1.4;
    m *= 1.4;
    
     // animation
    float n = 3.0 + 2.5*sin(6.283185*iTime/3.0);

    // distance
    vec3 dg =  sdSquircle(p, n);
    float d = dg.x;
    vec2 g = dg.yz;
    
    // central differenes based gradient, for comparison
    //g = vec2( dFdx(d), dFdy(d) )/(2.0*1.4/iResolution.y);

    // coloring
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.4,0.7,0.85);
    col *= 1.0 + vec3(0.5*g,0.0);
    col *= 1.0 - 0.5*exp(-8.0*abs(d));
    col *= 0.9 + 0.1*cos(90.0*d);
    col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.015,abs(d)) );

    // mouse interaction
    if( iMouse.z>0.001 )
    {
    d = sdSquircle(m,n).x;
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.010, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.010, length(p-m)-0.015));
    }
    
	fragColor = vec4(col, 1.0);
}