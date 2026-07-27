// Wt2XzK - iq
// https://www.shadertoy.com/view/Wt2XzK
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// This shader shows how to control the velocity of an
// object that is being animated with a sin() function.
//
// When animating something like angle=sin(v*t), with t being
// the time (iTime for example), w is only the (angular) 
// velocity of the object if v is a constant.  Hence, doing 
// v(t) = smoothstep(0,1,t) for exampe will  result in an
// acceleration and a deceleration, which is probably not
// intenteded.
//
// To get the desired behaviour you need to define your v(t),
// integrate it to get w(t), then plug it into the sin:
//
// v(t) = smoothste(0,1,t)      if t<1
// v(t) = 1                     if t>=1
//
// Then you integrate that to get
//
// w(t) = t*t*t*(1.0 - t/2.0)   if t<1
// w(t) = t-0.5                 if t>=1
// 
// Try using the incorrect method below and restarting the
// shader in order to see the difference:


// 0: incorrect method: sin(v(t)*t)
// 1:   correct method: sin(w(t))
#define METHOD 1



// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
vec4 iBox( in vec3 ro, in vec3 rd, in mat4 tx, in vec3 rad ) 
{
	vec3 rdd = (tx*vec4(rd,0.0)).xyz;
	vec3 roo = (tx*vec4(ro,1.0)).xyz;
    vec3 m = 1.0/rdd;
    vec3 n = m*roo;
    vec3 k = abs(m)*rad;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	if( tN > tF || tF < 0.0) return vec4(-1.0);
	vec3 nor = -sign(rdd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
	return vec4( tN, nor );
}

mat4 rotationAxisAngle( vec3 v, float angle )
{
    float s = sin( angle );
    float c = cos( angle );
    float ic = 1.0 - c;
    return mat4( v.x*v.x*ic + c,     v.y*v.x*ic - s*v.z, v.z*v.x*ic + s*v.y, 0.0,
                 v.x*v.y*ic + s*v.z, v.y*v.y*ic + c,     v.z*v.y*ic - s*v.x, 0.0,
                 v.x*v.z*ic - s*v.y, v.y*v.z*ic + s*v.x, v.z*v.z*ic + c,     0.0,
			     0.0,                0.0,                0.0,                1.0 );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy) / iResolution.y;

	vec3 ro = vec3( 0.0, 0.0, 2.2 );
    vec3 rd = normalize( vec3(p.xy,-1.8) );
    
    
    #if METHOD==0
        // WRONG
    	float animation = smoothstep(0.0,1.0,iTime)*iTime;
    #else
        // CORRECT
        float animation = (iTime<1.0) ?
    	    iTime*iTime*iTime*(1.0 - iTime/2.0)
            :
            iTime-0.5;
    #endif
    
	mat4 txi = rotationAxisAngle( normalize(vec3(1.0,1.0,0.0)), 0.5*animation-1.0 );

	vec3 col = vec3(0.1);
		
	const vec3 box = vec3(0.4,0.6,0.8) ;
	vec4 res = iBox( ro, rd, txi, box);
	if( res.x>0.0 )
	{
		vec3 onor = res.yzw;
		vec3 wpos = ro + res.x*rd;
		
	    mat4 txx = inverse( txi );
        vec3 opos = (txi*vec4(wpos,1.0)).xyz;
        vec3 wnor = (txx*vec4(onor,0.0)).xyz;

        col = vec3(1.0,0.5,0.1)*(0.5 + 0.5*wnor.y);
        col *= 1.0 - (1.0-abs(onor.x))*smoothstep( box.x-0.04, box.x-0.02, abs(opos.x) );
        col *= 1.0 - (1.0-abs(onor.y))*smoothstep( box.y-0.04, box.y-0.02, abs(opos.y) );
        col *= 1.0 - (1.0-abs(onor.z))*smoothstep( box.z-0.04, box.z-0.02, abs(opos.z) );
	}
	
	col = sqrt( col );

	fragColor = vec4( col, 1.0 );
}