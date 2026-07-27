// 4dKfDV - iq
// https://www.shadertoy.com/view/4dKfDV
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2018 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#define AA 4   // make this 1 is your machine is too slow


//------------------------------------------------------------------

const vec2 torus = vec2(0.5,0.2);

float map( in vec3 p )
{
    return length( vec2(length(p.xz)-torus.x,p.y) )-torus.y;
}

// gradient/derivative of map (common factors removed)
vec3 dmap( in vec3 p )
{
    return p*(1.0 - vec3(1,0,1)*torus.x/length(p.xz));
  //return p*(dot(p,p)-torus.y*torus.y-torus.x*torus.x*vec3(1.0,-1.0,1.0));
}

vec2 castRay( in vec3 ro, in vec3 rd )
{
    // plane
    float tmax = (-torus.y-ro.y)/rd.y;
   
    // torus
    float t = 1.0;
    float m = 2.0;
    for( int i=0; i<100; i++ )
    {
	    float precis = 0.0004*t;
	    float res = map( ro+rd*t );
        if( res<precis || t>tmax ) break;
        t += res;
    }

    if( t>tmax ) { t=tmax; m=1.0; }
    return vec2( t, m );
}


float calcSoftshadow( in vec3 ro, in vec3 rd )
{
	float res = 1.0;
    float t = 0.02;
    for( int i=0; i<12; i++ )
    {
		float h = map( ro + rd*t );
        res = min( res,18.0*h/t );
        t += clamp( h, 0.05, 0.10 );
        if( res<0.005 || t>1.0 ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

vec3 hexagon_pattern( vec2 p ) 
{
	vec2 q = vec2( p.x*2.0*0.5773503, p.y + p.x*0.5773503 );
	
	vec2 pi = floor(q);
	vec2 pf = fract(q);

	float v = mod(pi.x + pi.y, 3.0);

	float ca = step(1.0,v);
	float cb = step(2.0,v);
	vec2  ma = step(pf.xy,pf.yx);
	
	return vec3( pi + ca - cb*ma, dot( ma, 1.0-pf.yx + ca*(pf.x+pf.y-1.0) + cb*(pf.yx-2.0*pf.xy) ) );
}

vec3 render( in vec3 ro, in vec3 rd )
{ 
    vec3  col = vec3(0.0);
    vec2  res = castRay(ro,rd);
    vec3  pos = ro + rd*res.x;
    vec3  nor = vec3(0.0,1.0,0.0);
    float occ = 1.0;

    // plane
    if( res.y<1.5 )
    {
        // fake occlusion
        occ = smoothstep(0.0,0.42, abs(length(pos.xz)-torus.x) );
        // texture
        #if 0
        vec3  h = hexagon_pattern(pos.xz*4.);
        float f = mod(h.x+2.0*h.y,3.0)/2.0 ;
        #else
        float f = float( (int(floor(2.0*pos.x))+int(floor(2.0*pos.z)))&1);
        #endif
        col = vec3(0.3 + f*0.1);
    }
    // torus
    else
    {
        // analytic torus normal
        nor = normalize( dmap(pos) );
        // fake occlusion
        occ = 0.5 + 0.5*nor.y;
        // texture
        vec2 uv = vec2(atan(pos.z,pos.x),atan(length(pos.xz)-torus.x,pos.y) )*
                  vec2(12.0*sqrt(3.0), 8.0)/3.14159;
        uv.y += iTime;
        vec3 h = hexagon_pattern( uv );
        col = vec3( mod(h.x+2.0*h.y,3.0)/2.0 );
        //col = mix(col,vec3(0.0), 1.0-smoothstep(0.02,0.05,h.z)); // aliased
        col = mix(col,vec3(0.0),clamp(1.3*(1.0-smoothstep(0.01*res.x,0.05*res.x,h.z))/res.x,0.0,1.0)); // somehow filtered
    }
    // lighting        
    vec3  lig = normalize( vec3(0.4, 0.5, -0.6) );
    vec3  hal = normalize( lig-rd );
    float amb = clamp( 0.65+0.35*nor.y, 0.0, 1.0 );
    float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
    float bac = clamp( dot( nor, normalize(vec3(-lig.x,0.0,-lig.z))), 0.0, 1.0 );

    dif *= calcSoftshadow( pos, lig );

    float spe = pow( clamp( dot( nor, hal ), 0.0, 1.0 ),32.0) *
                dif *
                (0.04 + 0.96*pow( clamp(1.0+dot(hal,rd),0.0,1.0), 5.0 ));

    vec3 lin = vec3(0.0);
    lin += 1.63*dif*vec3(1.15,0.90,0.55);
    lin += 0.50*amb*vec3(0.30,0.60,1.50)*occ;
    lin += 0.30*bac*vec3(0.40,0.30,0.25)*occ;
    col = col*lin;
    col += 6.00*spe*vec3(1.15,0.90,0.55);

	return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 mo = iMouse.xy/iResolution.xy;

    // camera	
    vec3 ro = vec3( 1.3*cos(0.05*iTime + 6.0*mo.x), 1.1, 1.3*sin(0.05*iTime + 6.0*mo.x) );
    vec3 ta = vec3( 0.0, -0.2, 0.0 );
    // camera-to-world transformation
    vec3 cw = normalize(ta-ro);
    vec3 cu = normalize(vec3(-cw.z,0.0,cw.x));
    vec3 cv =          (cross(cu,cw) );
    
    vec4 tot = vec4(0.0);
	#if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = (vec2(float(m),float(n)) / float(AA-1) - 0.5)*1.7; // 1.7 pixels wide
        vec2 p = (-iResolution.xy + 2.0*(fragCoord+o))/iResolution.y;
		#else    
        vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y;
		#endif

        // ray direction
        vec3 rd = normalize( p.x*cu + p.y*cv + 2.0*cw );

        // render	
        vec3 col = render( ro, rd );

		// gamma (before reconstruction/filtering)
        col = pow( col, vec3(0.4545) );

 		#if AA>1
        // triangular reconstruction filter, kernel 2.0 pixels wide
        float w = clamp(1.0 - length(o)/1.0,0.0,1.0);
        tot.xyz += w*col;
        tot.w += w;
        #else
        tot.xyz = col;
        #endif
	#if AA>1
    }
    tot /= tot.w;
	#endif

    // grading
    tot.xyz = pow(tot.xyz,vec3(0.8,0.9,1.0) );
    
    // vignetting
    vec2 q = fragCoord/iResolution.xy;
    tot.xyz *= 0.3 + 0.7*pow(16.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.25);
    
    fragColor = vec4( tot.xyz, 1.0 );
}