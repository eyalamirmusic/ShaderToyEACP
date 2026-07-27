// 4dBXz3 - iq
// https://www.shadertoy.com/view/4dBXz3
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2014 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



// A useful trick to avoid certain type of discontinuities
// during rendering and procedural content generation. More info:
//
// https://iquilezles.org/www/articles/dontflip/dontflip.htm



// Flip v if in the negative half plane defined by r (this works in 3D too)
vec2 flipIfNeg( in vec2 v, in vec2 r )
{
    float k = dot(v,r);
    return (k>0.0) ? v : -v;
}

// Reflect v if in the negative half plane defined by r (this works in 3D too)
vec2 reflIfNeg( in vec2 v, in vec2 r )
{
    float k = dot(v,r);
    return (k>0.0) ? v : v-2.0*r*k;
}

// Clip v if in the negative half plane defined by r (this works in 3D too)
vec2 clipIfNeg( in vec2 v, in vec2 r )
{
    float k = dot(v,r);
    return (k>0.0) ? v : (v-r*k)*inversesqrt(1.0-k*k/dot(v,v));
}

//===============================================================

float sdLine( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h );
}

// https://www.shadertoy.com/view/slj3Dd
float sdArrow( in vec2 p, vec2 a, vec2 b, float w1, float w2 )
{
    const float k = 3.0;
	vec2  ba = b - a;
    float l2 = dot(ba,ba);
    float l = sqrt(l2);

    p = p-a;
    p = mat2(ba.x,-ba.y,ba.y,ba.x)*p/l;
    p.y = abs(p.y);
    vec2 pz = p-vec2(l-w2*k,w2);

    vec2 q = p;
    q.x -= clamp( q.x, 0.0, l-w2*k );
    q.y -= w1;
    float di = dot(q,q);

    q = pz;
    q.y -= clamp( q.y, w1-w2, 0.0 );
    di = min( di, dot(q,q) );

    if( p.x<w1 )
    {
    q = p;
    q.y -= clamp( q.y, 0.0, w1 );
    di = min( di, dot(q,q) );
    }

    if( pz.x>0.0 )
    {
    q = pz;
    q -= vec2(k,-1.0)*clamp( (q.x*k-q.y)/(k*k+1.0), 0.0, w2 );
    di = min( di, dot(q,q) );
    }
    
    float si = 1.0;
    float z = l - p.x;
    if( min(p.x,z)>0.0 )
    {
      float h = (pz.x<0.0) ? w1 : z/k;
      if( p.y<h ) si = -1.0;
    }
    return si*sqrt(di);
}

//===============================================================

float line( in vec2 p, in vec2 a, in vec2 b, float w , float e)
{
    return 1.0 - smoothstep( -e, e, sdLine( p, a, b ) - w );
}

float arrow( in vec2 p, in vec2 a, in vec2 b, float w1, float w2, float e )
{
    return 1.0 - smoothstep( -e, e, sdArrow( p, a, b, w1, w2) );
}

//===============================================================

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
 	vec2 p = fragCoord/iResolution.x;
    vec2 q = p;
    p.x = mod(p.x,1.0/3.0) - 1.0/6.0;
    
    p.y -= 0.5*iResolution.y/iResolution.x;
    p.y += 0.04;
    
    float e = 1.0/iResolution.x;
   
    float time = iTime;
    
    //time = mod( time, 8.0 );
    float an = 0.3*(1.0-smoothstep(-0.1,0.1,sin(0.125*6.283185*(time+1.0/2.0))));
    
    vec2 r = vec2( sin(an), cos(an) );
    vec2 pe = r.yx*vec2(-1.0,1.0);
    
    vec3 col = vec3(0.15);
    col = vec3(21,32,43)/255.0;

    float wi = 0.0015;
    float s = dot(p,r);
    if( s>0.0 )
    {
        float r = length(p);
        if( r<0.12 )
        {
            float nr = r/0.12;
            col += 0.25*nr*nr;
        }
        col = mix(col,vec3(0.7), 1.0-smoothstep(-e,e,abs(r-0.12)-wi));
    }

    col = mix( col, vec3(0.7), arrow(p, vec2(0.0), r*0.18, wi, 0.01, e) );
    col = mix( col, vec3(0.7), line(p, -0.12*pe, 0.12*pe, wi, e) );

    {
    float an = cos(0.5*6.283185*time);
    vec2 v = vec2( -cos(an), sin(an) )*0.12;
    vec2 f;
         if( q.x<0.333 ) f = flipIfNeg( v, r );
    else if( q.x<0.666 ) f = reflIfNeg( v, r );
    else                 f = clipIfNeg( v, r );

    col = mix( col, col+0.2, arrow(p, vec2(0.0), v, wi, 5.0*wi, e) );
    col = mix( col, vec3(1.0,0.7,0.2), arrow(p, vec2(0.0), f, wi, 5.0*wi, e) );
    }
    
    fragColor = vec4( col, 1.0 );
}