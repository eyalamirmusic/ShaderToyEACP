// WlGfWc - jorge2017a1
// https://www.shadertoy.com/view/WlGfWc
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

//Modificado por jorge2017a1 ----jorgeFloresP


//Referencia de IQ https://www.shadertoy.com/view/wdBXRW
// The MIT License
// Copyright © 2019 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Distance to a regular pentagon, without trigonometric functions. 
//
//
// http://www.iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm

#define Rot(a) mat2(cos(a),-sin(a),sin(a),cos(a))
#define antialiasing(n) n/min(iResolution.y,iResolution.x)
#define S(d,b) smoothstep(antialiasing(1.0),b,d)
#define DF(a,b) length(a) * cos( mod( atan(a.y,a.x)+6.28/(b*8.0), 6.28/((b*8.0)*0.5))+(b-1.)*6.28/(b*8.0) + vec2(0,11) )
#define opU2(d1, d2) ( d1.x < d2.x ? d1 : d2 )


#define saturate(x) clamp(x, 0.0, 1.0)
#define R iResolution.xy
#define ss(a, b, t) smoothstep(a, b, t)
#define SS(U) smoothstep(3./R.y,0.,U)


float opU( float d1, float d2 ) { return  min(d1,d2); }
float opS( float d1, float d2 ) { return max(-d1,d2); }
float opI( float d1, float d2 ) { return max(d1,d2); }

//----------oPeraciones de Repeticion
float opRep1D( float p, float c )
	{ float q = mod(p+0.5*c,c)-0.5*c; return  q ;}
//----------
float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}


float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

////-------------------


float dot2( in vec2 v ) { return dot(v,v); }
float cross2d( in vec2 v0, in vec2 v1) { return v0.x*v1.y - v0.y*v1.x; }

const int N1 =12;




float sdPolygon( in vec2 p, in vec2[N1] v )
{
    const int num = v.length();
    float d = dot(p-v[0],p-v[0]);
    float s = 1.0;
    for( int i=0, j=num-1; i<num; j=i, i++ )
    {
        // distance
        vec2 e = v[j] - v[i];
        vec2 w =    p - v[i];
        vec2 b = w - e*clamp( dot(w,e)/dot(e,e), 0.0, 1.0 );
        d = min( d, dot(b,b) );

        // winding number from http://geomalgorithms.com/a03-_inclusion.html
        bvec3 cond = bvec3( p.y>=v[i].y, 
                            p.y <v[j].y, 
                            e.x*w.y>e.y*w.x );
        if( all(cond) || all(not(cond)) ) s=-s;  
    }
    
    return s*sqrt(d);
}


//vec2[] polygon = vec2[](v0,v1,v2,v3,v4);

vec2 pt1[12]=vec2[](
vec2(.32,.56),
vec2(.24,.32),
vec2(.34,.39),
vec2(.4,.32),
vec2(.43,.39),
vec2(.47,.33),
vec2(.49,.41),
vec2(.55,.3),
vec2(.56,.41),
vec2(.61,.28),
vec2(.59,.56),
vec2(.32,.56)
 );



vec2 rotatev2(vec2 p, float ang)
{
    float c = cos(ang);
    float s = sin(ang);
    return vec2(p.x*c - p.y*s, p.x*s + p.y*c);
}



vec3 CabezaConPelo(vec2 p, vec3 col )
{
    vec2 p2= rotatev2( p, radians(180.0));
    //vec2 p3= rotatev2( p-vec2(0.03,0.10), radians(iTime*10.0));
    vec2 p3= rotatev2( p-vec2(0.03,0.10), radians(185.0));
    
    float d1 = sdPolygon(p2-vec2(-0.4,-0.5), pt1);
    float d2 = sdPolygon(p3-vec2(-0.4,-0.5), pt1);
    
    float s1= sdCircle( p-vec2(-0.05,-0.1), 0.15 );
    
    float boca1= sdBox( p-vec2(-0.01,-0.2), vec2(0.05,0.01) );
    
    float ojo1= sdBox( p-vec2(-0.05,-0.1), vec2(0.02,0.02) );
    float ojo2= sdBox( p-vec2(0.05,-0.1), vec2(0.02,0.02) );
    
    col = mix(col,vec3(1.0, 0.8,0.1)*1.2,S(s1,0.0));
    col = mix(col,vec3(1.0, 0.2,0.1)*1.2,S(d2,0.0));
    col = mix(col,vec3(1.0, 0.2,0.1)*1.2,S(boca1,0.0));
    
    col = mix(col,vec3(0.0, 0.2,0.1)*1.2,S(ojo1,0.0));
    col = mix(col,vec3(0.0, 0.2,0.1)*1.2,S(ojo2,0.0));
    
    
    d1 = SS(d1);
    col=mix(col,vec3(0.0),d1);
    return col;
}
    
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 uv = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    
    float tt=iTime;
    uv=uv*2.0*abs(sin(tt));
    vec2 p=uv*0.5+tt;
    vec2 p2=uv*2.0;
    //-------------------------------
    vec3 col=vec3(1.0);
    
    p.x= opRep1D( p.x, 0.8 );
    p.y= opRep1D( p.y, 0.8 );
    
    p2.x= opRep1D( p2.x, 1.6 );
    p2.y= opRep1D( p2.y, 1.6 );
    
    col= CabezaConPelo(p, col);
    col= CabezaConPelo(p2-vec2(0.5,-0.5), col);
    
    fragColor=vec4(col,1.0);
    

}