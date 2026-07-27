// wlyBWm - PauloFalcao
// https://www.shadertoy.com/view/wlyBWm
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// Smooth Repetition
// by @paulofalcao
//
// CC0 1.0 Universal https://creativecommons.org/publicdomain/zero/1.0/
//
// Twitter: @paulofalcao
// https://twitter.com/paulofalcao/status/1365726720695934979
//
// YouTube playing with this and Material Maker
// https://www.youtube.com/watch?v=HoAQ7DFRzQE
//
// I was using smooth abs p=sqrt(p*p+a) introduced by omeometo
// at https://shadertoy.com/view/wljXzh
// and iteratively doing smooth abs and translations
// the number of objects is exponencial
//
// But it's possible to use asin(sin(x)*S) with S between 0 and 1 
// like blackle said in the comments!
// Creates infinite repetitions and it's even faster! :)
// Change asin_sin_mode to true to use this mode (this is now the default mode)
//
// Using IQ "Raymarching - Primitives" as sandbox
// https://www.shadertoy.com/view/Xds3zN
//

#define asin_sin_mode true

//Change asin_sin_mode to true to use this mode (default)
//blackle mode asin(sin(x)*S) with S between 0 and 1 (higher values less smooth)
vec2 smoothrepeat_asin_sin(vec2 p,float smooth_size,float size){
    p/=size;
    p=asin(sin(p)*(1.0-smooth_size));
    return p*size;
}

//Change asin_sin_mode to false to use this mode
//6 iterations create 2^6 objects for each axis
#define smoothrepeat_iterations 6
vec2 smoothrepeat(vec2 p,float smooth_size,float size){
    size/=2.0;
    float w=pow(2.0,float(smoothrepeat_iterations));
	for(int i=0;i<smoothrepeat_iterations;i++){
        p=sqrt(p*p+smooth_size);//smooth abs
		p-=size*w;//translate
		w=w/2.0;
	}
	return p;
}


//
// The code from now on is the same as IQ "Raymarching - Primitives"
// with minor modifications and different map function
// https://www.shadertoy.com/view/Xds3zN
//

#if HW_PERFORMANCE==1
#define AA 1
#else
#define AA 2   // make this 2 or 3 for antialiasing
#endif

//------------------------------------------------------------------
// PRIMITIVES
//------------------------------------------------------------------

float sdPlane( vec3 p )
{
	return p.y;
}

float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdTorus( vec3 p, vec2 t )
{
    return length( vec2(length(p.xz)-t.x,p.y) )-t.y;
}


//------------------------------------------------------------------

vec2 opU( vec2 d1, vec2 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

vec2 rot(vec2 p, float r) {
	float s=sin(r);float c=cos(r);
	return p*mat2(c,-s,s,c);
}

//------------------------------------------------------------------

#define ZERO (min(iFrame,0))

//------------------------------------------------------------------

vec2 map( in vec3 pos )
{
    vec2 res = vec2( 1e10, 0.0 );

    {

      float sm=(smoothstep(0.0,1.0,sin(iTime)+0.5)-0.5)*0.01+0.005;
      float dist=sin(iTime*0.35)*0.2+0.3;
      
      if (asin_sin_mode){
          pos.xz=smoothrepeat_asin_sin(pos.xz,sm*10.0,dist);
      } else {
          pos.xz=smoothrepeat(pos.xz,sm,dist);
      }

      
      pos.xz=rot(pos.xz,sin(iTime*0.5));
      pos.xy=rot(pos.xy,sin(iTime*0.7)*0.4);
      pos.yz=rot(pos.yz,sin(iTime)*0.3);

      pos-=vec3(0.0,0.2, 0.0);
      float b=sdRoundBox( pos, vec3(0.4,0.02,0.1),0.02);
      
      res = opU( res, vec2(b ,1.5) );
    }

    
    return res;
}

vec2 raycast( in vec3 ro, in vec3 rd )
{
    vec2 res = vec2(-1.0,-1.0);

    float tmin = 0.1;
    float tmax = 20.0;

    // raytrace floor plane
    float tp1 = (0.0-ro.y)/rd.y;
    if( tp1>0.0 )
    {
        tmax = min( tmax, tp1 );
        res = vec2( tp1, 1.0 );
    }
    //else return res;
    

    float t = tmin;
    for( int i=0; i<70 && t<tmax; i++ )
    {
        vec2 h = map( ro+rd*t );
        if( abs(h.x)<(0.0001*t) )
        { 
            res = vec2(t,h.y); 
            break;
        }
        t += h.x;
    }
    
    return res;
}

// http://iquilezles.org/www/articles/rmshadows/rmshadows.htm
float calcSoftshadow( in vec3 ro, in vec3 rd, in float mint, in float tmax )
{
    // bounding volume
    float tp = (0.8-ro.y)/rd.y; if( tp>0.0 ) tmax = min( tmax, tp );

    float res = 1.0;
    float t = mint;
    for( int i=ZERO; i<24; i++ )
    {
		float h = map( ro + rd*t ).x;
        float s = clamp(8.0*h/t,0.0,1.0);
        res = min( res, s*s*(3.0-2.0*s) );
        t += clamp( h, 0.02, 0.2 );
        if( res<0.004 || t>tmax ) break;
    }
    return clamp( res, 0.0, 1.0 );
}

// http://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
vec3 calcNormal( in vec3 pos )
{
#if 0
    vec2 e = vec2(1.0,-1.0)*0.5773*0.0005;
    return normalize( e.xyy*map( pos + e.xyy ).x + 
					  e.yyx*map( pos + e.yyx ).x + 
					  e.yxy*map( pos + e.yxy ).x + 
					  e.xxx*map( pos + e.xxx ).x );
#else
    // inspired by tdhooper and klems - a way to prevent the compiler from inlining map() 4 times
    vec3 n = vec3(0.0);
    for( int i=ZERO; i<4; i++ )
    {
        vec3 e = 0.5773*(2.0*vec3((((i+3)>>1)&1),((i>>1)&1),(i&1))-1.0);
        n += e*map(pos+0.0005*e).x;
      //if( n.x+n.y+n.z>100.0 ) break;
    }
    return normalize(n);
#endif    
}

float calcAO( in vec3 pos, in vec3 nor )
{
	float occ = 0.0;
    float sca = 1.0;
    for( int i=ZERO; i<5; i++ )
    {
        float h = 0.01 + 0.12*float(i)/4.0;
        float d = map( pos + h*nor ).x;
        occ += (h-d)*sca;
        sca *= 0.95;
        if( occ>0.35 ) break;
    }
    return clamp( 1.0 - 3.0*occ, 0.0, 1.0 ) * (0.5+0.5*nor.y);
}

// http://iquilezles.org/www/articles/checkerfiltering/checkerfiltering.htm
float checkersGradBox( in vec2 p, in vec2 dpdx, in vec2 dpdy )
{
    // filter kernel
    vec2 w = abs(dpdx)+abs(dpdy) + 0.001;
    // analytical integral (box filter)
    vec2 i = 2.0*(abs(fract((p-0.5*w)*0.5)-0.5)-abs(fract((p+0.5*w)*0.5)-0.5))/w;
    // xor pattern
    return 0.5 - 0.5*i.x*i.y;                  
}

vec3 render( in vec3 ro, in vec3 rd, in vec3 rdx, in vec3 rdy )
{ 
    // background
    vec3 col = vec3(0.7, 0.7, 0.9) - max(rd.y,0.0)*0.3;
    
    // raycast scene
    vec2 res = raycast(ro,rd);
    float t = res.x;
	float m = res.y;
    if( m>-0.5 )
    {
        vec3 pos = ro + t*rd;
        vec3 nor = (m<1.5) ? vec3(0.0,1.0,0.0) : calcNormal( pos );
        vec3 ref = reflect( rd, nor );
        
        // material        
        col = 0.2 + 0.2*sin( m*2.0 + vec3(0.0,1.0,2.0) );
        float ks = 1.0;
        
        if( m<1.5 )
        {
            // project pixel footprint into the plane
            vec3 dpdx = ro.y*(rd/rd.y-rdx/rdx.y);
            vec3 dpdy = ro.y*(rd/rd.y-rdy/rdy.y);

            float f = checkersGradBox( 3.0*pos.xz, 3.0*dpdx.xz, 3.0*dpdy.xz );
            col = 0.15 + f*vec3(0.05);
            ks = 0.4;
        }

        // lighting
        float occ = calcAO( pos, nor );
        
		vec3 lin = vec3(0.0);

        // sun
        {
            vec3  lig = normalize( vec3(-0.5, 0.4, -0.6) );
            vec3  hal = normalize( lig-rd );
            float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
          //if( dif>0.0001 )
        	      dif *= calcSoftshadow( pos, lig, 0.02, 2.5 );
			float spe = pow( clamp( dot( nor, hal ), 0.0, 1.0 ),16.0);
                  spe *= dif;
                  spe *= 0.04+0.96*pow(clamp(1.0-dot(hal,lig),0.0,1.0),5.0);
            lin += col*2.20*dif*vec3(1.30,1.00,0.70);
            lin +=     10.00*spe*vec3(1.30,1.00,0.70)*ks;
        }
        // sky
        {
            float dif = sqrt(clamp( 0.5+0.5*nor.y, 0.0, 1.0 ));
                  dif *= occ;
            float spe = smoothstep( -0.2, 0.2, ref.y );
                  spe *= dif;
                  spe *= 0.04+0.96*pow(clamp(1.0+dot(nor,rd),0.0,1.0), 5.0 );
          //if( spe>0.001 )
                  spe *= calcSoftshadow( pos, ref, 0.02, 2.5 );
            lin += col*0.60*dif*vec3(0.40,0.60,1.15);
            lin +=     2.00*spe*vec3(0.40,0.60,1.30)*ks;
        }
        // back
        {
        	float dif = clamp( dot( nor, normalize(vec3(0.5,0.0,0.6))), 0.0, 1.0 )*clamp( 1.0-pos.y,0.0,1.0);
                  dif *= occ;
        	lin += col*0.55*dif*vec3(0.25,0.25,0.25);
        }
        // sss
        {
            float dif = pow(clamp(1.0+dot(nor,rd),0.0,1.0),2.0);
                  dif *= occ;
        	lin += col*0.25*dif*vec3(1.00,1.00,1.00);
        }
        
		col = lin;

        col = mix( col, vec3(0.7,0.7,0.9), 1.0-exp( -0.001*t*t*t ) );
    }

	return vec3( clamp(col,0.0,1.0) );
}

mat3 setCamera( in vec3 ro, in vec3 ta, float cr )
{
	vec3 cw = normalize(ta-ro);
	vec3 cp = vec3(sin(cr), cos(cr),0.0);
	vec3 cu = normalize( cross(cw,cp) );
	vec3 cv =          ( cross(cu,cw) );
    return mat3( cu, cv, cw );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 mo = iMouse.xy/iResolution.xy;
	float time = 32.0 + iTime*1.5;

    // camera	
    vec3 ta = vec3( 0, 0, 0 );
    
    vec3 ro = ta + vec3( 4.5*cos(0.1*time + 7.0*mo.x), 1.0 + 4.0*mo.y, 4.5*sin(0.1*time + 7.0*mo.x) );
    // camera-to-world transformation
    mat3 ca = setCamera( ro, ta, 0.0 );

    vec3 tot = vec3(0.0);
#if AA>1
    for( int m=ZERO; m<AA; m++ )
    for( int n=ZERO; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (2.0*(fragCoord+o)-iResolution.xy)/iResolution.y;
#else    
        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
#endif

        // focal length
        const float fl = 2.5;
        
        // ray direction
        vec3 rd = ca * normalize( vec3(p,fl) );

         // ray differentials
        vec2 px = (2.0*(fragCoord+vec2(1.0,0.0))-iResolution.xy)/iResolution.y;
        vec2 py = (2.0*(fragCoord+vec2(0.0,1.0))-iResolution.xy)/iResolution.y;
        vec3 rdx = ca * normalize( vec3(px,fl) );
        vec3 rdy = ca * normalize( vec3(py,fl) );
        
        // render	
        vec3 col = render( ro, rd, rdx, rdy );

        // gain
        // col = col*3.0/(2.5+col);
        
		// gamma
        col = pow( col, vec3(0.4545) );

        tot += col;
#if AA>1
    }
    tot /= float(AA*AA);
#endif
    
    fragColor = vec4( tot, 1.0 );
}