// clGyWm - iq
// https://www.shadertoy.com/view/clGyWm
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org

// Analytic derivatives for a simple field of random Gabor kernels

// please never use this hash or any other fract based
// hash in production. they are really bad.
vec2 hash( in vec2 x )   
{
    const vec2 k = vec2( 0.3183099, 0.3678794 );
    x = x*k + k.yx;
    return fract( 16.0*k*fract( x.x*x.y*(x.x+x.y)) );
}

vec3 gabor_wave(in vec2 p)
{    
    vec2  ip = floor(p);
    vec2  fp = fract(p);
    
    const float fr = 2.0*6.283185;
    const float fa = 4.0;
    
    vec3 av = vec3(0.0,0.0,0.0);
    vec3 at = vec3(0.0,0.0,0.0);
	for( int j=-2; j<=2; j++ ) // can reduce this search to just [-1,1] 
    for( int i=-2; i<=2; i++ ) // if you are okey with some small errors
	{		
        vec2  o = vec2( i, j );
        vec2  h = hash(ip+o);
        vec2  r = fp - (o+h);

        vec2  k = normalize(-1.0+2.0*hash(ip+o+vec2(11,31)) );

        float d = dot(r, r);
        float l = dot(r, k);
        float w = exp(-fa*d);
        vec2 cs = vec2( cos(fr*l), sin(fr*l) );
        
        av += w*vec3(cs.x, -2.0*fa*r*cs.x - cs.y*fr*k );
        at += w*vec3(1.0,  -2.0*fa*r);
	}
  //return av;
    return vec3( av.x, av.yz-av.x*at.yz/at.x  ) /at.x;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = fragCoord/iResolution.y;

    vec3 f = gabor_wave(8.0*p);

    vec3 col = vec3(0.5 + 0.5*f.x);
    if( p.y<0.5 )
    {
        // show analytical derivatives
        col = 0.5 + 0.01*vec3(f.yz*8.0,0.0);
        
        // show low quality numerical derivatives (check correctness)
        //col = 0.5 + 0.01*vec3(dFdx(f.x)*iResolution.y, dFdy(f.x)*iResolution.y, 0.0 );
    }

    fragColor = vec4( col, 1.0 );
}