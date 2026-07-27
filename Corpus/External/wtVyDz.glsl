// wtVyDz - iq
// https://www.shadertoy.com/view/wtVyDz
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2021 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// The three bisectors of a triangle meet at a single point
// which is also the point that is equidistant to the three
// sides. And so, it's also the center of the incircle of
// the triangle.


vec2 triangleIncenter( in vec2 v0, in vec2 v1, in vec2 v2 )
{
    float l0 = length(v2-v1);
    float l1 = length(v0-v2);
    float l2 = length(v1-v0);

    return (v0*l0+v1*l1+v2*l2)/(l0+l1+l2);
}

//=====================================================

// signed distance to a disk
float sdDisk( in vec2 p, in vec2 c, in float r )
{
    return length(p-c)-r;
}

// distance to a line segment
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h );
}

// signed distance to a 2D triangle
float cro(in vec2 a, in vec2 b ) { return a.x*b.y-a.y*b.x; }
float dot2( in vec2 a ) { return dot(a,a); }
float sdTriangle( in vec2 p0, in vec2 p1, in vec2 p2, in vec2 p )
{
	vec2 e0 = p1-p0; vec2 v0 = p-p0;
	vec2 e1 = p2-p1; vec2 v1 = p-p1;
	vec2 e2 = p0-p2; vec2 v2 = p-p2;

	vec2 pq0 = v0 - e0*clamp( dot(v0,e0)/dot2(e0), 0.0, 1.0 );
	vec2 pq1 = v1 - e1*clamp( dot(v1,e1)/dot2(e1), 0.0, 1.0 );
	vec2 pq2 = v2 - e2*clamp( dot(v2,e2)/dot2(e2), 0.0, 1.0 );
    
    vec2 d = min( min( vec2( dot2( pq0 ), cro(v0,e0) ),
                       vec2( dot2( pq1 ), cro(v1,e1) )),
                       vec2( dot2( pq2 ), cro(v2,e2) ));

	return -sqrt(d.x)*sign(d.y);
}

//=====================================================

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
	
	vec2 v0 = vec2(1.2,0.8)*cos( 0.5*iTime + vec2(0.0,2.0) );
	vec2 v1 = vec2(1.2,0.8)*cos( 0.5*iTime + vec2(1.5,3.0) );
	vec2 v2 = vec2(1.2,0.8)*cos( 0.5*iTime + vec2(4.0,1.0) );

    // compute traingle SDF
	float dis = sdTriangle( v0, v1, v2, p );
    
    // compute triangle equicenter (yellow dot)
    vec2 ce = triangleIncenter( v0, v1, v2 );

    // draw triangle SDF
    vec3 col = vec3(1.0) - sign(dis)*vec3(0.1,0.4,0.7);
	col *= 1.0 - exp(-2.0*abs(dis));
	col *= 0.8 + 0.2*cos(150.0*dis);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(dis)) );

    // draw helped bisectors
    col = mix(col,vec3(1.0,1.0,1.0),smoothstep(0.005,0.001,sdSegment( p, v0, ce )));
    col = mix(col,vec3(1.0,1.0,1.0),smoothstep(0.005,0.001,sdSegment( p, v1, ce )));
    col = mix(col,vec3(1.0,1.0,1.0),smoothstep(0.005,0.001,sdSegment( p, v2, ce )));
    
    // draw equicenter in yellow
    col = mix(col,vec3(1.0,1.0,0.0),smoothstep(0.005,0.001,sdDisk(p,ce,0.02)));

    // output
    fragColor = vec4(col,1.0);
}