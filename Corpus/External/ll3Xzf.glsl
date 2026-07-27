// ll3Xzf - iq
// https://www.shadertoy.com/view/ll3Xzf
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2016 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



// See http://iquilezles.org/www/articles/diskbbox/diskbbox.htm
//
//
// Analytical computation of the exact bounding box for an arbitrarily oriented disk. 
// It took me a good two hours to find the symmetries and term cancellations that 
// simplified the original monster equation into something pretty compact in its final form.
//
// For a disk of raius r centerd in the origin oriented in the direction n, has extent e:
//
// e = r·sqrt(1-n²)
//
// Derivation and more info in the link above


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
// bounding box for a disk (http://iquilezles.org/www/articles/diskbbox/diskbbox.htm)
//---------------------------------------------------------------------------------------
bound3 DiskAABB( in vec3 cen, in vec3 nor, float rad )  // disk: center, normal, radius
{
    vec3 e = rad*sqrt( 1.0 - nor*nor );
    return bound3( cen-e, cen+e );
}


// ray-disk intersection
float iDisk( in vec3 ro, in vec3 rd,               // ray: origin, direction
             in vec3 cen, in vec3 nor, float rad ) // disk: center, normal, radius
{
	vec3  q = ro - cen;
    float t = -dot(nor,q)/dot(rd,nor);
    if( t<0.0 ) return -1.0;
    vec3 d = q + rd*t;
    if( dot(d,d)>(rad*rad) ) return -1.0;
    return t;
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

    // disk animation
	vec3  disk_center = 0.3*sin(iTime*vec3(1.11,1.27,1.47)+vec3(2.0,5.0,6.0));
	vec3  disk_axis = normalize( sin(iTime*vec3(1.23,1.41,1.07)+vec3(0.0,1.0,3.0)) );
    float disk_radius = 0.4 + 0.2*sin(iTime*1.3+0.5);

    // render
   	vec3 col = vec3(0.4)*(1.0-0.3*length(p));

    // raytrace disk
    float t = iDisk( ro, rd, disk_center, disk_axis, disk_radius );
	float tmin = 1e10;
    if( t>0.0 )
	{
    	tmin = t;
		col = vec3(1.0,0.75,0.3)*(0.7+0.2*abs(disk_axis.y));
	}

    // compute bounding box for disk
    bound3 bbox = DiskAABB( disk_center, disk_axis, disk_radius );

    
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
    tot += ((hash1(fragCoord.xy)+hash1(fragCoord.yx+13.1))/2.0-0.5)/256.0;

	fragColor = vec4( tot, 1.0 );
}