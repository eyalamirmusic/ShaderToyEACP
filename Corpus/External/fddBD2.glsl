// fddBD2 - iq
// https://www.shadertoy.com/view/fddBD2
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Ray intersection for quadrics of this particular shape:
//
//  f(x,y,z) = ± a²x² ± b²y² ± c²z² - {-1,0,1} = 0
//
// Note this is NOT a general quadric, it does not handle
// paraboloids. It does however handle hyperboloids, cones and
// ellipsods optimally (as opposed to a general quadric solver),
// and also spheres, cylinders, slabs and so on, in a non-optimal
// way as a bonus (you should use specialized code paths for
// those shapes, do NOT use this). See this shader for paraboloids:
//
// https://www.shadertoy.com/view/sdyfDR
//
// a,b,c,d are the parameters of the shape. a,b,c are inverse
// radii and d is either -1, 0 or 1. See lines 91 to 100.
//
// Sphere                  : a>0, b=a, c=a, d= 1
// Ellipsoid               : a>0, b>0, c>0, d= 1
// Cone                    : a>0, b<0, c>0, d= 0
// Hyperboloid of 1 sheets : a>0, b<0, c>0, d= 1
// Hyperboloid of 2 sheets : a>0, b<0, c>0, d=-1
// Cylinder                : a>0, b=0, c>0, d= 1
// Slab                    : a>0, b=0, c=0, d= 1
// Hyperbolic Cylinder     : a>0, b=0, c<0, d=-1
//
// Note I'm showing symmetric cones and hyperboloids, but
// you can just specify different radii for each axis.
//
//
// List of ray-surface intersectors at 
//     https://www.shadertoy.com/playlist/l3dXRf
// and
//     https://iquilezles.org/articles/intersectors

bool clipped( in vec3 pos, float clipY, float clipZ );

float iQuadricTypeA(         // intersection distance. -1 if no intersection
    in vec3  ro, in vec3 rd, // ray origin and direction
    in vec4  abcd,           // the quadric (see above)
    in float clipY,          // height of clipping volume
    in float clipZ,          // depth  of clipping volume
    out vec3 oNor,           // normal at intersection
    out bool oInside )       // inside/outside identifier
{
    vec3 r2 = abcd.xyz*abs(abcd.xyz); // squared WITH sign
    
    float k2 = dot(rd,rd*r2);
    float k1 = dot(rd,ro*r2);
    float k0 = dot(ro,ro*r2) - abcd.w;
             
    float h = k1*k1 - k2*k0;
    if( h<0.0 ) return -1.0;
    h = sqrt(h) * sign(k2);

    // entry point
    float t = (-k1-h)/k2;
    vec3 pos = ro + t*rd;
    if( t>0.0 && clipped(pos,clipY,clipZ) ) 
    {
        oInside = k2<0.0;
        oNor = normalize(pos*r2);
        return t;
    }

    // exit point
    t = (-k1+h)/k2;
    pos = ro + t*rd;
    if( t>0.0 && clipped(pos,clipY,clipZ) )
    {
        oInside = k2>0.0;
        oNor = normalize(pos*r2);
        return t;
    }

    return -1.0;
}

bool clipped( in vec3 pos, float y, float z )
{
    return abs(pos.y)<y && abs(pos.z)<z;
}

//--------------------------------------------------------

// shapes
const vec4 kShape[10] = vec4[10]( 
  vec4(1.0/1.6, 1.0/1.6,1.0/1.6, 1.0),  // sphere
  vec4(1.0/1.7, 1.0/3.0,1.0/0.9, 1.0),  // ellipsoid
  vec4(1.0/1.0, 0.0,    0.0,     1.0),  // slab
  vec4(1.0/0.8, 0.0,   -1.0/0.8, 0.0),  // cross
  vec4(1.0/0.8, 0.0,   -1.0/0.8,-1.0),  // hyperbolic cylinder
  vec4(1.0/1.6, 0.0,    1.0/1.6, 1.0),  // cylinder
  vec4(1.0/1.6, 0.0,    1.0/0.9, 1.0),  // cylinder
  vec4(1.0/0.6,-1.0/1.2,1.0/0.6, 0.0),  // cone
  vec4(1.0/0.3,-1.0/0.7,1.0/0.3, 1.0),  // hyperboloid of one sheet
  vec4(1.0/0.3,-1.0/0.6,1.0/0.3,-1.0)); // hyperboloid of two sheets
    

// https://iquilezles.org/articles/filterableprocedurals/
float gridTextureGradBox( in vec2 p, in vec2 ddx, in vec2 ddy )
{
	// filter kernel
    vec2 w = max(abs(ddx), abs(ddy)) + 0.01;

	// analytic (box) filtering
    vec2 a = p + 0.5*w;                        
    vec2 b = p - 0.5*w;           
    const float N = 18.0; // grid thickness
    vec2 i = (floor(a)+min(fract(a)*N,1.0)-
              floor(b)-min(fract(b)*N,1.0))/(N*w);
    //pattern
    return (1.0-i.x)*(1.0-i.y);
}

vec2 getUV( in vec3 pos, ivec2 id )
{
    if( id.y==0 && id.x>=2 ) return 11.0*pos.zy;
    
    return vec2(12.0,11.0)*vec2(atan(pos.x,pos.z),pos.y);
}

vec3 getRay( in vec2 p, in vec3 uu, in vec3 vv, in vec3 ww )
{
    return normalize( p.x*uu + p.y*vv + 3.0*ww );
}

#define AA 2

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // clip height
    float clipY = 1.0 + 2.0*smoothstep(-1.0,-0.8,-cos(iTime*6.283185/12.0));

    // camera movement	
    float an1 = 0.4 + 0.9*smoothstep(0.7,0.9,-cos(iTime*6.283185/12.0));
	float an2 = 6.283185*iTime/6.0;
	vec3 ro = 12.0*vec3( cos(an1)*sin(an2), sin(an1), cos(an1)*cos(an2) );
    vec3 ta = vec3( 0.0, 0.0, 0.0 );
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));

    // global normalize coordinates
    vec2 gp = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    
    // viewport
    ivec2 id  = ivec2(vec2(5.0,2.0)*fragCoord/iResolution.xy );
    vec2  res = iResolution.xy/vec2(5.0,2.0);
    vec2  q   = mod(fragCoord,res);
        
    float clipZ = (id.x>=2 && id.y==0) ? 1.4 : 2.0;
    
    // render
    vec3 tot = vec3(0.0);
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (2.0*(q+o)-res)/res.y;
        #else    
        vec2 p = (2.0*q-res)/res.y;
        #endif

	    // create view ray
	    vec3 rd = getRay( p, uu, vv, ww );

        // background
	    vec3 col = vec3(0.08) * (1.0-0.3*length(gp));
        //col += 0.1*cos( float(5*id.y+id.x)+vec3(0,2,4));
 
        // raytrace
        bool isInside = false;
        vec3 nor = vec3(0.0);
        float t = iQuadricTypeA( ro, rd, kShape[5*id.y+id.x], clipY, clipZ, nor, isInside );
        if( t>0.0 )
        {
            vec3 pos = ro + t*rd;


            // material

            vec2 uv = getUV( pos, id );

            // checkerboard pattern
            {
                col = vec3(0.6);
                col += 0.4*smoothstep(-0.01,0.01,cos(uv.x*0.5)*cos(uv.y*0.5)); 
                if( isInside ) col = vec3(1.5,0.6,0.0);
            }
            // grid lines
            {
                #if 0
                // no filtering
                col *= smoothstep(-1.0,-0.98,cos(uv.x))*smoothstep(-1.0,-0.98,cos(uv.y));
                #endif
                #if 0
                // hardware filtering
                uv = 0.5 + uv/6.283185;
                col *= gridTextureGradBox( uv, dFdx(uv), dFdy(uv) );
                #endif
                #if 1
                // software filtering
                // https://iquilezles.org/articles/filteringrm
                vec2 px = vec2(p.x+2.0/res.y,p.y);
                vec2 py = vec2(p.x,p.y+2.0/res.y);
                vec3 rdx = getRay( px, uu, vv, ww );
                vec3 rdy = getRay( py, uu, vv, ww );
                vec3 posx = ro + t*rdx*dot(rd,nor)/dot(rdx,nor);
                vec3 posy = ro + t*rdy*dot(rd,nor)/dot(rdy,nor);
                vec2 uvx = getUV(posx, id);
                vec2 uvy = getUV(posy, id);
                uv  = 0.5 + uv /6.283185;
                uvx = 0.5 + uvx/6.283185;
                uvy = 0.5 + uvy/6.283185;
                col *= gridTextureGradBox( uv, uvx-uv, uvy-uv );
                #endif
            }

            // lighting
            vec3 lig = normalize(vec3(0.7,0.6,0.3));
            vec3 hal = normalize(-rd+lig);
            float dif = clamp( dot(nor,lig), 0.0, 1.0 );
            float amb = clamp( 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0)), 0.0, 1.0 );
            col *= vec3(0.2,0.3,0.4)*amb*2.0 + 0.7*vec3(1.0,0.9,0.7)*dif;
            col += 0.3*pow(clamp(dot(hal,nor),0.0,1.0),32.0)*dif;
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