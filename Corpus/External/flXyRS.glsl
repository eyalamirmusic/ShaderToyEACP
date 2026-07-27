// flXyRS - iq
// https://www.shadertoy.com/view/flXyRS
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// sdgEllipsoid() returns the approximated ellipsoid SDF and
// the exact normalized gradient/normal of the ellipsoid, by 
// computing it analytically. This means the normal to
// the ellipsoid surface can be used during the raymarch loop
// rather inexpensivelly (compared to sampling the SDF
// multiple times to evaluate a normal for it)

// Other SDF analytic gradients:
//
// Torus:     https://www.shadertoy.com/view/wtcfzM
// Capsule:   https://www.shadertoy.com/view/WttfR7
// Ellipsoid: https://www.shadertoy.com/view/flXyRS

// .x = f(p)
// .y = ∂f(p)/∂x
// .z = ∂f(p)/∂y
// .w = ∂f(p)/∂z
// .yzw = ∇f(p) with ‖∇f(p)‖ = 1
vec4 sdgEllipsoid( vec3 p, vec3 r )
{
    p /= r; float k0 =        sqrt(dot(p,p));
    p /= r; float k1 = inversesqrt(dot(p,p));
    return vec4( k0*(k0-1.0)*k1, p*k1 );
}


#define AA 3

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
     // camera movement	
	float an = 0.5*iTime;
	vec3 ro = 1.2*vec3( 1.0*cos(an), 0.65, 1.0*sin(an) );
    vec3 ta = vec3( 0.0, -0.15, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
   
    // animate torus
    vec3 ra = vec3(0.8,0.1,0.5);
    
    // render    
    vec3 tot = vec3(0.0);
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (2.0*(fragCoord+o)-iResolution.xy)/iResolution.y;
        #else    
        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
        #endif

	    // create view ray
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

        // raymarch
        const float tmax = 5.0;
        float t = 0.0;
        for( int i=0; i<256; i++ )
        {
            vec3 pos = ro + t*rd;
            float h = sdgEllipsoid(pos,ra).x;
            if( h<0.0001 || t>tmax ) break;
            t += h;
        }
        
    
        // shading/lighting	
        vec3 col = vec3(0.0);
        if( t<tmax )
        {
            vec3 pos = ro + t*rd;
            vec3 nor = sdgEllipsoid(pos,ra).yzw;

            // compute normal numerically, for comparison
            // https://iquilezles.org/articles/normalsSDF
            #if 0
            const vec2 e = vec2(1,-1);
            const float eps = 0.0002;
            nor = normalize( e.xyy*sdgEllipsoid( pos + e.xyy*eps, ra ).x + 
                             e.yyx*sdgEllipsoid( pos + e.yyx*eps, ra ).x + 
                             e.yxy*sdgEllipsoid( pos + e.yxy*eps, ra ).x + 
                             e.xxx*sdgEllipsoid( pos + e.xxx*eps, ra ).x );

            #endif

            float dif = clamp( dot(nor,vec3(0.57703)), 0.0, 1.0 );
            float amb = 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0));
            col = vec3(0.2,0.3,0.4)*amb + vec3(0.85,0.75,0.65)*dif;
            col *= (0.5+0.5*nor)*(0.5+0.5*nor);
        }

        // gamma        
        col = sqrt( col );
	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

	fragColor = vec4( tot, 1.0 );
}