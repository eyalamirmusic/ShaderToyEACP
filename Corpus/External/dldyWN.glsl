// dldyWN - lf94
// https://www.shadertoy.com/view/dldyWN
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2020 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// I'm starting with 2D but should scale up to 3D no problem
// This demonstrates having different radius ratios
// I need this for my SDF CAD stuff


// Most mininal example. You see it stretches the circle.
float sdCircle( in vec2 p, in float r ) 
{
    return length(vec2(p.x / 2., p.y))-r;
}

// Derived from the SDF box video from IQ.  The max(r.y/r.x, 1.) is my stuff
float sdBox1(in vec2 p, in vec2 r) {
  return sqrt(pow(max((p.x-r.x)*max(r.y/r.x, 1.), 0.0),2.) + pow(max((p.y-r.y)*max(r.x/r.y, 1.),0.0),2.));
}

// This is the final form
float sdBox( in vec2 p, in vec2 b, in vec2 r )
{
    vec2 s = max(vec2(r.y/r.x, r.x/r.y), 1.);
    vec2 b2 = b*vec2(r.y/r.x, r.x/r.y);
    vec2 d = abs(p)-b2;
    vec2 d2 = vec2((d.x-r.x)*s.x, (d.y-r.y)*s.y);
    
    return (length(max(d2,0.0)) + min(max(d2.x,d2.y),0.0)) - max(r.y/r.x, r.x/r.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;

	float d = sdBox(p * 10., vec2(1.0, 1.0), vec2(4.00, 1.00)) / 10.;
    
	// coloring
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
    col *= 1.0 - exp(-6.0*abs(d));
	col *= 0.8 + 0.2*cos(150.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );

    if( iMouse.z>0.001 )
    {
    d = sdBox(p * 10., vec2(1.0, 1.0), vec2(4.00, 1.00)) / 10.;
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }

	fragColor = vec4(col,1.0);
}