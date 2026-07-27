// 3s2SRV - iq
// https://www.shadertoy.com/view/3s2SRV
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Bounding box of a capsule


// Other capsule functions:
//
// Capsule intersection: https://www.shadertoy.com/view/Xt3SzX
// Capsule bounding box: https://www.shadertoy.com/view/3s2SRV
// Capsule distance:     https://www.shadertoy.com/view/Xds3zN
// Capsule occlusion:    https://www.shadertoy.com/view/llGyzG


// Other bounding box functions:
//
// Disk             - 3D BBox : https://www.shadertoy.com/view/ll3Xzf
// Cylinder         - 3D BBox : https://www.shadertoy.com/view/MtcXRf
// Ellipse          - 3D BBox : https://www.shadertoy.com/view/Xtjczw
// Cone             - 3D BBox : https://www.shadertoy.com/view/WdjSRK
// Capsule          - 3D Bbox : https://www.shadertoy.com/view/3s2SRV
// Cubic     Bezier - 2D BBox : https://www.shadertoy.com/view/XdVBWd 
// Quadratic Bezier - 3D BBox : https://www.shadertoy.com/view/ldj3Wh
// Quadratic Bezier - 2D BBox : https://www.shadertoy.com/view/lsyfWc



#define AA 3

struct bound3
{
    vec3 mMin;
    vec3 mMax;
};
    
//---------------------------------------------------------------------------------------
// bounding box for a capsule
//---------------------------------------------------------------------------------------
bound3 CapsuleAABB( in vec3 pa, in vec3 pb, in float ra )
{
    vec3 a = pb - pa;
    
    return bound3( min( pa - ra, pb - ra ),
                   max( pa + ra, pb + ra ) );
}

// http://www.iquilezles.org/www/articles/intersectors/intersectors.htm
float iCapsule( in vec3 ro, in vec3 rd, in vec3 pa, in vec3 pb, in float r )
{
    vec3  ba = pb - pa;
    vec3  oa = ro - pa;

    float baba = dot(ba,ba);
    float bard = dot(ba,rd);
    float baoa = dot(ba,oa);
    float rdoa = dot(rd,oa);
    float oaoa = dot(oa,oa);

    float a = baba      - bard*bard;
    float b = baba*rdoa - baoa*bard;
    float c = baba*oaoa - baoa*baoa - r*r*baba;
    float h = b*b - a*c;
    if( h>=0.0 )
    {
        float t = (-b-sqrt(h))/a;

        float y = baoa + t*bard;
        
        // body
        if( y>0.0 && y<baba ) return t;

        // caps
        vec3 oc = (y<=0.0) ? oa : ro - pb;
        b = dot(rd,oc);
        c = dot(oc,oc) - r*r;
        h = b*b - c;
        if( h>0.0 )
        {
            return -b - sqrt(h);
        }
    }
    return -1.0;
}

// compute normal
vec3 capNormal( in vec3 pos, in vec3 a, in vec3 b, in float r )
{
    vec3  ba = b - a;
    vec3  pa = pos - a;
    float h = clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0);
    return (pa - h*ba)/r;
}


// ray-box intersection
vec2 iBox( in vec3 ro, in vec3 rd, in vec3 cen, in vec3 rad ) 
{
    vec3 m = 1.0/rd;
    vec3 n = m*(ro-cen);
    vec3 k = abs(m)*rad;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
	if( tN > tF || tF < 0.0) return vec2(-1.0);

	return vec2( tN, tF );
}


float hash1( in vec2 p )
{
    return fract(sin(dot(p, vec2(12.9898, 78.233)))*43758.5453);
}

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

        // camera position
        vec3 ro = vec3( -0.5, 0.4, 1.5 );
        vec3 ta = vec3( 0.0, 0.0, 0.0 );
        // camera matrix
        vec3 ww = normalize( ta - ro );
        vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
        vec3 vv = normalize( cross(uu,ww));
        // create view ray
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

        // cylidner animation
        vec3  c_a =  0.2 + 0.3*sin(iTime*vec3(1.11,1.27,1.47)+vec3(2.0,5.0,6.0));
        vec3  c_b = -0.2 + 0.3*sin(iTime*vec3(1.23,1.41,1.07)+vec3(0.0,1.0,3.0));
        float c_ra =  0.3 + 0.2*sin(iTime*1.3+0.5);

        // render
        vec3 col = vec3(0.4)*(1.0-0.3*length(p));

        // raytrace
        float t = iCapsule( ro, rd, c_a, c_b, c_ra );
        float tmin = 1e10;
        if( t>0.0 )
        {
            tmin = t;
            // shading/lighting	
            vec3 pos = ro + t*rd;
            vec3 nor = capNormal( pos, c_a, c_b, c_ra );

            float dif = clamp( dot(nor,vec3(0.5,0.7,0.2)), 0.0, 1.0 );
            float amb = 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0));
            col = sqrt( vec3(0.2,0.3,0.4)*amb + vec3(0.8,0.7,0.5)*dif );
            col *= vec3(1.0,0.75,0.3);
        }


        // compute bounding box of cylinder
        bound3 bbox = CapsuleAABB( c_a, c_b, c_ra );

        // raytrace bounding box
        vec3 bcen = 0.5*(bbox.mMin+bbox.mMax);
        vec3 brad = 0.5*(bbox.mMax-bbox.mMin);
        vec2 tbox = iBox( ro, rd, bcen, brad );
        if( tbox.x>0.0 )
        {
            // back face
            if( tbox.y < tmin )
            {
                vec3 pos = ro + rd*tbox.y;
                vec3 e = smoothstep( brad-0.03, brad-0.02, abs(pos-bcen) );
                float al = 1.0 - (1.0-e.x*e.y)*(1.0-e.y*e.z)*(1.0-e.z*e.x);
                col = mix( col, vec3(0.0), 0.25 + 0.75*al );
            }
            // front face
            if( tbox.x < tmin )
            {
                vec3 pos = ro + rd*tbox.x;
                vec3 e = smoothstep( brad-0.03, brad-0.02, abs(pos-bcen) );
                float al = 1.0 - (1.0-e.x*e.y)*(1.0-e.y*e.z)*(1.0-e.z*e.x);
                col = mix( col, vec3(0.0), 0.15 + 0.85*al );
            }
        }

        // no gamma required here, it's done in line 118

        tot += col;
#if AA>1
    }
    tot /= float(AA*AA);
#endif

    // dithering
    tot += ((hash1(fragCoord.xy)+hash1(fragCoord.yx+13.1))/2.0 - 0.5)/256.0;


	fragColor = vec4( tot, 1.0 );
}