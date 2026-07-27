// slyfDc - kara0xfb
// https://www.shadertoy.com/view/slyfDc
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org


// Gradient Noise (http://en.wikipedia.org/wiki/Gradient_noise), not to be confused with
// Value Noise, and neither with Perlin's Noise (which is one form of Gradient Noise)
// is probably the most convenient way to generate noise (a random smooth signal with 
// mostly all its energy in the low frequencies) suitable for procedural texturing/shading,
// modeling and animation.
//
// It produces smoother and higher quality than Value Noise, but it's of course slighty more
// expensive.
//
// The princpiple is to create a virtual grid/latice all over the plane, and assign one
// random vector to every vertex in the grid. When querying/requesting a noise value at
// an arbitrary point in the plane, the grid cell in which the query is performed is
// determined, the four vertices of the grid are determined and their random vectors
// fetched. Then, the position of the current point under  evaluation relative to each
// vertex is doted (projected) with that vertex' random vector, and the result is
// bilinearly interpolated with a smooth interpolant.


// Value    Noise 2D, Derivatives: https://www.shadertoy.com/view/4dXBRH
// Gradient Noise 2D, Derivatives: https://www.shadertoy.com/view/XdXBRH
// Value    Noise 3D, Derivatives: https://www.shadertoy.com/view/XsXfRH
// Gradient Noise 3D, Derivatives: https://www.shadertoy.com/view/4dffRH
// Value    Noise 2D             : https://www.shadertoy.com/view/lsf3WH
// Value    Noise 3D             : https://www.shadertoy.com/view/4sfGzS
// Gradient Noise 2D             : https://www.shadertoy.com/view/XdXGW8
// Gradient Noise 3D             : https://www.shadertoy.com/view/Xsl3Dl
// Simplex  Noise 2D             : https://www.shadertoy.com/view/Msf3WH
// Wave     Noise 2D             : https://www.shadertoy.com/view/tldSRj

// Hash Functions for GPU Rendering - Jarzynski, Olano
// https://www.jcgt.org/published/0009/03/02/
ivec2 Pcg2(ivec2 v)
{
    uint x = uint(v.x);
    uint y = uint(v.y);
    x = x * 1664525u + 1013904223u;
    y = y * 1664525u + 1013904223u;
    x += y * 1664525u;
    y += x * 1664525u;
    x ^= x >> 16;
    y ^= y >> 16;
    x += y * 1664525u;
    y += x * 1664525u;
    return ivec2(x, y);
}

// Hash Functions for GPU Rendering - Jarzynski, Olano
// https://www.jcgt.org/published/0009/03/02/
ivec3 Pcg3(ivec3 v)
{
    uint x = uint(v.x);
    uint y = uint(v.y);
    uint z = uint(v.z);
    x = x * 1664525u + 1013904223u;
    y = y * 1664525u + 1013904223u;
    z = z * 1664525u + 1013904223u;
    x += y * z;
    y += z * x;
    z += x * y;
    x ^= x >> 16;
    y ^= y >> 16;
    z ^= z >> 16;
    x += y * z;
    y += z * x;
    z += x * y;
    return ivec3(x, y, z);
}

// Hash Functions for GPU Rendering - Jarzynski, Olano
// https://www.jcgt.org/published/0009/03/02/
ivec4 Pcg4(ivec4 v)
{
    uint x = uint(v.x);
    uint y = uint(v.y);
    uint z = uint(v.z);
    uint w = uint(v.w);
    x = x * 1664525u + 1013904223u;
    y = y * 1664525u + 1013904223u;
    z = z * 1664525u + 1013904223u;
    w = w * 1664525u + 1013904223u;
    x += y * w;
    y += z * x;
    z += x * y;
    w += y * z;
    x ^= x >> 16;
    y ^= y >> 16;
    z ^= z >> 16;
    w ^= w >> 16;
    x += y * w;
    y += z * x;
    z += x * y;
    w += y * z;
    return ivec4(x, y, z, w);
}

vec2 grad2( ivec2 v )
{
    int n = Pcg2(v).x;
    // higher quality rng in high bits
    float x = (n & (1<<30)) != 0 ? 1.0 : -1.0;
    float y = (n & (1<<29)) != 0 ? 1.0 : -1.0;
    float z = (n & (1<<28)) != 0 ? 1.0 : -1.0;
    vec3 gr = vec3(x, y, z);
    return vec2(gr.x, gr.y);
}

vec3 grad3( ivec3 v)
{
    v = Pcg3(v);
    // higher quality rng in high bits
    float x = (v.x & (1<<30)) != 0 ? 1.0 : -1.0;
    float y = (v.y & (1<<29)) != 0 ? 1.0 : -1.0;
    float z = (v.z & (1<<28)) != 0 ? 1.0 : -1.0;
    return vec3(x, y, z);
}

float noise2( in vec2 p )
{
    ivec2 i = ivec2(floor( p ));
     vec2 f =       fract( p );
	
	vec2 u = f * f * ((f * -2.0f) + 3.0f);

    float c00 = dot(grad2(i + ivec2(0,0)), f - vec2(0.0, 0.0));
    float c01 = dot(grad2(i + ivec2(1,0)), f - vec2(1.0, 0.0));
    float c10 = dot(grad2(i + ivec2(0,1)), f - vec2(0.0, 1.0));
    float c11 = dot(grad2(i + ivec2(1,1)), f - vec2(1.0, 1.0));
    
    float c = mix(mix(c00, c01, u.x), mix(c10, c11, u.x), u.y);
    return c;
}

float noise3(in vec3 p)
{
    ivec3 i = ivec3(floor( p ));
     vec3 f =       fract( p );
	
	vec3 u = f * f * ((f * -2.0f) + 3.0f);

    float c000 = dot(grad3(i + ivec3(0,0,0)), f - vec3(0.0,0.0,0.0));
    float c001 = dot(grad3(i + ivec3(0,0,1)), f - vec3(0.0,0.0,1.0));
    
    float c010 = dot(grad3(i + ivec3(0,1,0)), f - vec3(0.0,1.0,0.0));
    float c011 = dot(grad3(i + ivec3(0,1,1)), f - vec3(0.0,1.0,1.0));
    
    float c100 = dot(grad3(i + ivec3(1,0,0)), f - vec3(1.0,0.0,0.0));
    float c101 = dot(grad3(i + ivec3(1,0,1)), f - vec3(1.0,0.0,1.0));
    
    float c110 = dot(grad3(i + ivec3(1,1,0)), f - vec3(1.0,1.0,0.0));
    float c111 = dot(grad3(i + ivec3(1,1,1)), f - vec3(1.0,1.0,1.0));
    
    float c00z = mix(c000, c001, u.z);
    float c01z = mix(c010, c011, u.z);
    float c10z = mix(c100, c101, u.z);
    float c11z = mix(c110, c111, u.z);
    
    float c0yz = mix(c00z, c01z, u.y);
    float c1yz = mix(c10z, c11z, u.y);
    
    float cxyz = mix(c0yz, c1yz, u.x);
    
    return cxyz;
}

// -----------------------------------------------

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = fragCoord / iResolution.xy;
	
	float f = 0.0;

    vec2 uv2 = p*vec2(iResolution.x/iResolution.y,1.0);
    vec3 uv3 = vec3(uv2.x, uv2.y,iTime);
    uv3.xy = 32.0 * uv3.xy;
    float freq = 1.0;
    float scale = 1.0;
    float peak = 0.0;
    float u = min(p.x, 1.0);
    float octaves = 1.0 + u * 3.0;
    octaves = min(octaves, 4.0);
    for (float i = 0.0; i < ceil(octaves); i += 1.0)
    {
        float amt = min(max(octaves - i, 0.0), 1.0);
        scale *= amt;
        peak += scale;
        f += scale * noise3(uv3 * freq);
        scale *= 0.55;
        freq *= 2.0136;
    }
    f = f / peak;
    f = 0.5 + 0.5*f;
	
	fragColor = vec4( f, f, f, 1.0 );
}