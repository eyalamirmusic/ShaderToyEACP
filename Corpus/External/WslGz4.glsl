// WslGz4 - iq
// https://www.shadertoy.com/view/WslGz4
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2018 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



// Analytic fake soft shadow for boxes. With a single ray, we can compute a soft shadow.
// It is "plausible", but not accurate. It can probably be optimized further, right now
// I am testing the 12 edges, but generaly you only need to test between 1 and 6.


// Other Box functions:
//
// Intersection:     https://www.shadertoy.com/view/ld23DV
// Occlusion:        https://www.shadertoy.com/view/4sSXDV
// Occlusion:        https://www.shadertoy.com/view/4djXDy
// Density:          https://www.shadertoy.com/view/Ml3GR8
// Fake soft shadow: https://www.shadertoy.com/view/WslGz4

// Other Soft Shadow functions:
//
// Sphere:    https://www.shadertoy.com/view/4d2XWV
// Ellipsoid: https://www.shadertoy.com/view/llsSzn
// Box:       https://www.shadertoy.com/view/WslGz4
// Capsule:   https://www.shadertoy.com/view/MlGczG



#define SHADOW_TYPE 2

// SHADOW_TYPE = 2 ---> great soft shadow
// SHADOW_TYPE = 1 ---> super cheap soft shadow
// SHADOW_TYPE = 0 ---> regular hard shadows


#if SHADOW_TYPE==2
float dot2( in vec3 v ) { return dot(v,v); }

float segShadow( in vec3 ro, in vec3 rd, in vec3 pa, float sh )
{
    float dm = dot(rd.yz,rd.yz); // dm = 1.0 - rd.x*rd.x
    float k1 = (ro.x-pa.x)*dm;
    float k2 = (ro.x+pa.x)*dm;
    vec2  k5 = (ro.yz+pa.yz)*dm;
    float k3 = dot(ro.yz+pa.yz,rd.yz);
    vec2  k4 = (pa.yz+pa.yz)*rd.yz;
    vec2  k6 = (pa.yz+pa.yz)*dm;
    
    for( int i=0; i<4; i++ )
    {
        vec2  s = vec2(i&1,i>>1);
        float t = dot(s,k4) - k3;
        
        if( t>0.0 )
        sh = min(sh,dot2(vec3(clamp(-rd.x*t,k1,k2),k5-k6*s)+rd*t)/(t*t));
    }
    return sh;
}

// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
float boxSoftShadow( in vec3 ro, in vec3 rd, in mat4 txx, in vec3 rad, in float sk ) 
{
	vec3 rdd = (txx*vec4(rd,0.0)).xyz;
	vec3 roo = (txx*vec4(ro,1.0)).xyz;

    vec3 m = 1.0/rdd;
    vec3 n = m*roo;
    vec3 k = abs(m)*rad;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

    float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
    if( tN<tF && tF>0.0) return 0.0;
    
    float sh = 1.0;
    sh = segShadow( roo.xyz, rdd.xyz, rad.xyz, sh );
    sh = segShadow( roo.yzx, rdd.yzx, rad.yzx, sh );
    sh = segShadow( roo.zxy, rdd.zxy, rad.zxy, sh );
    sh = clamp(sk*sqrt(sh),0.0,1.0);
    return sh*sh*(3.0-2.0*sh);
}
#endif

#if SHADOW_TYPE==1
// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
float boxSoftShadow( in vec3 ro, in vec3 rd, in mat4 txx, in vec3 rad, in float sk ) 
{
	vec3 rdd = (txx*vec4(rd,0.0)).xyz;
	vec3 roo = (txx*vec4(ro,1.0)).xyz;

    vec3 m = 1.0/rdd;
    vec3 n = m*roo;
    vec3 k = abs(m)*rad;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

    float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
    // fake soft shadow
    if( tF<0.0) return 1.0;
    float sh = clamp(0.3*sk*(tN-tF)/tN,0.0,1.0);
    return sh*sh*(3.0-2.0*sh);
}    
#endif

#if SHADOW_TYPE==0
// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
float boxSoftShadow( in vec3 ro, in vec3 rd, in mat4 txx, in vec3 rad, in float sk ) 
{
	vec3 rdd = (txx*vec4(rd,0.0)).xyz;
	vec3 roo = (txx*vec4(ro,1.0)).xyz;

    vec3 m = 1.0/rdd;
    vec3 n = m*roo;
    vec3 k = abs(m)*rad;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

    float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
    if( tN>tF || tF<0.0) return 1.0;
	return 0.0;
}
#endif

// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
bool boxIntersect( in vec3 ro, in vec3 rd, in mat4 txx, in mat4 txi, in vec3 rad,
                 out vec2 outT, out vec3 outNor, out vec2 outST, out int outFaceID ) 
{
    // convert from ray to box space
	vec3 rdd = (txx*vec4(rd,0.0)).xyz;
	vec3 roo = (txx*vec4(ro,1.0)).xyz;

    vec3 s = vec3((rdd.x<0.0)?1.0:-1.0,
                  (rdd.y<0.0)?1.0:-1.0,
                  (rdd.z<0.0)?1.0:-1.0);

	// ray-box intersection in box space
    vec3 m = 1.0/rdd;
    vec3 t1 = m*(-roo + s*rad);
    vec3 t2 = m*(-roo - s*rad);

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
	if( tN > tF || tF < 0.0) return false;

    // compute normal (in world space), face and UV
         if( t1.x>t1.y && t1.x>t1.z ) { outNor = txi[0].xyz*s.x; outST = roo.yz+rdd.yz*t1.x; outFaceID=(1+int(s.x))/2; /* 0, 1 */ } 
    else if( t1.y>t1.z   )            { outNor = txi[1].xyz*s.y; outST = roo.zx+rdd.zx*t1.y; outFaceID=(5+int(s.y))/2; /* 2, 3 */ }
    else                              { outNor = txi[2].xyz*s.z; outST = roo.xy+rdd.xy*t1.z; outFaceID=(9+int(s.z))/2; /* 4, 5 */ }

	outT = vec2(tN,tF);
    
    return true;
}


// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
float boxOcclusion( in vec3 pos, in vec3 nor, in mat4 txx, in mat4 txi, in vec3 rad ) 
{
	vec3 p = (txx*vec4(pos,1.0)).xyz;
	vec3 n = (txx*vec4(nor,0.0)).xyz;
    
    // 8 verts
    vec3 v0 = normalize( vec3(-1.0,-1.0,-1.0)*rad - p);
    vec3 v1 = normalize( vec3( 1.0,-1.0,-1.0)*rad - p);
    vec3 v2 = normalize( vec3(-1.0, 1.0,-1.0)*rad - p);
    vec3 v3 = normalize( vec3( 1.0, 1.0,-1.0)*rad - p);
    vec3 v4 = normalize( vec3(-1.0,-1.0, 1.0)*rad - p);
    vec3 v5 = normalize( vec3( 1.0,-1.0, 1.0)*rad - p);
    vec3 v6 = normalize( vec3(-1.0, 1.0, 1.0)*rad - p);
    vec3 v7 = normalize( vec3( 1.0, 1.0, 1.0)*rad - p);
    
    // 12 edges    
    float k02 = dot( n, normalize( cross(v2,v0)) ) * acos( clamp(dot(v0,v2),-1.0,1.0) );
    float k23 = dot( n, normalize( cross(v3,v2)) ) * acos( clamp(dot(v2,v3),-1.0,1.0) );
    float k31 = dot( n, normalize( cross(v1,v3)) ) * acos( clamp(dot(v3,v1),-1.0,1.0) );
    float k10 = dot( n, normalize( cross(v0,v1)) ) * acos( clamp(dot(v1,v0),-1.0,1.0) );
    float k45 = dot( n, normalize( cross(v5,v4)) ) * acos( clamp(dot(v4,v5),-1.0,1.0) );
    float k57 = dot( n, normalize( cross(v7,v5)) ) * acos( clamp(dot(v5,v7),-1.0,1.0) );
    float k76 = dot( n, normalize( cross(v6,v7)) ) * acos( clamp(dot(v7,v6),-1.0,1.0) );
    float k37 = dot( n, normalize( cross(v7,v3)) ) * acos( clamp(dot(v3,v7),-1.0,1.0) );
    float k64 = dot( n, normalize( cross(v4,v6)) ) * acos( clamp(dot(v6,v4),-1.0,1.0) );
    float k51 = dot( n, normalize( cross(v1,v5)) ) * acos( clamp(dot(v5,v1),-1.0,1.0) );
    float k04 = dot( n, normalize( cross(v4,v0)) ) * acos( clamp(dot(v0,v4),-1.0,1.0) );
    float k62 = dot( n, normalize( cross(v2,v6)) ) * acos( clamp(dot(v6,v2),-1.0,1.0) );
    
    // 6 faces    
    float occ = 0.0;
    occ += ( k02 + k23 + k31 + k10) * step( 0.0,  v0.z );
    occ += ( k45 + k57 + k76 + k64) * step( 0.0, -v4.z );
    occ += ( k51 - k31 + k37 - k57) * step( 0.0, -v5.x );
    occ += ( k04 - k64 + k62 - k02) * step( 0.0,  v0.x );
    occ += (-k76 - k37 - k23 - k62) * step( 0.0, -v6.y );
    occ += (-k10 - k51 - k45 - k04) * step( 0.0,  v0.y );
        
    return occ / 6.2831;
}

//-----------------------------------------------------------------------------------------

mat4 rotationAxisAngle( vec3 v, float angle )
{
    float s = sin( angle );
    float c = cos( angle );
    float ic = 1.0 - c;

    return mat4( v.x*v.x*ic + c,     v.y*v.x*ic - s*v.z, v.z*v.x*ic + s*v.y, 0.0,
                 v.x*v.y*ic + s*v.z, v.y*v.y*ic + c,     v.z*v.y*ic - s*v.x, 0.0,
                 v.x*v.z*ic - s*v.y, v.y*v.z*ic + s*v.x, v.z*v.z*ic + c,     0.0,
			     0.0,                0.0,                0.0,                1.0 );
}

mat4 translate( float x, float y, float z )
{
    return mat4( 1.0, 0.0, 0.0, 0.0,
				 0.0, 1.0, 0.0, 0.0,
				 0.0, 0.0, 1.0, 0.0,
				 x,   y,   z,   1.0 );
}

// http://iquilezles.org/www/articles/checkerfiltering/checkerfiltering.htm
float checkersGradBox( in vec2 p )
{
    // filter kernel
    vec2 w = fwidth(p) + 0.001;
    // analytical integral (box filter)
    vec2 i = 2.0*(abs(fract((p-0.5*w)*0.5)-0.5)-abs(fract((p+0.5*w)*0.5)-0.5))/w;
    // xor pattern
    return 0.5 - 0.5*i.x*i.y;                  
}

#define AA 2

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
     // camera movement	
	float an = 0.4*iTime;
	vec3 ro = vec3( 2.5*cos(an), 1.0, 2.5*sin(an) );
    vec3 ta = vec3( 0.0, 0.8, 0.0 );
    
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv =          ( cross(uu,ww));
    
    // animate box
    mat4 rot = rotationAxisAngle( normalize(vec3(1.0,1.0,0.0)), iTime );
    mat4 tra = translate( 0.0, 1.0, 0.0 );
    mat4 txi = tra * rot; 
    mat4 txx = inverse( txi );
    vec3 box = vec3(0.4,0.6,0.8);

    
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

        // create view ray
        vec3 rd = normalize( p.x*uu + p.y*vv + 2.0*ww );

        // raytrace
        float tmin = 10000.0;
        vec3  nor = vec3(0.0);
        vec3  pos = vec3(0.0);
        vec2  uv = vec2(0.0);

        // raytrace-plane
        float oid = 0.0;
        float h = (0.0-ro.y)/rd.y;
        if( h>0.0 ) 
        { 
            tmin = h; 
            nor = vec3(0.0,1.0,0.0); 
            oid = 1.0;
            pos = ro + rd*h;
            uv = pos.xz;
        }

        // raytrace box
        vec3 bnor;  vec2 buv;
        int outFaceID;
        vec2 tnf;
        if( boxIntersect( ro, rd, txx, txi, box, tnf, bnor, buv, outFaceID) )
        {
            if( tnf.x>0.0 && tnf.x<tmin )
            {
                tmin = tnf.x; 
                nor = bnor;
                uv = buv;
                oid = 2.0;
        	}
        }

        // shading/lighting	
        vec3 col = vec3(0.9);
        if( tmin<100.0 )
        {
            vec3 lig = normalize(vec3(0.3,0.5,0.8));
            pos = ro + tmin*rd;

            // material
            float occ = 1.0;
            vec3  mate = vec3(1.0);
            if( oid<1.5 ) // plane
            {
                mate = vec3(0.6)*(0.8+0.2*checkersGradBox( 2.0*uv ));
                // analytic ambient occlusion
                occ = 1.0-boxOcclusion( pos, nor, txx, txi, box );
            }			
            else // box
            {
                mate = vec3(0.5)*(0.8+0.2*checkersGradBox( 5.0*uv ));
                // fake ambient occlusion
                occ  = 0.5 + 0.5*nor.y;
                occ *= 0.5 + 0.5*clamp(pos.y,0.0,1.0);
            }		


            // lighting
            float dif = clamp( dot(nor,lig), 0.0, 1.0 );
            dif *= boxSoftShadow( pos+0.01*nor, lig, txx, box, 4.0 );
            col = vec3(0.1,0.2,0.3)*occ + 2.0*dif*vec3(1.0,0.8,0.7);

            // material * lighting		
            col *= mate;

            // fog
            col = mix( col, vec3(0.9), 1.0-exp( -0.003*tmin*tmin ) );
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