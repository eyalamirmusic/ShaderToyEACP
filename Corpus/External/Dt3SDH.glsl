// Dt3SDH - iq
// https://www.shadertoy.com/view/Dt3SDH
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org/
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Shader for https://www.youtube.com/watch?v=tfLku5IjUzE (cosmetics removed)

// When a ray doesn't intersect a sphere, it still does it if one is
// willing to take complex coordinates for the intersection points.
// This shader shows where these complex intersections are in space,
// for some arbitrary moving ray.


//-------------------------------------------------------------------

// https://iquilezles.org/articles/distfunctions
float sdCircle( in vec2 p, in vec2 c, in float r )
{
    return length(p-c)-r;
}

// https://iquilezles.org/articles/distfunctions
float sdLine( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p-a, ba = b-a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h );
}

// https://iquilezles.org/articles/distfunctions/
vec2 opUnion( vec2 m, float d, float a )
{
    return (d<m.x) ? vec2(d,a) : m;
}

// https://iquilezles.org/articles/intersectors/
void intersectCircle( in vec2 ro, in vec2 rd, float rad, out vec4 p1, out vec4 p2 )
{
	float b = dot( ro, rd );
	float c = dot( ro, ro ) - rad*rad;
	float h = b*b - c;
    
    if( h>0.0 )
    {
        // real
        h = sqrt(h);
        p1 = vec4( ro + (-b+h)*rd, ro );
        p2 = vec4( ro + (-b-h)*rd, ro );
    }
    else
    {
        // complex
        h = sqrt(-h);
        p1 = vec4( ro - b*rd, ro + h*rd );
        p2 = vec4( ro - b*rd, ro - h*rd );
    }
}

//-------------------------------------------------------------------

void get_ray( out vec2 ro, out vec2 rd, in float t )
{
    float an = 3.1415927*(0.5 + 0.2*sin(t*0.735+4.0));
    ro = vec2(-1.0*cos(t*0.525),-1.0+0.1*sin(t*1.5));
    rd = vec2(cos(an),sin(an));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    float px = 2.0/iResolution.y;

    p.y -= 0.4;


    const float rad = 0.4;
    const float cth = 0.03;
    

    // background
    vec3 col = vec3(0.2 - 0.1*length(p*0.5));
    
    // circle
    {
    float d = sdCircle( p, vec2(0.0,0.0), rad );
    col = mix( col, vec3(0.75), 1.0-smoothstep(0.0,0.01,abs(d)-0.005) );
    }
    
    // trails
    {
        vec2 dr = vec2(1e20,1.0);
        vec2 di = vec2(1e20,1.0);
        vec4 op1;
        vec4 op2;
        const int num = 256;
        for( int i=0; i<num; i++ )
        {
            float a = float(i)/float(num);

            vec2 ro, rd; get_ray( ro, rd, iTime - 3.0*a );

            vec4 p1, p2; intersectCircle( ro, rd, rad, p1, p2 );
            
            if( i>0 )
            {
            dr = opUnion(dr, min(sdLine( p, p1.xy, op1.xy ), sdLine( p, p2.xy, op2.xy )), a);
            di = opUnion(di, min(sdLine( p, p1.zw, op1.zw ), sdLine( p, p2.zw, op2.zw )), a);
            }

            op1 = p1;
            op2 = p2;
        }
        
        col = mix( col, vec3(0.0,0.7,1.2), smoothstep(1.0,0.7,dr.y)*(1.0-smoothstep(0.0,0.01,dr.x)) );
        col = mix( col, vec3(1.2,0.7,0.0), smoothstep(1.0,0.7,di.y)*(1.0-smoothstep(0.0,0.01,di.x)) );
    }

    vec2 ro, rd; get_ray( ro, rd, iTime );

    // ray
    {
        {
        float d = sdLine( p, ro-rd*10.0, ro+rd*10.0 );
        col = mix( col, vec3(1.0), 0.25*(1.0-smoothstep(0.0,0.008,d)) );
        }
        
        {
        vec2 rdp = vec2(-rd.y,rd.x);
        vec2 tip = ro+rd*0.2;
        float d = sdLine( p, ro, tip );
        
        d = min( d, sdLine( p, tip, tip + 0.05*normalize( rdp-2.0*rd) ) );
        d = min( d, sdLine( p, tip, tip + 0.05*normalize(-rdp-2.0*rd) ) );
      //d = min( d, sdCircle( p, ro, cth ) );
        col = mix( col, vec3(0.75), 1.0-smoothstep(0.005,0.01,d) );
        }
    }
    
    // intersections
    {
        vec4 p1, p2; intersectCircle( ro, rd, rad, p1, p2 );

        float dr = min( sdCircle( p, p1.xy, cth ), sdCircle( p, p2.xy, cth ) );
        float di = min( sdCircle( p, p1.zw, cth ), sdCircle( p, p2.zw, cth ) );
        col = mix( col, vec3(0.0,0.7,1.2), 1.0-smoothstep(0.005,0.01,dr) );
        col = mix( col, vec3(1.2,0.7,0.0), 1.0-smoothstep(0.005,0.01,di) );
    }

    // cheap dithering
    col += sin(fragCoord.x*114.0)*sin(fragCoord.y*211.1)/512.0;

    fragColor = vec4(col,1.0);
}