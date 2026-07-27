// tsBfRD - iq
// https://www.shadertoy.com/view/tsBfRD
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2017 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



// Analytical computation of the exact bounding box for a cubic bezier segment
//
// See http://iquilezles.org/www/articles/bezierbbox/bezierbbox.htm


// Other bounding box functions:
//
// Disk             - 3D BBox : https://www.shadertoy.com/view/ll3Xzf
// Cylinder         - 3D BBox : https://www.shadertoy.com/view/MtcXRf
// Ellipse          - 3D BBox : https://www.shadertoy.com/view/Xtjczw
// Cone boundong    - 3D BBox : https://www.shadertoy.com/view/WdjSRK
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
// bounding box for a bezier (http://iquilezles.org/www/articles/bezierbbox/bezierbbox.htm)
//---------------------------------------------------------------------------------------
bound3 BezierAABB( in vec3 p0, in vec3 p1, in vec3 p2 )
{
    // extremes
    vec3 mi = min(p0,p2);
    vec3 ma = max(p0,p2);

    // p = (1-t)^2*p0 + 2(1-t)t*p1 + t^2*p2
    // dp/dt = 2(t-1)*p0 + 2(1-2t)*p1 + 2t*p2 = t*(2*p0-4*p1+2*p2) + 2*(p1-p0)
    // dp/dt = 0 -> t*(p0-2*p1+p2) = (p0-p1);

    vec3 t = clamp((p0-p1)/(p0-2.0*p1+p2),0.0,1.0);
    vec3 s = 1.0 - t;
    vec3 q = s*s*p0 + 2.0*s*t*p1 + t*t*p2;

    mi = min(mi,q);
    ma = max(ma,q);
    
    return bound3( mi, ma );
}


// ray-ellipse intersection
float iEllipse( in vec3 ro, in vec3 rd,         // ray: origin, direction
             in vec3 c, in vec3 u, in vec3 v )  // disk: center, 1st axis, 2nd axis
{
	vec3 q = ro - c;
	vec3 r = vec3(
        dot( cross(u,v), q ),
		dot( cross(q,u), rd ),
		dot( cross(v,q), rd ) ) / 
        dot( cross(v,u), rd );
    
    return (dot(r.yz,r.yz)<1.0) ? r.x : -1.0;
}


// ray-box intersection (simplified)
vec2 iBox( in vec3 ro, in vec3 rd, in vec3 cen, in vec3 rad ) 
{
	// ray-box intersection in box space
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

float length2( in vec3 v ) { return dot(v,v); }

vec3 iSegment( in vec3 ro, in vec3 rd, in vec3 a, in vec3 b )
{
	vec3 ba = b - a;
	vec3 oa = ro - a;
	
	float oad  = dot( oa, rd );
	float dba  = dot( rd, ba );
	float baba = dot( ba, ba );
	float oaba = dot( oa, ba );
	
	vec2 th = vec2( -oad*baba + dba*oaba, oaba - oad*dba ) / (baba - dba*dba);
	
	th.x = max(   th.x, 0.0 );
	th.y = clamp( th.y, 0.0, 1.0 );
	
	vec3 p =  a + ba*th.y;
	vec3 q = ro + rd*th.x;
	
	return vec3( th, length2( p-q ) );
    
}


float iBezier( in vec3 ro, in vec3 rd, in vec3 p0, in vec3 p1, in vec3 p2, in float width)
{
    const int kNum = 50;
    
    float hit = -1.0;
    float res = 1e10;
    vec3 a = p0;
    for( int i=1; i<kNum; i++ )
    {
        float t = float(i)/float(kNum-1);
        vec3 b = mix(mix(p0,p1,t),mix(p1,p2,t),t);
        vec3 r = iSegment( ro, rd, a, b );
        if( r.z<width*width )
        {
            res = min( res, r.x );
            hit = 1.0;
        }
        a = b;
    }
    
    return res*hit;
    
    
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

    // bezier animation
    float time = iTime*0.5;
    vec3 p0 = vec3(0.8,0.6,0.8)*sin( time*0.7 + vec3(3.0,1.0,2.0) );
    vec3 p1 = vec3(0.8,0.6,0.8)*sin( time*1.1 + vec3(0.0,6.0,1.0) );
    vec3 p2 = vec3(0.8,0.6,0.8)*sin( time*1.3 + vec3(4.0,2.0,3.0) );
	float thickness = 0.01;
        
    // render
   	vec3 col = vec3(0.4)*(1.0-0.3*length(p));

    // raytrace bezier
    float t = iBezier( ro, rd, p0, p1, p2, thickness);
	float tmin = 1e10;
    if( t>0.0 )
	{
    	tmin = t;
		col = vec3(1.0,0.75,0.3);
	}

    // compute bounding box for bezier
    bound3 bbox = BezierAABB( p0, p1, p2 );
    bbox.mMin -= thickness;
    bbox.mMax += thickness;

    
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
	
        tot += col;
#if AA>1
    }
    tot /= float(AA*AA);
#endif

    // dithering
    tot += ((hash1(fragCoord.xy)+hash1(fragCoord.yx+13.1))/2.0-0.5)/256.0;

	fragColor = vec4( tot, 1.0 );
}