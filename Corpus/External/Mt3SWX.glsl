// Mt3SWX - iq
// https://www.shadertoy.com/view/Mt3SWX
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2016 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



// Analytical second derivatibes of value noise and fbm made with it. Used second
// derivatives to compute curvature.


float hash( float n ) { return fract(sin(n)*753.5453123); }

//---------------------------------------------------------------
// return.x = value noise
// return.xyz = derivatives
// out dd     = hessian (second derivatives)
//---------------------------------------------------------------

vec4 noised( in vec3 x, out mat3 dd )
{
    vec3 p = floor(x);
    vec3 w = fract(x);

    // cubic interpolation vs quintic interpolation
#if 0
    vec3 u = w*w*(3.0-2.0*w);
    vec3 du = 6.0*w*(1.0-w);
    vec3 ddu = 6.0 - 12.0*w;
#else
    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);
    vec3 ddu = 60.0*w*(1.0+w*(-3.0+2.0*w));
#endif
    
    
    float n = p.x + p.y*157.0 + 113.0*p.z;
    
    float a = hash(n+  0.0);
    float b = hash(n+  1.0);
    float c = hash(n+157.0);
    float d = hash(n+158.0);
    float e = hash(n+113.0);
	float f = hash(n+114.0);
    float g = hash(n+270.0);
    float h = hash(n+271.0);
	
    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    dd = mat3( ddu.x*(k1 + k4*u.y + k6*u.z + k7*u.y*u.z), 
               du.x*(k4+k7*u.z)*du.y,
               du.x*(k6+k7*u.y)*du.z,
              
               du.y*(k4+k7*u.z)*du.x,
               ddu.y*(k2 + k5*u.z + k4*u.x + k7*u.z*u.x),
               du.y*(k5+k7*u.x)*du.z,
              
               du.z*(k6+k7*u.y)*du.x,
               du.z*(k5+k7*u.x)*du.y,
               ddu.z*(k3 + k6*u.x + k5*u.y + k7*u.x*u.y) );


    return vec4( k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z, 
                 du * vec3( k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                            k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                            k3 + k6*u.x + k5*u.y + k7*u.x*u.y ) );
}

//---------------------------------------------------------------

vec4 sdBox( vec3 p, vec3 b ) // distance and normal
{
    vec3 d = abs(p) - b;
    float x = min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
    vec3  n = step(d.yzx,d.xyz)*step(d.zxy,d.xyz)*sign(p);
    return vec4( x, n );
}

vec4 fbmd( in vec3 x, out mat3 s )
{
    const float scale  = 1.5;

    float a = 0.0;
    float b = 0.5;
	float f = 1.0;
    vec3  d = vec3(0.0);
    s = mat3(0.0);
    for( int i=0; i<3; i++ )
    {
        mat3 dd;
        vec4 n = noised(f*x*scale,dd);
        a += b*n.x;                // accumulate values		
        d += b*n.yzw*f*scale;      // accumulate derivatives
        s += b*dd*f*f*scale*scale; // accumulate second derivative
        b *= 0.5;
        f *= 1.8;
    }

	return vec4( a, d );
}

vec4 map( in vec3 p, out mat3 s )
{
    
    mat3 dd;
	vec4 d1 = fbmd( p, dd );
    d1.x -= 0.33;
	d1.x *= 0.7;
    d1.yzw = 0.7*d1.yzw;
    dd *= 0.7;
    // clip to box
    vec4 d2 = sdBox( p, vec3(1.5) );
    if(d1.x>d2.x)
    {
        s = dd;
        return d1;
    }
    
    
    s = mat3(0.0);
    return d2;
}

// ray-box intersection in box space
vec2 iBox( in vec3 ro, in vec3 rd, in vec3 rad ) 
{
    vec3 m = 1.0/rd;
    vec3 n = m*ro;
    vec3 k = abs(m)*rad;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	if( tN > tF || tF < 0.0) return vec2(-1.0);
	return vec2( tN, tF );
}

// raymarch
vec4 interesect( in vec3 ro, in vec3 rd, out mat3 resS )
{
	vec4 res = vec4(-1.0);
    resS = mat3(0.0);
    // bounding volume    
    vec2 dis = iBox( ro, rd, vec3(1.5) ) ;
    if( dis.y<0.0 ) return res;

    // raymarch
    float tmax = dis.y;
    float t = dis.x;
	for( int i=0; i<128; i++ )
	{
        vec3 pos = ro + t*rd;
        mat3 dd;
		vec4 hnor = map( pos, dd );
        res = vec4(t,hnor.yzw);
        resS = dd;
		if( hnor.x<0.0001 ) break;
		t += hnor.x;
        if( t>tmax ) break;
	}

	if( t>tmax ) res = vec4(-1.0);
	return res;
}


// fibonazzi points in s aphsre, more info:
// http://lgdv.cs.fau.de/uploads/publications/spherical_fibonacci_mapping_opt.pdf
vec3 forwardSF( float i, float n) 
{
    const float PI  = 3.141592653589793238;
    const float PHI = 1.618033988749894848;
    float phi = 2.0*PI*fract(i/PHI);
    float zi = 1.0 - (2.0*i+1.0)/n;
    float sinTheta = sqrt( 1.0 - zi*zi);
    return vec3( cos(phi)*sinTheta, sin(phi)*sinTheta, zi);
}

float calcAO( in vec3 pos, in vec3 nor )
{
	float ao = 0.0;
    for( int i=0; i<32; i++ )
    {
        vec3 ap = forwardSF( float(i), 32.0 );
        float h = hash(float(i));
		ap *= sign( dot(ap,nor) ) * h*0.25;
        mat3 kk;
        ao += clamp( map( pos + nor*0.001 + ap, kk ).x*3.0, 0.0, 1.0 );
    }
	ao /= 32.0;
	
    return clamp( ao*5.0, 0.0, 1.0 );
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (-iResolution.xy + 2.0*fragCoord.xy) / iResolution.y;
   
	// camera anim
    float an = 0.1*iTime;
	vec3 ro = 3.0*vec3( cos(an), 0.8, sin(an) );
	vec3 ta = vec3( 0.0 );
	
    // camera matrix	
	vec3  cw = normalize( ta-ro );
	vec3  cu = normalize( cross(cw,vec3(0.0,1.0,0.0)) );
	vec3  cv = normalize( cross(cu,cw) );
	vec3  rd = normalize( p.x*cu + p.y*cv + 1.7*cw );

	// render
	vec3 col = vec3(0.0);
    mat3 dd;
    vec4 tnor = interesect( ro, rd, dd );
	float t = tnor.x;

    if( t>0.0 )
	{
		vec3  pos = ro + t*rd;
        vec3  nor = normalize(tnor.yzw);
        float occ = calcAO( pos, nor );

        
        vec3 d = tnor.yzw;

        // compute curvature
		mat4 mm = mat4( dd[0].x, dd[0].y, dd[0].z, d.x,
                        dd[1].x, dd[1].y, dd[1].z, d.y,
                        dd[2].x, dd[2].y, dd[2].z, d.z,
                        d.x, d.y, d.z, 0.0 );
		float k = -determinant(mm)/(dot(d,d)*dot(d,d));

        // shape it a bit
        k = sign(k)*pow( abs(k), 1.0/3.0 );
        
        if( k<0.0) col = vec3(1.0,0.7,0.2); else col = vec3(0.2,0.8,1.0); col *= abs(k*0.2);
        if( abs(k)<0.0001 ) col = vec3(0.1);

        col *= occ;
        col *= 0.7 + 0.3*nor.y;
	}

    col = sqrt(col);
	
    fragColor=vec4(col,1.0);
}