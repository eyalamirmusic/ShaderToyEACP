// 3d2GRh - iq
// https://www.shadertoy.com/view/3d2GRh
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// random hash
float hash( in ivec2 q )
{
    // You SHOULD replace this by something better. Again, Do Not Use in production.
    int n = q.x*131 + q.y*57;
    n = (n << 13) ^ n;
    n = n * (n * n * 15731 + 789221) + 1376312589;
    return float((n>>8)&0x007fffff)/float(0x007fffff);
}

// basic value noise
float noise( in vec2 x, in int p )
{
    ivec2 i = ivec2(floor(x));
     vec2 f =       fract(x);
    
    f = f*f*(3.0-2.0*f);
    
    return mix(mix( hash((i+ivec2(0,0))&(p-1)), 
                    hash((i+ivec2(1,0))&(p-1)),f.x),
               mix( hash((i+ivec2(0,1))&(p-1)), 
                    hash((i+ivec2(1,1))&(p-1)),f.x),f.y);
}

// fractal noise
float fbm( in vec2 x, in int p )
{
    float f = 0.0;
    float s = 0.5;
    for( int i=0; i<9; i++ )
    {
        f += s*noise( x, p );
        s *= 0.5;
        x *= 2.0;
        p *= 2;
    }
    return f;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    
    bool polar = fract(iTime/6.0)>0.5;

    // coords
    vec2 q = (polar) ? vec2( 4.0+4.0*atan(p.y,p.x)/3.1415927, length(p) ) :  p*8.0;
    q += 0.5*iTime;

    // fbm
    const int pe = 8; // Period. Make it a power of 2
    float f = fbm( q, pe );
	vec3 col = vec3(f);

    // grid
    if( !polar )
    {
        vec2 w = smoothstep(0.0,0.01,abs(mod(8.0*p+float(pe/2),float(pe))/float(pe)-0.5));
        col = mix( col, vec3(1.0,0.7,0.0), (1.0-w.x*w.y)*smoothstep( 0.8,0.9,sin(iTime) ) );
    }
    
    
	fragColor = vec4( col, 1.0 );
}