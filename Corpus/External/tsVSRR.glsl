// tsVSRR - iq
// https://www.shadertoy.com/view/tsVSRR
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//-------------------------------------------------------

// For a point p in the unit box, return a color
// based on the solutions of the associated cubic
// polynomial. The point p is interprested as the 
// 3 polar angles of a 4D point in a unit sphere,
// and that 4D point maps to a unique cubic
// polynomials a,b,c,d coefficients.
vec3 getColor( in vec3 pb ) // p is in -1..1
{
    vec3 col = vec3(0.0);
    float m = 0.0;

    
    //-------------------------------------------------------
    
    // convert from box space to cannoincal 0..1
    pb = 0.5 + 0.498*pb/vec3(1.0,1.0,2.0); 
    
    pb += vec3(0.5,0.5,0.5);
    
    // convert to 4D polar coordinates with radius=1
    pb *= vec3(3.141593,3.141593,6.283185);
    
    // convert to cartesian 4D
    vec4 ps = vec4( cos(pb.x),
                    sin(pb.x)*cos(pb.y),
                    sin(pb.x)*sin(pb.y)*cos(pb.z),
                    sin(pb.x)*sin(pb.y)*sin(pb.z) );
    
    //-----------------------------
    // make lead coefficient=1
    ps /= ps.x;
    
#if 1
    //-----------------------------
    // compute depressed cubic t^3 + pt + q = 0
    float p = (3.0*ps.z - ps.y*ps.y)/3.0;
    float q = (2.0*ps.y*ps.y*ps.y - 9.0*ps.y*ps.z + 27.0*ps.w)/27.0;
    
    // discriminant
    float h = -4.0*p*p*p - 27.0*q*q;
#else    
    // discriminant
    float h = 18.0*ps.y*ps.z*ps.w - 4.0*ps.y*ps.y*ps.y*ps.w + ps.y*ps.y*ps.z*ps.z - 4.0*ps.z*ps.z*ps.z - 27.0*ps.w*ps.w;
#endif    
    
    if( h<0.0 )
    {
        // 1 real, 2 complex roots. Make it blue, and shade it
        // based on modulo of the roots
        m = -h;//length(vec2(-p.y,sqrt(-h)))*0.5/abs(p.x);
        col = vec3(0.0,0.5,1.0);
    }
    else
    {
        // 3 real roots. Make it yellow if possitive and
        // purple is negative, and shader it based on size
        // of the first root
        m = h;//1.0;//(-p.y-sqrt(h))*0.5/p.x;
        col = vec3(1.0,0.5,0.0);// : vec3(1.0,0.0,0.5);
	}
    
    // discriminant --> geometric mean of root differences
    h = pow(abs(h),1.0/6.0);
    col *= 0.7 + 0.3*smoothstep(-0.1,0.1,sin(abs(12.0*h))); // discriminant isolines
    //col *= h;
    return col;
}

//-------------------------------------------------------

// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
vec4 boxIntersect( in vec3 ro, in vec3 rd, in vec3 cen, in vec3 rad ) 
{
    ro -= cen;
    
	// ray-box intersection in box space
    vec3 m = 1.0/rd;
    vec3 n = m*ro;
    vec3 k = abs(m)*rad;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
	if( tN > tF || tF < 0.0) return vec4(-1.0);

	vec3 nor = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);


	return vec4( tN, nor );
}


// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
float boxShadow( in vec3 ro, in vec3 rd, in vec3 cen, in vec3 rad ) 
{
    ro -= cen;

    vec3 m = 1.0/rd;
    vec3 n = m*ro;
    vec3 k = abs(m)*rad;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	if( tN > tF || tF < 0.0) return -1.0;
	
	return tN;
}

float sdBox( in vec2 p, in vec2 b ) 
{
    vec2 q = abs(p) - b;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0));
}

float iPlane( in vec3 ro, in vec3 rd )
{
    return (0.0 - ro.y)/rd.y;
}

//=====================================================

vec3 plot3D( in vec2 px )
{
    vec2 p = (-iResolution.xy + 2.0*px)/iResolution.y;

    // camera
     // camera movement	
	float an = 0.2*iTime;
	vec3 ro = vec3( 4.0*cos(an), 4.0, 4.0*sin(an) );
    vec3 ta = vec3( 0.0, 0.5, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));

    // create view ray
    vec3 rd = normalize( p.x*uu + p.y*vv + 2.2*ww );
    
    // sphere
    //vec3 box = vec3( 1.0 );
    
    float h = 0.5+0.49995*sin(1.0*iTime);
    //h = 1.0;
    vec3 box_cen = vec3(0.0,h,0.0);
    vec3 box_rad = vec3(1.0,h,2.0);
       

    vec3 col = vec3(0.0);

    // intersect geometry
    float tmin = 1e10;
    vec3 nor;
    float occ = 1.0;
    vec3 mate = vec3(1.0);

    // plane/floor
    float t1 = iPlane( ro, rd );
    if( t1>0.0 )
    {
        tmin = t1;
        vec3 pos = ro + t1*rd;
        nor = vec3(0.0,1.0,0.0);
        occ = 1.0;//-sphOcclusion( pos, nor, sph );
        float d = sdBox( pos.xz, box_rad.xz );
        occ = 0.2 + 0.8*clamp(1.0 - 1.0/(1.0+d*d),0.0,1.0);
            
        mate = vec3(0.2);
    }

    // box
    vec4 t2 = boxIntersect( ro, rd, box_cen, box_rad );
    if( t2.x>0.0 && t2.x<tmin )
    {
        tmin = t2.x;
        vec3 pos = ro + t2.x*rd;
        nor = t2.yzw;
        occ = 0.2+0.8*clamp(pos.y/2.0,0.0,1.0);
        mate = getColor(pos);

        // wireframe
        mate *= 1.0 - (1.0-abs(nor.x))*smoothstep( box_rad.x-0.04, box_rad.x-0.02, abs(pos.x-box_cen.x) );
        mate *= 1.0 - (1.0-abs(nor.y))*smoothstep( box_rad.y-0.04, box_rad.y-0.02, abs(pos.y-box_cen.y) );
        mate *= 1.0 - (1.0-abs(nor.z))*smoothstep( box_rad.z-0.04, box_rad.z-0.02, abs(pos.z-box_cen.z) );
    }

    // apply color and lighting
    if( tmin<1000.0 )
    {
        vec3 pos = ro + tmin*rd;

        vec3 lig = normalize( vec3(0.6,0.2,0.4) );

        float sha = step( boxShadow( pos+0.01*nor, lig, box_cen, box_rad ), 0.0 );

        vec3 lin = vec3(0.0);
        lin += vec3(1.5)*clamp(dot(nor,lig),0.0,1.0)*sha;
        lin += 0.5*occ;
        //lin += 0.5*occ*pow(clamp(1.0+dot(nor,rd),0.0,1.0),3.0);

        col = mate*lin;
        //col = vec3(occ);
        //col = mate;
        // fog
        col *= exp( -0.05*tmin );
    }
    return col;
}

#if HW_PERFORMANCE==0
#define AA 1
#else
#define AA 2   // make this 2 or 3 for antialiasing
#endif

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 p = fragCoord + vec2(float(m),float(n))/float(AA)-0.5;
        #else    
        vec2 p = fragCoord;
        #endif
 
        vec3 col = plot3D(p);

        // gamma correction
        col = pow(col,vec3(0.4545));
        
	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // cheap dithering
    tot += sin(fragCoord.x*114.0)*sin(fragCoord.y*211.1)/512.0;

    fragColor = vec4( tot, 1.0 );
}