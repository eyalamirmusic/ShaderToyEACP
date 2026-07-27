// 3tj3DW - iq
// https://www.shadertoy.com/view/3tj3DW
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Analytic intersection of a sphere f(x,y,z)=x^4+y^4+z^4-r^4=0. I Specialized
// the generic quartic equation solver for the only geometrically valid cases,
// reduced all canceling complex operations, and optimized coefficients.

// List of ray-surface intersectors at https://www.shadertoy.com/playlist/l3dXRf
// and http://iquilezles.org/www/articles/intersectors/intersectors.htm


// f(x,y,z) = x^4 + y^4 + z^4 - ra^4
float iSphere4( in vec3 ro, in vec3 rd, in float ra )
{
    // -----------------------------
    // solve quartic equation
    // -----------------------------
    
    float r2 = ra*ra;
    
    vec3 d2 = rd*rd; vec3 d3 = d2*rd;
    vec3 o2 = ro*ro; vec3 o3 = o2*ro;

    float ka = 1.0/dot(d2,d2);

    float k3 = ka* dot(ro,d3);
    float k2 = ka* dot(o2,d2);
    float k1 = ka* dot(o3,rd);
    float k0 = ka*(dot(o2,o2) - r2*r2);

    // -----------------------------
    // solve cubic
    // -----------------------------

    float c2 = k2 - k3*k3;
    float c1 = k1 + 2.0*k3*k3*k3 - 3.0*k3*k2;
    float c0 = k0 - 3.0*k3*k3*k3*k3 + 6.0*k3*k3*k2 - 4.0*k3*k1;

    float p = c2*c2 + c0/3.0;
    float q = c2*c2*c2 - c2*c0 + c1*c1;
    
    float h = q*q - p*p*p;

    // -----------------------------
    // skip the case of three real solutions for the cubic, which involves four
    // complex solutions for the quartic, since we know this objcet is convex
    // -----------------------------
    if( h<0.0 ) return -1.0;
    
    // one real solution, two complex (conjugated)
    float sh = sqrt(h);

    float s = sign(q+sh)*pow(abs(q+sh),1.0/3.0); // cuberoot
    float t = sign(q-sh)*pow(abs(q-sh),1.0/3.0); // cuberoot
    vec2  w = vec2( s+t,s-t );

    // -----------------------------
    // the quartic will have two real solutions and two complex solutions.
    // we only want the real ones
    // -----------------------------

#if 1
    vec2  v = vec2( w.x+c2*4.0, w.y*sqrt(3.0) )*0.5;
    float r = length(v);
    return -abs(v.y)/sqrt(r+v.x) - c1/r - k3;
#else
    float r = sqrt( c2*c2 + w.x*w.x + 2.0*w.x*c2 - c0 );
    return -sqrt( 3.0*w.y*w.y/(4.0*r+w.x*2.0+c2*8.0)) - c1/r - k3;
#endif    
}

// df/dx,df/dy,df/dx for f(x,y,z) = x^4 + y^4 + z^4 - ra^4
vec3 nSphere4( in vec3 pos )
{
    return normalize( pos*pos*pos );
}

#define AA 2

#define ZERO min(iFrame,0)

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // camera movement	
	float an = 0.5*iTime;
	vec3 ro = vec3( 3.1*cos(an), 1.4, 3.1*sin(an) );
    vec3 ta = vec3( 0.0, 0.0, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));

    
    vec3 tot = vec3(0.0);
    
    #if AA>1
    for( int m=ZERO; m<AA; m++ )
    for( int n=ZERO; n<AA; n++ )
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
	    float t = iSphere4( ro, rd, 1.0 );

        // shading/lighting	
	    vec3 col = vec3(0.08)*(1.0-0.3*length(p)) + 0.02*rd.y;
	    if( t>0.0 && t<100.0 )
	    {
            vec3 pos = ro + t*rd;
		    vec3 nor = nSphere4( pos );
            vec3 lig = normalize(vec3(0.7,0.6,0.3));
            vec3 hal = normalize(-rd+lig);
		    float dif = clamp( dot(nor,lig), 0.0, 1.0 );
		    float amb = clamp( 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0)), 0.0, 1.0 );
#if 0
            col = vec3(0.8);
#else
            const float fr = 3.14159*7.5;
            vec3 uvw = pow(abs(nor),vec3(1.0/3.0));
            //vec3 uvw = pos;
            col = vec3(0.5);
            float w = pow(1.0+dot(nor,rd),3.0);
            col += 0.4*smoothstep(-0.01,0.01,cos(uvw.x*fr*0.5)*cos(uvw.y*fr*0.5)*cos(uvw.z*fr*0.5)); 
            col *= 1.0*smoothstep(-1.0,-0.98+0.2*w,cos(uvw.x*fr))
                      *smoothstep(-1.0,-0.98+0.2*w,cos(uvw.y*fr))
                      *smoothstep(-1.0,-0.98+0.2*w,cos(uvw.z*fr));
#endif      
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
    tot += fract(sin(fragCoord.x*vec3(13,1,11)+fragCoord.y*vec3(1,7,5))*158.391832)/255.0;
    
	fragColor = vec4( tot, 1.0 );
}