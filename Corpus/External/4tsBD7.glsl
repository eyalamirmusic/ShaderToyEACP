// 4tsBD7 - iq
// https://www.shadertoy.com/view/4tsBD7
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Ray-disk intersection. For general planar shapes, please see the
// "coord system intersector" at https://www.shadertoy.com/view/lsfGDB
//
//
// List of other ray-surface intersectors:
//    https://www.shadertoy.com/playlist/l3dXRf
// and 
//    http://iquilezles.org/www/articles/intersectors/intersectors.htm


// disk: center c, normal n, radius r
float diskIntersect( in vec3 ro, in vec3 rd, vec3 c, vec3 n, float r )
{
	vec3  o = ro - c;
    float t = -dot(n,o)/dot(rd,n);
    vec3  q = o + rd*t;
    return (dot(q,q)<r*r) ? t : -1.0;
}

// disk: center c, normal n, radius r
float diskIntersectWithBackFaceCulling( in vec3 ro, in vec3 rd, vec3 c, vec3 n, float r )
{
    float d = dot(rd,n);
    if( d>0.0 ) return -1.0;
	vec3  o = ro - c;
    float t = -dot(n,o)/d;
    vec3  q = o + rd*t;
    return (dot(q,q)<r*r) ? t : -1.0;
}


#if HW_PERFORMANCE==0
#define AA 1
#else
#define AA 2
#endif

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
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

        // camera
        vec3 ro = 1.5*vec3(cos(0.15*iTime),0.0,sin(0.15*iTime));
        vec3 ta = vec3(0.0,0.0,0.0);
        // camera matrix
        vec3 ww = normalize( ta - ro );
        vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
        vec3 vv = normalize( cross(uu,ww));
        // create view ray
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.0*ww );

        // render background
        vec3 col = vec3(0.08)*(1.0-0.3*length(p)) + 0.02*rd.y;

        // render disks (raycast them)
        const int num = 64;  // number of disks

        float tmin = 1e20;
        vec3  onor = vec3(0.0);
        for( int i=0; i<num; i++ )
        {
            // fibonacci points on a sphere
            const float kInvPhi = (sqrt(5.0)-1.0)/2.0; // one over golden ratio
            float cb = 1.0-2.0*(float(i)+0.5)/float(num);
            float sb = sqrt(1.0-cb*cb);
            float aa = 6.283185*kInvPhi*float(i);
            vec3  cen = vec3( sb*sin(aa), sb*cos(aa), cb );

            // orient disk tangent to sphere surface
            vec3  nor = normalize(cen);

            // for full coverage, each disk's area should be 4PI/num,
            // ie, their radius should be 2/sqrt(num)
            float rad = (2.0/sqrt(float(num))); 
            // but we only want partial coverage, for aesthetic reasons
            rad *= 0.5;

            // test for intersection with disk
            float t = diskIntersect( ro, rd, cen, nor, rad );

            // trak intersections
            if( t>0.0 && t<tmin ) 
            {
                tmin = t;
                onor = nor;
            }
        }

        // shade disk, if one found
        if( tmin<1000.0 )
        {
            float dif = clamp( dot(onor,vec3(0.8,0.6,0.4)), 0.0, 1.0 );
            float amb = 0.5 + 0.5*onor.y;
            col = vec3(0.2,0.3,0.4)*amb + vec3(0.8,0.75,0.6)*dif;
        }

        // gamma        
        col = sqrt( col );
        
	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // dither to remove banding in the background
    tot += fract(sin(fragCoord.x*vec3(13,1,11)+fragCoord.y*vec3(1,7,5))*158.391832)/255.0;

	fragColor = vec4( tot, 1.0 );
}