// tdKSRR - iq
// https://www.shadertoy.com/view/tdKSRR
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Something I toyed with a decade ago was mapping all possible
// quadratic polynomials to the surface of a sphere:
//
// http://www.iquilezles.org/blog/?p=1089
//
// See also this video: https://www.youtube.com/watch?v=JJYVqviE2Uk
//
// Basically, all possible quadratic equations (parabolas) can be
// mapped to the surface of a sphere. p(x)=ax²+bx+c becomes a point
// (a,b,c) in 3D space, and since all quadratics of the form
// (k·a, k·b, k·c) has the same solutions, all space can be
// collapsed into a unit sphere through vector normalization.
//
// In blue are complex solutions.
// In yellow are real solutions with different signs
// In white are real solutions with same signs
//
// Similar idea, but for cubic equations:
// https://www.shadertoy.com/view/tsVSRR

//-------------------------------------------------------

// For a point in the sphere's surface p, return a color based on
// the solutions of the associate quadratic polynomial
vec3 getColor( in vec3 p )
{
    // rotate the solution space (the sphere mapping)
    float an = 0.5*iTime;
    float si = sin(an), co = cos(an);
    p.xz = mat2(co,-si,si,co)*p.xz;
    
    vec3 col = vec3(0.0);
    float m = 11.0;
    
    // solve quadratic
    float h = p.y*p.y - 4.0*p.x*p.z;
    if( h<0.0 )
    {
        // Complex solution. Make it blue
        col = vec3(0.0,0.5,1.0);
        //m = -h;
        float f = sqrt(abs(p.z/p.x));
        m = 1.0*min(f,1.0/f);
    }
    else
    {
        // Real solution. Yellow if same sign and white if not
        float t1 = (-p.y-sqrt(h))*0.5/p.x;
        float t2 = (-p.y+sqrt(h))*0.5/p.x;
        col = (t1*t2>0.0) ? vec3(1.0,0.9,0.8) : vec3(1.0,0.5,0.1);        
        
        m = 16.0*abs(min(min(abs(    t1),abs(    t2)),
                         min(abs(1.0/t1),abs(1.0/t2))));
	}
    
    
    // shade
    col *= clamp(log(1.0+m),0.0,1.0);

    col *= clamp(log(1.0+16.0*abs(h)),0.0,1.0);
    
    // discriminant isolines
    col *= 0.7 + 0.3*smoothstep(-0.1,0.1,sin(abs(24.0*h)));

#if 0
    //if( abs(p.x-p.z)<0.01 ) col = vec3(1,0,0);

    //if( abs(h-2.0)<0.01 ) col = vec3(1,0,0);
    if( abs(h+2.0)<0.01 ) col = vec3(1,0,0);
    
    if( abs(p.x-0.0)<0.01 ) col = vec3(1,0,0);
    //if( abs(p.y-0.0)<0.01 ) col = vec3(0,1,0);
    if( abs(p.z-0.0)<0.01 ) col = vec3(0,0,1);
    
    if( length(p-vec3( 1, 0, 1)/sqrt(2.0))<0.05 ) col = vec3(0,0,0);
    if( length(p-vec3(-1, 0,-1)/sqrt(2.0))<0.05 ) col = vec3(0,0,0);
    if( length(p-vec3( 1, 0, 0))<0.05 ) col = vec3(0,0,0);
    if( length(p-vec3(-1, 0, 0))<0.05 ) col = vec3(0,0,0);
    if( length(p-vec3( 0, 0, 1))<0.05 ) col = vec3(0,0,0);
    if( length(p-vec3( 0, 0,-1))<0.05 ) col = vec3(0,0,0);
    if( length(p-vec3(1, 2,1)/sqrt(6.0))<0.05 ) col = vec3(0,0,0);
    if( length(p-vec3(1,-2,1)/sqrt(6.0))<0.05 ) col = vec3(0,0,0);
    
    
#endif
    
    return col;
}

//-------------------------------------------------------

float sphIntersect( in vec3 ro, in vec3 rd, in vec4 sph )
{
	vec3 oc = ro - sph.xyz;
	float b = dot( oc, rd );
	float c = dot( oc, oc ) - sph.w*sph.w;
	float h = b*b - c;
	if( h<0.0 ) return -1.0;
	return -b - sqrt( h );
}

float sphSoftShadow( in vec3 ro, in vec3 rd, in vec4 sph, in float k )
{
    vec3 oc = ro - sph.xyz;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - sph.w*sph.w;
    float h = b*b - c;
    return (b>0.0) ? step(-0.0001,c) : smoothstep( 0.0, 1.0, h*k/b );
}    
            
float sphOcclusion( in vec3 pos, in vec3 nor, in vec4 sph )
{
    vec3  r = sph.xyz - pos;
    float l = length(r);
    return dot(nor,r)*(sph.w*sph.w)/(l*l*l);
}

vec3 sphNormal( in vec3 pos, in vec4 sph )
{
    return normalize(pos-sph.xyz);
}

float iPlane( in vec3 ro, in vec3 rd )
{
    return (-1.0 - ro.y)/rd.y;
}

//=====================================================

vec3 plot2D( in vec2 px )
{
    vec2 p = px/iResolution.xy;
    
#if 1
    p.x -= 0.5;
    vec2 a = p.yx*vec2(3.141593, 6.283185);
        
    vec3 q = vec3( cos(a.x),
                   sin(a.x)*cos(a.y),
                   sin(a.x)*sin(a.y) );
#else
    p.y = -0.5 + p.y;
    vec2 a = p*vec2(6.283185,3.141593);
        
    vec3 q = vec3( cos(a.y)*cos(a.x),
        		   sin(a.y),
                   cos(a.y)*sin(a.x) );
#endif    
    
    //if( length(q-vec3(0,1,0))<0.1 ) return vec3(1,0,0);
    
    return getColor(q);    
}

//=====================================================

vec3 plot3D( in vec2 px )
{
    vec2 p = (-iResolution.xy + 2.0*px)/iResolution.y;

    // camera
    vec3 ro = vec3(0.0, 0.0, 3.0 );
    vec3 rd = normalize( vec3(p,-2.0) );

    // sphere
    vec4 sph = vec4( 0.0, 0.0, 0.0, 1.0 );

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
        occ = 1.0-sphOcclusion( pos, nor, sph );
        mate = vec3(0.2);
    }

    // sphere
    float t2 = sphIntersect( ro, rd, sph );
    if( t2>0.0 && t2<tmin )
    {
        tmin = t2;
        vec3 pos = ro + t2*rd;
        nor = sphNormal( pos, sph );
        occ = 0.5 + 0.5*nor.y;
        mate = getColor(nor);
    }

    // apply color and lighting
    if( tmin<1000.0 )
    {
        vec3 pos = ro + tmin*rd;

        vec3 lig = normalize( vec3(0.6,0.3,0.4) );
        float sha = sphSoftShadow( pos, lig, sph, 2.0 );

        vec3 lin = vec3(1.5)*clamp(dot(nor,lig),0.0,1.0)*sha;
        lin += 0.5*occ;
        lin += 0.5*occ*pow(clamp(1.0+dot(nor,rd),0.0,1.0),3.0);

        col = mate*lin;
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
 
        // draw stuff
        vec3 col = (sin(0.7*iTime)<-0.5) ? plot2D(p) : plot3D(p);

        // gamma correction
        col = pow(col,vec3(0.4545));
        
	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // cheap dithering
    tot += sin(fragCoord.x*114.0)*sin(fragCoord.y*211.1)/512.0;

    // output color
    fragColor = vec4( tot, 1.0 );
}