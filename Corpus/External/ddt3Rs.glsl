// ddt3Rs - iq
// https://www.shadertoy.com/view/ddt3Rs
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Signed distance, closest point and gradient to a trapezoid.

// List of other 2D distances+gradients:
//
// https://iquilezles.org/articles/distgradfunctions2d
//
// and
//
// https://www.shadertoy.com/playlist/M3dSRf


// .x = f(p)
// .y = ∂f(p)/∂x
// .z = ∂f(p)/∂y
// .yz = ∇f(p) with ‖∇f(p)‖ = 1
vec3 sdgTrapezoid( in vec2 p, in float ra, float rb, float he, out vec2 ocl )
{
    float sx = (p.x<0.0)?-1.0:1.0;
    float sy = (p.y<0.0)?-1.0:1.0;

	p.x = abs(p.x);

    vec4 res;
    
    // bottom and top edges
    {
        float h = min(p.x,(p.y<0.0)?ra:rb);
        vec2  c = vec2(h,sy*he);
        vec2  q = p - c;
        float d = dot(q,q);
        float s = abs(p.y) - he;
        res = vec4(d,q,s);
        ocl = c;
    }
    
    // side edge
    {
        vec2  k = vec2(rb-ra,2.0*he);
        vec2  w = p - vec2(ra, -he);
        float h = clamp(dot(w,k)/dot(k,k),0.0,1.0);
        vec2  c = vec2(ra,-he) + h*k;
        vec2  q = p - c;
        float d = dot(q,q);
        float s = w.x*k.y - w.y*k.x;
        if( d<res.x ) { ocl = c; res.xyz = vec3(d,q); }
        if( s>res.w ) { res.w = s; }
    }
   
    // distance and sign
    float d = sqrt(res.x)*sign(res.w);
    res.y *= sx;
    ocl.x *= sx;
    
    return vec3(d,res.yz/d);
}

#define AA 2

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);
    
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (-iResolution.xy + 2.0*(fragCoord+o))/iResolution.y;
        #else    
        vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y;
        #endif
        vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;

        // animation
        float ra = 0.2+0.15*sin(iTime*1.3+0.0);
        float rb = 0.2+0.15*sin(iTime*1.4+1.1);
        float he = 0.5+0.2*sin(1.3*iTime);


        // sdf(p) and gradient(sdf(p))
        vec2 kk;
        vec3  dg = sdgTrapezoid( p, ra, rb, he, kk );
        float d = dg.x;
        vec2 g = dg.yz;

        // central differenes based gradient, for comparison
        //g = vec2(dFdx(d),dFdy(d))/(2.0/iResolution.y);

        // coloring
        vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.4,0.7,0.85);
        col *= 1.0 + vec3(0.5*g,0.0);
      //col = vec3(0.5+0.5*g,1.0);
        col *= 1.0 - 0.5*exp(-16.0*abs(d));
        col *= 0.9 + 0.1*cos(150.0*d);
        col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );
 
        // interaction
        if( iMouse.z>0.001 )
        {
            vec2 cl;
            d = sdgTrapezoid(m, ra, rb, he, cl).x;
            col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
            col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
            col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-cl)-0.015));
        }


	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

	fragColor = vec4( tot, 1.0 );
}