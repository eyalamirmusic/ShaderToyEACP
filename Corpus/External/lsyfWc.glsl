// lsyfWc - iq
// https://www.shadertoy.com/view/lsyfWc
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2018 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Computes the exact bounding box to a quadratic Bezier curve. Since the bezier is quadratic,
// the bbox can be compute with a linear equation:
//
//   Yellow: naive bbox of the 3 control points
//   Blue: exact bbox
//
// More info here: http://iquilezles.org/www/articles/bezierbbox/bezierbbox.htm
//    
// Related Shaders:
//     Quadratic Bezier - 3D      : https://www.shadertoy.com/view/ldj3Wh
//     Cubic     Bezier - 2D BBox : https://www.shadertoy.com/view/XdVBWd 
//     Cubic     Bezier - 3D BBox : https://www.shadertoy.com/view/MdKBWt
//     Quadratic Bezier - 2D BBox : https://www.shadertoy.com/view/lsyfWc
//     Quadratic Bezier - 3D BBox : https://www.shadertoy.com/view/tsBfRD


// Exact BBox to a quadratic bezier
vec4 bboxBezier(in vec2 p0, in vec2 p1, in vec2 p2 )
{
    // extremes
    vec2 mi = min(p0,p2);
    vec2 ma = max(p0,p2);

    // maxima/minima point, if p1 is outside the current bbox/hull
    if( p1.x<mi.x || p1.x>ma.x || p1.y<mi.y || p1.y>ma.y )
    {
        // p = (1-t)^2*p0 + 2(1-t)t*p1 + t^2*p2
        // dp/dt = 2(t-1)*p0 + 2(1-2t)*p1 + 2t*p2 = t*(2*p0-4*p1+2*p2) + 2*(p1-p0)
        // dp/dt = 0 -> t*(p0-2*p1+p2) = (p0-p1);

        vec2 t = clamp((p0-p1)/(p0-2.0*p1+p2),0.0,1.0);
        vec2 s = 1.0 - t;
        vec2 q = s*s*p0 + 2.0*s*t*p1 + t*t*p2;
        
        mi = min(mi,q);
        ma = max(ma,q);
    }
    
    return vec4( mi, ma );
}


// Approximated BBox to a quadratic bezier
vec4 bboxBezierSimple(in vec2 p0, in vec2 p1, in vec2 p2 )
{
    vec2 mi = min(p0,min(p1,p2));
    vec2 ma = max(p0,max(p1,p2));
    
    return vec4( mi, ma );
}

//---------------------------------------------------------------------------------------

float sdBox( in vec2 p, in vec2 b ) 
{
    vec2 q = abs(p) - b;
    vec2 m = vec2( min(q.x,q.y), max(q.x,q.y) );
    return (m.x > 0.0) ? length(q) : m.y; 
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h );
}

vec2 udBezier(in vec2 p0, in vec2 p1, in vec2 p2, in vec2 pos)
{    
    // p(t)    = (1-t)^2*p0 + 2(1-t)t*p1 + t^2*p2
    // p'(t)   = 2*t*(p0-2*p1+p2) + 2*(p1-p0)
    // p'(0)   = 2(p1-p0)
    // p'(1)   = 2(p2-p1)
    // p'(1/2) = 2(p2-p0)
    vec2 a = p1 - p0;
    vec2 b = p0 - 2.0*p1 + p2;
    vec2 c = p0 - pos;

    float kk = 1.0 / dot(b,b);
    float kx = kk * dot(a,b);
    float ky = kk * (2.0*dot(a,a)+dot(c,b)) / 3.0;
    float kz = kk * dot(c,a);      

    vec2 res;

    float p = ky - kx*kx;
    float p3 = p*p*p;
    float q = kx*(2.0*kx*kx - 3.0*ky) + kz;
    float h = q*q + 4.0*p3;

    if(h >= 0.0) 
    { 
        h = sqrt(h);
        vec2 x = (vec2(h, -h) - q) / 2.0;
        vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
        float t = uv.x + uv.y - kx;
        t = clamp( t, 0.0, 1.0 );

        // 1 root
        vec2 qos = c + (2.0*a + b*t)*t;
        res = vec2( length(qos),t);
    }
    else
    {
        float z = sqrt(-p);
        float v = acos( q/(p*z*2.0) ) / 3.0;
        float m = cos(v);
        float n = sin(v)*1.732050808;
        vec3 t = vec3(m + m, -n - m, n - m) * z - kx;
        t = clamp( t, 0.0, 1.0 );

        // 3 roots
        vec2 qos = c + (2.0*a + b*t.x)*t.x;
        float dis = dot(qos,qos);
        
        res = vec2(dis,t.x);

        qos = c + (2.0*a + b*t.y)*t.y;
        dis = dot(qos,qos);
        if( dis<res.x ) res = vec2(dis,t.y );

        qos = c + (2.0*a + b*t.z)*t.z;
        dis = dot(qos,qos);
        if( dis<res.x ) res = vec2(dis,t.z );

        res.x = sqrt( res.x );
    }
    
    return res;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    //--------
    // animate
    //--------
    float time = iTime*0.5 + 20.0;
    vec2 p0 = 0.8*sin( time*0.7 + vec2(3.0,1.0) );
    vec2 p1 = 0.8*sin( time*1.1 + vec2(0.0,6.0) );
    vec2 p2 = 0.8*sin( time*1.3 + vec2(4.0,2.0) );
    
	//-------------
    // compute bbox
	//-------------
    vec4 b1 = bboxBezierSimple(p0,p1,p2);
    vec4 b2 = bboxBezier(p0,p1,p2);
    
    //--------
    // render
    //--------
    
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    float px = 2.0/iResolution.y;

    // background
    vec3 col = vec3(0.15);
    float be = udBezier( p0, p1, p2, p ).x;
	col += 0.03*sin(be*150.0);
    col *= 1.0 - 0.3*length(p);
    
    // naive bbox
    float d = sdBox( p-(b1.xy+b1.zw)*0.5, (b1.zw-b1.xy)*0.5 );
    col = mix( col, vec3(1.0,0.6,0.0), 1.0-smoothstep(0.003,0.003+px,abs(d)) );
    
    // exact bbox
    d = sdBox( p-(b2.xy+b2.zw)*0.5, (b2.zw-b2.xy)*0.5 );
    col = mix( col, vec3(0.2,0.5,1.0), 1.0-smoothstep(0.003,0.003+px,abs(d)) );
    
    // control cage
    d = sdSegment( p, p0, p1 );
    col = mix( col, vec3(0.3), 1.0-smoothstep(0.003,0.003+px,d) );
    d = sdSegment( p, p1, p2 );
    col = mix( col, vec3(0.3), 1.0-smoothstep(0.003,0.003+px,d) );

    // bezier
    d = be;
    col = mix( col, vec3(1.0), 1.0-smoothstep(0.003,0.003+px*1.5,d) );
         
    // control points
    d = length(p0-p); col = mix( col, vec3(1.0), 1.0-smoothstep(0.04,0.04+px,d) );
    d = length(p1-p); col = mix( col, vec3(1.0), 1.0-smoothstep(0.04,0.04+px,d) );
    d = length(p2-p); col = mix( col, vec3(1.0), 1.0-smoothstep(0.04,0.04+px,d) );
    
    fragColor = vec4(col,1.0);
}