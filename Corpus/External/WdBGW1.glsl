// WdBGW1 - yasuo
// https://www.shadertoy.com/view/WdBGW1
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2014 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Code is based on: https://www.shadertoy.com/view/MlGcDz

#define matRotateX(rad) mat3(1,0,0,0,cos(rad),-sin(rad),0,sin(rad),cos(rad))
#define matRotateY(rad) mat3(cos(rad),0,-sin(rad),0,1,0,sin(rad),0,cos(rad))

// data from my modeling data.
const int numVertices = 60;
const int numFaces = 42;

const float vertices[60] = float[](
    1.013484,-0.004748,-0.170576,1.363493,-0.372823,-1.554794,0.917013,-0.178702,-0.862685,1.288280,-0.178702,-0.862685,1.350874,-0.372823,1.669797,1.010963,-0.004748,0.212469,0.914492,-0.178702,0.904577,1.285759,-0.178702,0.904577,0.581273,-0.024900,0.352901,1.127463,-0.024900,0.352901,1.146371,0.728927,1.492630,0.581273,-0.023149,-0.350895,1.127463,-0.023149,-0.350895,1.146371,0.730678,-1.392582,1.000000,-0.010163,0.363769,1.000000,-0.002439,-0.369747,-1.000000,0.000000,0.006199,0.830098,0.325427,-0.003099,0.862253,-0.223150,0.009298,1.247514,-0.006511,0.004402
);

const int faces[42] = int[](
    3,4,2,1,4,3,7,8,6,5,8,7,9,10,11,12,13,14,17,15,18,18,20,16,15,17,19,16,17,18,19,17,16,16,20,19,19,20,15,20,18,15
);

const int numVertices2 = 60;
const int numFaces2 = 69;

const float vertices2[60] = float[](
-0.050644,-1.000000,-0.287185,-0.046908,-1.000000,0.282374,-0.022325,1.000000,-0.603118,0.252637,-0.756947,0.001045,0.086070,-0.554094,0.470331,0.080405,-0.581953,-0.393294,-0.310284,-0.550998,-0.745497,-0.299836,-0.538616,0.847426,0.301236,-0.464652,0.021582,-0.203997,0.661104,-0.847783,0.081116,0.650054,-0.284954,0.155316,0.606239,-0.650704,0.163361,0.764587,-0.622910,-0.191163,0.699229,0.950683,0.172071,0.792447,0.705030,0.085968,0.690296,0.454854,0.166343,0.645718,0.705368,-0.012304,0.995923,0.721267,0.357289,0.557239,0.010229,0.082718,1.115938,0.002954
);

const int faces2[69] = int[](
3,11,13,12,11,9,2,5,8,2,4,5,4,1,6,4,2,1,6,1,7,6,7,10,11,3,19,8,5,14,18,14,15,14,5,9,14,9,17,9,10,12,10,9,6,11,19,9,19,16,9,3,20,19,18,16,19,16,17,9,20,18,19,3,13,10,18,15,16
);

// Triangle intersection. Returns { t, u, v }
// http://iquilezles.org/www/articles/intersectors/intersectors.htm
vec3 triIntersect( in vec3 ro, in vec3 rd, in vec3 v0, in vec3 v1, in vec3 v2 )
{
    vec3 v1v0 = v1 - v0;
    vec3 v2v0 = v2 - v0;
    vec3 rov0 = ro - v0;

#if 0
    // Cramer's rule for solcing p(t) = ro+t·rd = p(u,v) = vo + u·(v1-v0) + v·(v2-v1)
    float d = 1.0/determinant(mat3(v1v0, v2v0, -rd ));
    float u =   d*determinant(mat3(rov0, v2v0, -rd ));
    float v =   d*determinant(mat3(v1v0, rov0, -rd ));
    float t =   d*determinant(mat3(v1v0, v2v0, rov0));
#else
    // The four determinants above have lots of terms in common. Knowing the changing
    // the order of the columns/rows doesn't change the volume/determinant, and that
    // the volume is dot(cross(a,b,c)), we can precompute some common terms and reduce
    // it all to:
    vec3  n = cross( v1v0, v2v0 );
    vec3  q = cross( rov0, rd );
    float d = 1.0/dot( rd, n );
    float u = d*dot( -q, v2v0 );
    float v = d*dot(  q, v1v0 );
    float t = d*dot( -n, rov0 );
#endif    

    if( u<0.0 || v<0.0 || (u+v)>1.0 ) t = -1.0;
    
    return vec3( t, u, v );
}

// http://iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
vec4 iBox( in vec3 ro, in vec3 rd, in mat4 txx, in mat4 txi, in vec3 rad ) 
{
    // convert from ray to box space
	vec3 rdd = (txx*vec4(rd,0.0)).xyz;
	vec3 roo = (txx*vec4(ro,1.0)).xyz;

	// ray-box intersection in box space
    vec3 m = 1.0/rdd;
    vec3 n = m*roo;
    vec3 k = abs(m)*rad;
	
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

	float tN = max( max( t1.x, t1.y ), t1.z );
	float tF = min( min( t2.x, t2.y ), t2.z );
	
	if( tN > tF || tF < 0.0) return vec4(-1.0);

	vec3 nor = -sign(rdd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);

    // convert to ray space
	
	nor = (txi * vec4(nor,0.0)).xyz;

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

mat4 translate( float x, float y, float z )
{
    return mat4( 1.0, 0.0, 0.0, 0.0,
				 0.0, 1.0, 0.0, 0.0,
				 0.0, 0.0, 1.0, 0.0,
				 x,   y,   z,   1.0 );
}

float dBox2d(vec2 p, vec2 b) {
	return max(abs(p.x) - b.x, abs(p.y) - b.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (-iResolution.xy + 2.0*fragCoord.xy) / iResolution.y;
	vec2 prevP = p;
    
    // camera
	vec3 ro = vec3(5.0,1.0,0.0);
    vec3 ta = vec3( 0.0, 0.8, 0.0 );
    
    // camera matrix
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
    
	// create view ray
	vec3 rd = normalize( p.x*uu + p.y*vv + 2.0*ww );
    
    // raytrace
	float tmin = 10000.0;
	vec3  pos = vec3(0.0);
	float oid = 0.0;

    // player model
    int index = 0;
    float xpos = 3.0;
    float ypos = 0.3+sin(iTime*0.5)*0.5;
    float zpos = 0.0;
    vec3 airCraftColor = vec3(0.7);
    mat3 rotX = matRotateX(radians(sin(iTime*0.7)*30.0));
    for(int i = 0; i<numFaces/3; i++){
        int f1 = faces[index];
        int f2 = faces[index+1];
        int f3 = faces[index+2];
        
        vec3 v0 = vec3(vertices[(f1*3)-3],vertices[((f1*3)-3)+1],vertices[((f1*3)-3)+2]);
        vec3 v1 = vec3(vertices[(f2*3)-3],vertices[((f2*3)-3)+1],vertices[((f2*3)-3)+2]);
        vec3 v2 = vec3(vertices[(f3*3)-3],vertices[((f3*3)-3)+1],vertices[((f3*3)-3)+2]);
        v0.y+=ypos;
        v1.y+=ypos;
        v2.y+=ypos;
    	
        v0.x += 1.0;
        v1.x += 1.0;
        v2.x += 1.0;
        
        v0 *= rotX;
        v1 *= rotX;
        v2 *= rotX;
        
        float xspeed = 0.9;
        v0.z += sin(iTime*xspeed)*1.5;
        v1.z += sin(iTime*xspeed)*1.5;
        v2.z += sin(iTime*xspeed)*1.5;
        
    	vec3 res = triIntersect( ro, rd, v0, v1, v2);
        if( res.x>0.0 && res.x<tmin )
        {
            tmin = res.x; 
            oid = 2.0;
            airCraftColor = vec3(0.6-(float(i)*0.02));
            if(f1 == 9 && f2 == 10 && f3 == 11 || f1 == 12 && f2 == 13 && f3 == 14){
            	airCraftColor = vec3(0.0,0.0,1.0);
            } else if(f1 == 19 && f2 == 20 && f3 == 15){
                airCraftColor = mod(iTime,0.2)<0.1?vec3(0.9,0.45,0.2):vec3(0.9,0.45,0.2)*1.5;
            } else if(f1 == 16 && f2 == 20 && f3 == 19){
                airCraftColor = mod(iTime,0.2)<0.1?vec3(0.9,0.4,0.2):vec3(0.9,0.4,0.2)*1.5;
            }
        }
        index += 3;
    }

    // boss model
    index = 0;
    ypos = 1.5+sin(iTime*0.3)*-0.1;
    xpos = 1.0+sin(iTime*0.5)*-1.5;
    zpos = sin(iTime*1.2)*2.0;
    vec3 bossColor = vec3(0.7);
    float manimate = sin(iTime*5.0)*0.05;
    for(int i = 0; i<numFaces2/3; i++){
        int f1 = faces2[index];
        int f2 = faces2[index+1];
        int f3 = faces2[index+2];
        
        vec3 v0 = vec3(vertices2[(f1*3)-3],vertices2[((f1*3)-3)+1],vertices2[((f1*3)-3)+2]);
        vec3 v1 = vec3(vertices2[(f2*3)-3],vertices2[((f2*3)-3)+1],vertices2[((f2*3)-3)+2]);
        vec3 v2 = vec3(vertices2[(f3*3)-3],vertices2[((f3*3)-3)+1],vertices2[((f3*3)-3)+2]);
        v0.y+=ypos;
        v1.y+=ypos;
        v2.y+=ypos;
    
		v0.x -= xpos;
        v1.x -= xpos;
        v2.x -= xpos;
        
		v0.z += zpos;
        v1.z += zpos;
        v2.z += zpos;
        
        // mouth animation
        if(f1 == 9){
            v0.y += manimate;
        }
        if(f2 == 9){
            v1.y += manimate;
        }
        if(f3 == 9){
            v2.y += manimate;
        }
        
		if(f1 == 4){
            v0.y += manimate*-1.0;
        }
        if(f2 == 4){
            v1.y += manimate*-1.0;
        }
        if(f3 == 4){
            v2.y += manimate*-1.0;
        }
        
    	vec3 res = triIntersect( ro, rd, v0, v1, v2);
        if( res.x>0.0 && res.x<tmin )
        {
            tmin = res.x; 
            oid = 3.0;
            bossColor = vec3(0.7-(float(i)*0.02));
        }
        index += 3;
    }
    
	// enemy bullet
	vec3 box = vec3(0.2,0.03,0.2);
    vec3 bcolor = vec3(0.8);
    mat4 brotX = rotationAxisAngle(vec3(1.0,0.0,0.0),radians(iTime*30.0));
    mat4 tra = translate( -xpos+mod(iTime*2.0,3.0)*3.0, 1.0, zpos );
    mat4 txi = tra *brotX; 
    mat4 txx = inverse( txi );       
	
    vec4 res = iBox( ro, rd, txx, txi, box);
    if( res.x>0.0 && res.x<tmin )
    {
        tmin = res.x; 
        oid = 1.0;
        bcolor = vec3(0.8-(tmin*0.1));
    }
    
    // material/bg
	vec3 col = vec3(1.0);
	if( tmin<100.0 )
	{
        // material
		vec3  mate = vec3(.0);
		if( oid<1.5 ) {
		    mate = bcolor;
		} else if( oid>=1.5 && oid<=2.0 ) {
		    mate = airCraftColor;
		} else if( oid>2.1 && oid<=3.0 ){
            mate = bossColor;
        }
		mate = mate*mate*1.1;
        	
		col *= mate;

		col = sqrt( col );
    } else {
        // bg
    	col = vec3(0.0);
        prevP.x+=sin(iTime+p.y)*0.7;
        float rbg = (length(prevP+vec2(2.5,0.0))-0.5)+sin(iTime+p.y)*0.2;
        col = mix( col, vec3(0.9,0.5,0.0), 1.0-smoothstep(0.15,2.5,abs(rbg)));
        
		float lbg = (length(prevP+vec2(-2.5,0.0))-0.5)+sin(iTime+p.y)*0.2;
        col = mix( col, vec3(1.0,0.2,0.2), 1.0-smoothstep(0.15,2.5,abs(lbg)));
    }
	
    // UI
    p = (fragCoord.xy * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);
    float ganimate = sin(iTime*1.5)*0.1;
    
    float playerBarBg = dBox2d(p+vec2(1.20, 0.85), vec2(0.3,0.055));
    col = mix( col, vec3(1.0), 1.0-smoothstep(0.01,0.011,abs(playerBarBg)));
    
    float playerBar = dBox2d(p+vec2(1.3-ganimate, 0.85), vec2(0.15+ganimate,0.006));
    col = mix( col, vec3(1.0,0.0,0.0), 1.0-smoothstep(0.029,0.03,abs(playerBar)));
    
	float bossBarBg = dBox2d(p+vec2(-1.20, 0.85), vec2(0.3,0.055));
    col = mix( col, vec3(1.0), 1.0-smoothstep(0.01,0.011,abs(bossBarBg)));
    
    float bossBar = dBox2d(p+vec2(-1.2, 0.85), vec2(0.25,0.006));
    col = mix( col, vec3(0.6,0.6,1.0), 1.0-smoothstep(0.029,0.03,abs(bossBar)));
    
    // result
	fragColor = vec4( col, 1.0 );
}