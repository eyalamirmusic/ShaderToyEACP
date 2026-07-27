// WsV3zz - iq
// https://www.shadertoy.com/view/WsV3zz
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Shows the anisotropic self-similarity of Brownian Motion 
// on the left and the isotropic self-similarity of Fractional
// Brownian Motion if gain=0.5.
//
// On the left, a clasical Brownian Motion is generated, which
// is a process with Hurst Exponet H=1/2 (uncorrelated deltas,
// no memory). Such curve has a fractal dimension of 1.5 and
// needs a vertical scaling factor of sqrt(x) when it's scaled
// by x horizontally. It's power spectrum decays as f^-2
//
// On the right, a Fractional Brownian Motion with H=1
// which means a gain G of 0.5. It's a long memory curve
// with possitively correlated increments, has a fractal
// of 1, and is naturally istropicaly self-similar (non-
// distorted zoom). Because of that, it's what we use to
// mimic mountains. It's power spectrum decays as f^-3
//
// More info: http://iquilezles.org/www/articles/fbm/fbm.htm

// integer hash copied from Hugo Elias
float hash( int n ) 
{
	n = (n << 13) ^ n;
    n = n * (n * n * 15731 + 789221) + 1376312589;
    return -1.0+2.0*float( n & ivec3(0x0fffffff))/float(0x0fffffff);
}

// gradient noise
float gnoise( in float p )
{
    int   i = int(floor(p));
    float f = fract(p);
	float u = f*f*(3.0-2.0*f);
    return mix( hash(i+0)*(f-0.0), 
                hash(i+1)*(f-1.0), u);
}

// fbm
float fbm( in float x, in float G )
{    
    x += 26.06;
    float n = 0.0;
    float s = 1.0;
    float a = 0.0;
    float f = 1.0;    
    for( int i=0; i<16; i++ )
    {
        n += s*gnoise(x*f);
        a += s;
        s *= G;
        f *= 2.0;
        x += 0.31;
    }
    return n;
}

vec3 anim( in vec2 p, float time )
{
    vec3 col = vec3(0.0);
    
    //float ani = fract(time/4.0);
    float ani = smoothstep(0.0,1.0,fract(time/4.0));

    float zoom = pow( 2.0, 6.0*ani );
    

    if( p.x<0.0 )
    {
        vec2 q = vec2(p.x*0.5 + 0.5,p.y);
        float G = 0.707107;

        float comp = zoom;
        float comp2 = sqrt(comp);

        if( q.y<0.0 )
        {
        float y = -0.5+0.5*comp2*(fbm(0.8*q.x/comp, G ));
        y += zoom*0.004;
        col = mix( col, vec3(1.0,1.0,0.5).zyx, 1.0-smoothstep( 0.0, 12.0/iResolution.x,q.y-y));
        }
        else
        {
        float y = 0.5+0.5*fbm(0.8*q.x, G );
        col = mix( col, vec3(1.0,0.5,0.0).zyx, (1.0-smoothstep( 0.0, 12.0/iResolution.x,q.y-y)));
        }
    }
    else
    {
        vec2 q = vec2(p.x*0.5 - 0.5,p.y);
        float G = 0.5;
        float comp = zoom;
        float comp2 = comp;
        if( p.y<0.0 )
        {
        float y = -0.5+0.9*comp2*(fbm(1.0*q.x/comp, G ));
        y += zoom*0.004;
        col = mix( col, vec3(1.0,1.0,0.5), 1.0-smoothstep( 0.0, 12.0/iResolution.x,q.y-y));
        }
        else
        {
        float y = 0.5+0.9*fbm(1.0*q.x, G );
        col = mix( col, vec3(1.0,0.5,0.0), 1.0-smoothstep( 0.0, 12.0/iResolution.x,q.y-y));
        }
        
    }
       
    col  *= smoothstep(0.01,0.02,abs(p.x) );
    col  *= smoothstep(0.01,0.02,abs(p.y) );

    return col;
}


#define AA 5
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{	
    vec3 col = vec3(0.0);
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        vec2 o = vec2(m,n)/float(AA);
        vec2 p = (2.0*(fragCoord+o)-iResolution.xy)/iResolution.y;
        float d = 0.5*sin(fragCoord.x*147.0)*sin(fragCoord.y*131.0);
        float time = iTime + 0.5*(1.0/24.0)*(float(m*AA+n)+d)/float(AA*AA);

        col += anim(p,iTime);
    }
    col /= float(AA*AA);
    
    fragColor = vec4( col, 1.0 );
    
}
