// DslcWB - pizzahollandaise
// https://www.shadertoy.com/view/DslcWB
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2020 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Based on:

// List of some other 2D distances: https://www.shadertoy.com/playlist/MXdSRf
// and iquilezles.org/articles/distfunctions2d
#define INF 1.0 / 0.0

float distLine(vec3 p, vec3 dir) {
    return length(cross(p, dir))/length(dir)-0.1;
}

float sdSphere(vec3 p, vec4 s) {
    return length(p-s.xyz)-s.w;
}

bool bounded = false;
// Rounded capsule https://iquilezles.org/articles/distfunctions/
float dot2(in vec3 v) { return dot(v,v); }
float sdBranchFast(vec3 p, vec4 a, vec4 b, float minDist) {
    // sampling independent computations (only depend on shape)
    vec3  ba = b.xyz - a.xyz;
    float l2 = dot(ba, ba);
    float bound = length(cross(p-a.xyz, ba))/sqrt(l2) -a.w;
    if (bound > minDist) {
        bounded = true;
        return minDist; // Early skip
    } // Bounding cylinder
    float rr = a.w - b.w;
    float a2 = l2 - rr*rr;
    float il2 = 1.0/l2;
        
    // sampling dependant computations
    vec3 pa = p - a.xyz;
    float y = dot(pa, ba);
    float z = y - l2;
    float x2 = dot2( pa*l2 - ba*y );
    float y2 = y*y*l2;
    float z2 = z*z*l2;

    // single square root!
    float k = sign(rr)*rr*rr*x2;
    if( sign(z)*a2*z2>k ) return min(sqrt(x2 + z2)         *il2 - b.w, minDist);
    if( sign(y)*a2*y2<k ) return min(sqrt(x2 + y2)         *il2 - a.w, minDist);
                          return min((sqrt(x2*a2*il2)+y*rr)*il2 - a.w, minDist);
}

float map(vec2 p2) {
    vec3 p = vec3(p2.x, p2.y, 0.0);
    float other = sdSphere(p, vec4(0.5, 0.0, 0.0, 0.3));
    //return distLine(p, vec3(1.0, 1.0, 0.0));
    return sdBranchFast(p, vec4(-0.3, -0.3, 0.0, 0.4), vec4(0.5, 0.5, 0.0, 0.1), other);
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;

	float d = map(p);
    
	// coloring
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
    col *= 1.0 - exp(-6.0*abs(d));
	col *= 0.8 + 0.2*cos(150.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );

    if( iMouse.z>0.001 ) {
        d = map(m);
        col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
        col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }
    if (bounded) col *= 0.5;
	fragColor = vec4(col,1.0);
}