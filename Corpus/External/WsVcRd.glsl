// WsVcRd - pikmin2010
// https://www.shadertoy.com/view/WsVcRd
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// A list of useful distance function to simple primitives. All
// these functions (except for ellipsoid) return an exact
// euclidean distance, meaning they produce a better SDF than
// what you'd get if you were constructing them from boolean
// operations.
//
// More info here:
//
// https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm

//------------------------------------------------------------------
#define March_Quality 32
#define Shadow_Quality 4
#define AO_Quality 8
#define Lighting 1
#define Epsilon 0.00001
float dot2( in vec2 v ) { return dot(v,v); }
float dot2( in vec3 v ) { return dot(v,v); }
float ndot( in vec2 a, in vec2 b ) { return a.x*b.x - a.y*b.y; }



/**
 * Rotation matrix around the X axis.
 */
mat3 rotateX(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(1, 0, 0),
        vec3(0, c, -s),
        vec3(0, s, c)
    );
}

/**
 * Rotation matrix around the Y axis.
 */
mat3 rotateY(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(c, 0, s),
        vec3(0, 1, 0),
        vec3(-s, 0, c)
    );
}

/**
 * Rotation matrix around the Z axis.
 */
mat3 rotateZ(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(c, -s, 0),
        vec3(s, c, 0),
        vec3(0, 0, 1)
    );
}

float sdSphere( vec3 p, float s )
{
    return length(p)-s;
}

float sdBox( vec3 p, vec3 b )
{
    vec3 d = abs(p) - b;
    return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}


float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
	vec3 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h ) - r;
}


// vertical
float sdCylinder( vec3 p, vec2 h )
{
    vec2 d = abs(vec2(length(p.xz),p.y)) - h;
    return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

// arbitrary orientation
float sdCylinder(vec3 p, vec3 a, vec3 b, float r)
{
    vec3 pa = p - a;
    vec3 ba = b - a;
    float baba = dot(ba,ba);
    float paba = dot(pa,ba);

    float x = length(pa*baba-ba*paba) - r*baba;
    float y = abs(paba-baba*0.5)-baba*0.5;
    float x2 = x*x;
    float y2 = y*y*baba;
    float d = (max(x,y)<0.0)?-min(x2,y2):(((x>0.0)?x2:0.0)+((y>0.0)?y2:0.0));
    return sign(d)*sqrt(abs(d))/baba;
}



//------------------------------------------------------------------

vec2 opU( vec2 d1, vec2 d2 )
{
	return (d1.x<d2.x) ? d1 : d2;
}

vec2 opB( vec2 d1, vec2 d2 )
{
	return (d1.x>d2.x) ? d1 : d2;
}

vec3 opRepLim(  vec3 p,  float c, vec3 l)
{
    vec3 q = p-c*clamp(round(p/c),-l,l);
    return ( q );
}
//------------------------------------------------------------------

#define ZERO (min(iFrame,0))

//------------------------------------------------------------------

vec2 map( in vec3 pos )
{
    pos = opRepLim(pos,3.,vec3(1,1,1));
    pos.y +=0.2;
    pos.y *=0.9;
    vec2 belly = vec2( sdSphere(    pos-vec3(.0,0., 0.2), 0.5 ), 11  );

    vec2 brownBelly = vec2(sdSphere(    pos-vec3(.0,0., 0.0), 0.6), 12  );
    vec2 brownHead = vec2(sdSphere(    pos-vec3(.0,0.6, 0.0), 0.4), 12  );
    vec3 eyePos = pos;
    eyePos.x *=1.3;
    vec2 whiteEyeL = vec2(sdSphere(    eyePos-vec3(.15,0.65, 0.25),0.15), 11  );
    vec2 whiteEyeR = vec2(sdSphere(    eyePos-vec3(-.15,0.65, 0.25), 0.15), 11  );
    vec2 brownEyeL = vec2(sdSphere(    eyePos-vec3(.15,0.73, 0.22),0.15), 12  );
    vec2 brownEyeR = vec2(sdSphere(    eyePos-vec3(-.15,0.73, 0.22), 0.15), 12  );
	vec2 pupilEyeL = vec2(sdSphere(    eyePos-vec3(.15,0.65, 0.37),0.05), 13  );
    vec2 pupilEyeR = vec2(sdSphere(    eyePos-vec3(-.15,0.65, 0.37), 0.05), 13  );
	
    vec3 furPos = pos;
    furPos.x *=0.5;
    
    vec2 mouthFur = vec2(sdSphere( furPos-vec3(0.,0.44,0.35),0.11),11);
    vec2 mouthFur2 = vec2(sdSphere( furPos-vec3(0.,0.5,0.35),0.09),11);
    vec2 mouthFur3 = vec2(sdSphere( furPos-vec3(0.,0.56,0.42),0.04),11);
    vec3 earPos = pos;
    earPos.z *=1.6;
    earPos.x *=1.7;
    earPos.y *=0.5;
    vec2 brownEarL = vec2(sdSphere(earPos-vec3(0.27,0.5,0.),0.25),12);
	vec2 brownEarR = vec2(sdSphere(earPos-vec3(-0.27,0.5,0.),0.25),12);
    vec2 redEarL = vec2(sdSphere(earPos-vec3(0.27,0.5,0.1),0.18),14);
	vec2 redEarR = vec2(sdSphere(earPos-vec3(-0.27,0.5,0.1),0.18),14);
    vec3 mouthPos = pos;
	mouthPos.y -= 0.5;
    mouthPos.z +=0.14;
    vec2 mouthSub = vec2(sdBox(mouthPos-vec3(0,-0.05,.5),vec3(0.1,0.1,0.1)),15);
    vec2 redMouth = vec2(sdSphere(mouthPos-vec3(0.,0.,.5),0.1),15);
	redMouth = opB(redMouth,mouthSub);
    
    vec2 teeth = opU(vec2(sdBox(mouthPos-vec3(0.035,0.031,0.59),vec3(0.025,0.03,0.005)),11),vec2(sdBox(mouthPos-vec3(-0.035,0.031,0.59),vec3(0.025,0.03,0.005)),11));
    
    vec3 feetPos =pos;
    feetPos.y += 0.4;
    feetPos.x *=0.7;
    
    vec2 leftFoot = vec2(sdSphere(feetPos-vec3(-0.30,0,0),0.25),12);
    vec2 rightFoot = vec2(sdSphere(feetPos-vec3(0.30,0,0),0.25),12);
    
    feetPos.y *=1.1;
    vec2 leftFootWhite = vec2(sdSphere(feetPos-vec3(-0.40,-0.05,0),0.25),11);
    vec2 rightFootWhite = vec2(sdSphere(feetPos-vec3(0.40,-0.05,0),0.25),11);
    vec2 feetWhite = opU(leftFootWhite,rightFootWhite);
    vec2 feet = opU(leftFoot,rightFoot);
    feet = opU(feetWhite,feet);
    
    
    vec2 rightArm = vec2(sdCylinder(pos-vec3(0.5,0.25,0.),vec3(0,0,0),vec3(0.5,0,0),0.1),12);      
    vec2 leftArm = vec2(sdCylinder(pos-vec3(-0.5,0.25,0.),vec3(0,0,0),vec3(-0.5,0,0),0.1),12);
	vec2 leftHand = vec2(sdSphere(pos-vec3(-1.0,0.25,0),0.15),11);
    vec2 rightHand = vec2(sdSphere(pos-vec3(1.0,0.25,0),0.15),11);
    
    vec2 res =opU(brownBelly,belly);
    res = opU(res,brownHead);
    res = opU(res,whiteEyeL);
    res = opU(res,whiteEyeR);
    res = opU(res,brownEyeR);
	res = opU(res,brownEyeL);
    res = opU(res,pupilEyeR);
	res = opU(res,pupilEyeL);
    res = opU(res,mouthFur);
    res = opU(res,mouthFur2);
    res = opU(res,mouthFur3);
    res = opU(res,brownEarL);
    res = opU(res,brownEarR);
    res = opU(res,redEarL);
    res = opU(res,redEarR);
    res = opU(res,redMouth);
    res = opU(res,teeth);
	res = opU(res,feet);
    res = opU(res,rightArm);
    res = opU(res,leftArm);
    res = opU(res,leftHand);
    res = opU(res,rightHand);

    return res;
}

vec2 iBox( in vec3 ro, in vec3 rd, in vec3 rad ) 
{
    vec3 m = 1.0/rd;
    vec3 n = m*ro;
    vec3 k = abs(m)*rad;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
	return vec2( max( max( t1.x, t1.y ), t1.z ),
	             min( min( t2.x, t2.y ), t2.z ) );
}

vec2 raycast( in vec3 ro, in vec3 rd )
{
    vec2 res = vec2(-1.0,-1.0);

    float tmin = 1.0;
    float tmax = 20.0;

   
    //else return res;
    
    // raymarch primitives   

        float t = tmin;
        for( int i=0; i<March_Quality && t<tmax; i++ )
        {
            vec2 h = map( ro+rd*t );
            if( abs(h.x)<(Epsilon*t) )
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
    for( int i=ZERO; i<Shadow_Quality; i++ )
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
    for( int i=ZERO; i<AO_Quality; i++ )
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
        
        if(m>=10.){
        if(m<=11.){
         col = vec3(1,1,1);   
        }else if(m<=12.){
         col = vec3(0.45,0.4,0.4);   
        }else if(m<=13.){
            col = vec3(0.,0.,0.);
        }else if(m<=14.){
            col = vec3(0.85,0.54,0.50);
        
        }else if(m<=15.){
            col = vec3(0.75,0.47,0.63);
        }
    
  
            // project pixel footprint into the plane
            vec3 dpdx = ro.y*(rd/rd.y-rdx/rdx.y);
            vec3 dpdy = ro.y*(rd/rd.y-rdy/rdy.y);

        
        
            ks = 0.4;
        }
        if(Lighting ==1){
        // lighting
        float occ = calcAO( pos, nor );
        
		vec3 lin = vec3(0.0);

        // sun
        {
            vec3  lig = normalize( vec3(1.5, 0.8, 0.6) );
            vec3  hal = normalize( lig-rd );
            float dif = clamp( dot( nor, lig ), 0.0, 1.0 );
          //if( dif>0.0001 )
        	      dif *= calcSoftshadow( pos, lig, 0.02, 2.5 );
			float spe = pow( clamp( dot( nor, hal ), 0.0, 1.0 ),16.0);
                  spe *= dif;
                  spe *= 0.04+0.96*pow(clamp(1.0-dot(hal,lig),0.0,1.0),5.0);
            lin += col*2.20*dif*vec3(1.30,1.00,0.70);
            lin +=     5.00*spe*vec3(1.30,1.00,0.70)*ks;
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
        }
        col = mix( col, vec3(0.7,0.7,0.9), 1.0-exp( -0.0001*t*t*t ) );
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
    vec3 ta = vec3( 0., -0., -0. );
    vec3 ro = ta + vec3( 4.5*cos(0.1*time + 7.0*mo.x), 1.3 + 2.0*mo.y, 4.5*sin(0.1*time + 7.0*mo.x) );
    // camera-to-world transformation
    mat3 ca = setCamera( ro, ta, 0.0 );

    vec3 tot = vec3(0.1);

        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;

        // ray direction
        vec3 rd = ca * normalize( vec3(p,2.5) );

         // ray differentials
        vec2 px = (2.0*(fragCoord+vec2(1.0,0.0))-iResolution.xy)/iResolution.y;
        vec2 py = (2.0*(fragCoord+vec2(0.0,1.0))-iResolution.xy)/iResolution.y;
        vec3 rdx = ca * normalize( vec3(px,2.5) );
        vec3 rdy = ca * normalize( vec3(py,2.5) );
        
        // render	
        vec3 col = render( ro, rd, rdx, rdy );

        // gain
        // col = col*3.0/(2.5+col);
        
		// gamma
        col = pow( col, vec3(0.45) );

        tot += col;

    
    fragColor = vec4( tot, 1.0 );
}