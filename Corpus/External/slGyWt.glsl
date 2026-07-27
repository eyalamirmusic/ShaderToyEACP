// slGyWt - iq
// https://www.shadertoy.com/view/slGyWt
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Approximating the SDF of the subtraction of two SDFs,
// by finding the closest intersection between the two shapes.
// Not working very well :(



// SDFs from iquilezles.org/articles/distfunctions2d
// .x = f(p), .yz = ∇f(p) with ‖∇f(p)‖ = 1
vec3 sdgCircle( in vec2 p, in vec2 c, in float r ) 
{
    p -= c;
    float l = length(p);
    return vec3( l-r, p/l );
}

// SDFs from iquilezles.org/articles/distfunctions2d
// .x = f(p), .yz = ∇f(p) with ‖∇f(p)‖ = 1
vec3 sdgBox( in vec2 p, in vec2 b )
{
    vec2 w = abs(p)-b;
    vec2 s = vec2(p.x<0.0?-1:1,p.y<0.0?-1:1);
    
    float g = max(w.x,w.y);
	vec2  q = max(w,0.0);
    float l = length(q);
    
    return vec3(   (g>0.0)?l: g,
                s*((g>0.0)?q/l : ((w.x>w.y)?vec2(1,0):vec2(0,1))));
}


float cro( vec2 a, vec2 b ) { return a.x*b.y - a.y*b.x; }


//-----------------

#define opSubtract(p,A,B)\
    /* regular subtraction */ \
    max(A.x,-B.x);\
    if( d>0.0 )\
    {\
        vec2 op = p;\
        /* find closest intersection of the two shapes */ \
        /* by recursively averaging the two closest points */ \
        for( int i=0; i<512; i++ ) \
        { \
            float d1=A.x; vec2 g1=A.yz; \
            float d2=B.x; vec2 g2=B.yz; \
            if( max(abs(d1),abs(d2))<0.001 ) break; \
            p -= 0.5*(d1*g1 + d2*g2); \
        } \
        /* distance to closest intersection*/ \
        float d3 = length(p-op);\
        /* decide whether we should update distance */ \
        vec2  g1 = A.yz;\
        vec2  g2 = B.yz;\
        float no = cro(g1,g2);\
        if( min(cro(op-p,g1)*no,cro(op-p,g2)*no)>0.0) d = d3;\
    }
    


float map( in vec2 p )
{
    vec2 off = 0.1*sin(iTime+vec2(0.0,2.0));

    float d = opSubtract( p, sdgBox(p,vec2(0.3,0.6)), 
                             sdgCircle(p,vec2(0.0,0.2)+off,0.4) );
    return d;
}

vec2 gra( in vec2 p )
{
    const float e = 0.0002;
    return vec2(map(p+vec2(e,0.0))-map(p-vec2(e,0.0)),
                map(p+vec2(0.0,e))-map(p-vec2(0.0,e)))/(2.0*e);
}



void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // normalized pixel coordinates
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    
    // distance
    float d = map(p);
    
    // coloring
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.5,0.85,1.0);
	col *= 1.0 - exp2(-32.0*abs(d));
	col *= 0.8 + 0.2*cos(128.0*abs(d));
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.002,0.005,abs(d)) );

    // debug gradient
    {
    #if 0
        vec2 g = gra(p);
        col *= 1.0 + vec3(0.5*g,0.0);
        float l = length(g);
        if( l>1.01 ) col=vec3(1,0,0);
        if( l<0.99 ) col=vec3(0,0,1);
    #endif
    }

    // debug distance with mouse
    if( iMouse.z>0.001 )
    {
    d = map(m);
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }

	fragColor = vec4(col, 1.0);
}