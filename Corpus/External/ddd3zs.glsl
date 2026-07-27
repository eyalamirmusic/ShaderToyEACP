// ddd3zs - iq
// https://www.shadertoy.com/view/ddd3zs
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Closest point on a capped cone. For closest points on other primitives, check
//
//    https://www.shadertoy.com/playlist/wXsSzB


// .x   distance to the cone
// .yzw closest point
vec4 sdcCappedCone(vec3 p, vec3 a, vec3 b, float ra, float rb)
{
    //--------------------------------------
    // 3D to 2D : p.xyz -> (u,v)
    //--------------------------------------
    vec3 pa = p-a;
    vec3 ba = b-a;
    
    float baba = dot(ba,ba);
    float bale = sqrt(baba);
    
    vec3  w = ba/bale;
    float v = dot(pa,w);

    vec3  q = a + w*v;
    vec3  pq = p-q;
    float pqpq = dot(pq,pq);
    float u = sqrt(pqpq);
    
    //--------------------------------------
    // distance and closest in 2D, in (u,v)
    // from https://www.shadertoy.com/view/ddt3Rs
    //--------------------------------------

    float he = 0.5*bale;
    v -= he;


    float sy = (v<0.0)?-1.0:1.0;
    
    vec4 res;

    // top and bottom edges
    {
    float h = min(u,(v<0.0)?ra:rb);
    vec2  c = vec2(h,sy*he);
    vec2  q = vec2(u,v) - c;
    float d = dot(q,q);
    float s = abs(v)-he;
    res = vec4(d,c.x,c.y,s);
    }
    
    // side edge
    {
    vec2  k = vec2(rb-ra,2.0*he);
    vec2  w = vec2(u,v)-vec2(ra,-he);
    float h = clamp(dot(w,k)/dot(k,k),0.0,1.0);
    vec2  c = vec2(ra,-he) + h*k;
    vec2  q = vec2(u,v) - c;
    float d = dot(q,q);
    float s = w.x*k.y - w.y*k.x;
    res = vec4( (d<res.x) ? vec3(d,c.x,c.y) : res.xyz,
                (s>res.w) ?      s          : res.w );
    }
   
    // distance and sign
    res.x = sqrt(res.x)*sign(res.w);
    // closest is in res.yz

    //--------------------------------------
    // 2D to 3D : res.yz -> xyz
    //--------------------------------------

    float d = res.x;
    vec2 cl = vec2(res.y,res.z+he);
    
    return vec4( d, a + w*cl.y + (p-q)*cl.x/u );
}

//------------------------------------------------------------

// https://iquilezles.org/articles/distfunctions
float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
	vec3 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h ) - r;
}

// https://iquilezles.org/articles/distfunctions
float sdSphere( vec3 p, vec3 cen, float rad )
{
    return length(p-cen)-rad;
}

//------------------------------------------------------------
const vec3 pa = vec3(0.4, 0.6, 0.0);
const vec3 pb = vec3(0.0,-0.4, 0.0);
const float ra = 0.2;
const float rb = 0.8;
    
vec2 map( in vec3 pos, bool showSurface, vec3 samplePoint )
{


    // compute closest point to gPoint on the surace of the capsule
    vec3 closestPoint = sdcCappedCone(samplePoint, pa, pb, ra, rb ).yzw;
    
    // point
    vec2 res = vec2( sdSphere( pos, samplePoint, 0.06 ), 1.0 );
    
    // closest point
    {
    float d = sdSphere( pos, closestPoint, 0.06 );
    if( d<res.x ) res = vec2( d, 4.0 );
    }
    
    // object
    if( showSurface )
    {
    float d = sdcCappedCone( pos, pa, pb, ra, rb ).x;
    if( d<res.x ) res =  vec2( d, 5.0 );
    }

    // segment
    {
    float d = sdCapsule( pos, samplePoint, closestPoint, 0.015 );
    if( d<res.x ) res =  vec2( d, 4.0 );
    }
    
    return res;
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal( in vec3 pos, in bool showSurface, vec3 samplePoint )
{
    vec2 e = vec2(1.0,-1.0)*0.5773;
    const float eps = 0.0005;
    return normalize( e.xyy*map( pos + e.xyy*eps, showSurface, samplePoint ).x + 
					  e.yyx*map( pos + e.yyx*eps, showSurface, samplePoint ).x + 
					  e.yxy*map( pos + e.yxy*eps, showSurface, samplePoint ).x + 
					  e.xxx*map( pos + e.xxx*eps, showSurface, samplePoint ).x );
}

// https://iquilezles.org/articles/rmshadows
float calcSoftShadow( vec3 ro, vec3 rd, in bool showSurface, vec3 samplePoint )
{
    float res = 1.0;
    const float tmax = 2.0;
    float t = 0.001;
    for( int i=0; i<64; i++ )
    {
     	float h = map(ro + t*rd, showSurface, samplePoint).x;
        res = min( res, 64.0*h/t );
    	t += clamp(h, 0.01,0.5);
        if( res<-1.0 || t>tmax ) break;
        
    }
    res = max(res,-1.0);
    return 0.25*(1.0+res)*(1.0+res)*(2.0-res); // smoothstep, in [-1,1]
}

#if HW_PERFORMANCE==0
#define AA 1
#else
#define AA 2
#endif

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // pixel coordinates
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (2.0*(fragCoord+o)-iResolution.xy)/iResolution.y;
        // pixel sample
        ivec2 samp = ivec2(fragCoord)*AA + ivec2(m,n);
        // time sample
        float td = 0.5+0.5*sin(fragCoord.x*114.0)*sin(fragCoord.y*211.1);
        float time = iTime - 0.0*0.5*(1.0/60.0)*(td+float(m*AA+n))/float(AA*AA-1);
        #else    
        // pixel coordinates
        vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
        // pixel sample
        ivec2 samp = ivec2(fragCoord);
        // time sample
        float time = iTime;
        #endif

        // make shape transparent
      //bool showSurface = ((samp.x+samp.y)&1)==0;     // 50% opaque
        bool showSurface = ((samp.x&1)+(samp.y&1))!=0; // 75% opaque


        // animate camera
        float an = 0.25*time + 6.283185*iMouse.x/iResolution.x;
        vec3 ro = vec3( 2.0*cos(an), 0.8, 2.0*sin(an) );
        vec3 ta = vec3( 0.0, 0.0, 0.0 );

        // camera matrix
        vec3 ww = normalize( ta - ro );
        vec3 uu = normalize( cross(ww,vec3(0.2,1.0,0.0) ) );
        vec3 vv = normalize( cross(uu,ww));

        // animate point
        vec3 samplePoint = sin(time*0.9*vec3(1.0,1.1,1.2)+vec3(0.0,4.0,5.0));

	    // create view ray
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

        // raycast
        const float tmax = 5.0;
        float t = 0.0;
        float m = -1.0;
        for( int i=0; i<256; i++ )
        {
            vec3 pos = ro + t*rd;
            vec2 hm = map(pos,showSurface,samplePoint);
            m = hm.y;
            if( hm.x<0.0001 || t>tmax ) break;
            t += hm.x;
        }
    
        // shade background
        vec3 col = vec3(0.05)*(1.0-0.2*length(p));
        
        // shade objects
        if( t<tmax )
        {
            // geometry
            vec3  pos = ro + t*rd;
            vec3  nor = calcNormal(pos,showSurface,samplePoint);

            // color
            vec3  mate = 0.55 + 0.45*cos( m + vec3(0.0,1.0,1.5) );
            
            // show distance isolines
            if( abs(m-5.0)<0.5 )
            {
                float dref = sdcCappedCone( samplePoint, pa, pb, ra, rb ).x;
                float dsam = length(pos-samplePoint);
                mate += 0.25*smoothstep(0.8,0.9,sin((dsam-dref)*100.0))*exp2(-12.0*(dsam-dref)*(dsam-dref));
            }
            
            // lighting	
            col = vec3(0.0);
            {
              // key light
              vec3  lig = normalize(vec3(0.3,0.7,0.2));
              float dif = clamp( dot(nor,lig), 0.0, 1.0 );
              if( dif>0.001 ) dif *= calcSoftShadow(pos+nor*0.001,lig,showSurface,samplePoint);
              col += 1.5*mate*vec3(1.0,0.9,0.8)*dif;
            }
            {
              // dome light
              float dif = 0.5 + 0.5*nor.y;
              col += 0.5*mate*vec3(0.2,0.3,0.4)*dif;
            }
        }

        // gamma        
        col = pow( col, vec3(0.4545) );
	    tot += col;
    #if AA>1
    }
    tot /= float(AA*AA);
    #endif

    // cheap dithering
    tot += sin(fragCoord.x*114.0)*sin(fragCoord.y*211.1)/512.0;

	fragColor = vec4( tot, 1.0 );
}