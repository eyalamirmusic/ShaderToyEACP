// mllGzH - iq
// https://www.shadertoy.com/view/mllGzH
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Intersection of a ray and a wedge.
//
// List of ray-surface intersectors at https://www.shadertoy.com/playlist/l3dXRf
// and https://iquilezles.org/articles/intersectors


// takes:
//  ro,rd = ray origin and direction
//  s     = wedge length, height and width
// returns:
//  .x    = distance to intersection
//  .yzw  = normal at intersection point
vec4 iWedge( in vec3 ro, in vec3 rd, in vec3 s )
{
    // intersect box
    vec3  m  = 1.0/rd;
    vec3  z  = vec3(rd.x>=0.0?1.0:-1.0, rd.y>=0.0?1.0:-1.0, rd.z>=0.0?1.0:-1.0);
    vec3  k  = s*z;
    vec3  t1 = (-ro - k)*m;
    vec3  t2 = (-ro + k)*m;
    float tn = max(max(t1.x, t1.y), t1.z);
    float tf = min(min(t2.x, t2.y), t2.z);
    if( tn>tf ) return vec4(-1.0);

    // boolean with plane
    float k1 = s.y*ro.x - s.x*ro.y;
    float k2 = s.x*rd.y - s.y*rd.x;
    float tp = k1/k2;

    // enable this ONLY if the ray origin can be inside the wedge
    /*
    if( tn<0.0 )
    {
        if( tp>0.0 && tp<tf ) return vec4(tp,normalize(vec3(-s.y,s.x,0.0))); // plane
        if( k1<0.0 )          return vec4(tf,step(t2,vec3(tf))*z); // box
        return vec4(-1.0);
    }
    */

    if( k1>tn*k2 )       return vec4(tn,-step(tn,t1)*z); // box
    if( tp>tn && tp<tf ) return vec4(tp,normalize(vec3(-s.y,s.x,0.0))); // plane
    return vec4(-1.0);
}

vec3 pattern( in vec2 uv )
{
    return vec3(0.6 + 0.4*smoothstep(-0.01,0.01,cos(uv.x*0.5)*cos(uv.y*0.5)))
           *smoothstep(-1.0,-0.98,cos(uv.x))*smoothstep(-1.0,-0.98,cos(uv.y));
}

#define AA 3

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // camera movement	
	float an = 0.2*iTime;
	vec3 ro = vec3( 1.0*sin(an), 0.4*sin(1.6*an), 1.0*cos(an) );
    vec3 ta = vec3( 0.0, 0.01, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
    // wedge
    const vec3 siz = vec3(0.5,0.2,0.4);

    // render
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

	    // ray direction
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

        // background
	    vec3 col = vec3(0.08+0.02*rd.y)*(1.0-0.3*length(p));

        // wedge
        vec4 tnor = iWedge( ro, rd, siz );
        if( tnor.x>0.0 )
        {
            float t = tnor.x;
            vec3  pos = ro + t*rd;
            vec3  nor = tnor.yzw;

            // texture
            vec3 mor = abs(nor);
            vec2 uv = (mor.x>mor.y && mor.x>mor.z) ? pos.yz : 
                      (mor.y>mor.z)                ? pos.zx : 
                                                     pos.xy;
            col = pattern( 47.0*uv );

            // lighting
            vec3  lig = normalize(vec3(0.7,0.6,0.3));
            vec3  hal = normalize(-rd+lig);
            float dif = clamp( dot(nor,lig), 0.0, 1.0 );
            float amb = clamp( 0.6 + 0.4*nor.y, 0.0, 1.0 );
            col *= vec3(0.2,0.3,0.4)*amb + vec3(1.0,0.9,0.7)*dif;
            col += 0.4*pow(clamp(dot(hal,nor),0.0,1.0),12.0)*dif;
        }

        // gamma
        col = sqrt( col );
	
	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // dither to remove banding in the background
    tot += fract(sin(fragCoord.x*vec3(13,17,11)+fragCoord.y*vec3(1,7,5))*158.391832)/255.0;

    fragColor = vec4( tot, 1.0 );
}