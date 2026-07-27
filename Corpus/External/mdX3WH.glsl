// mdX3WH - iq
// https://www.shadertoy.com/view/mdX3WH
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Signed distance and gradient to a parabola.
// Probably faster than central differences or
// automatic differentiation/dual numbers.

// List of other 2D distances+gradients:
//
// https://iquilezles.org/articles/distgradfunctions2d
//
// and
//
// https://www.shadertoy.com/playlist/M3dSRf


// .x = f(p)
// .y = ∂f(p)/∂x
// .z = ∂f(p)/∂y
// .yz = ∇f(p) with ‖∇f(p)‖ = 1
vec3 sdParabola( in vec2 pos, in float k )
{
    float s = sign(pos.x);
    pos.x = abs(pos.x);
    
    float ik = 1.0/k;
    float p = ik*(pos.y - 0.5*ik)/3.0;
    float q = 0.25*ik*ik*pos.x;
    
    float h = q*q - p*p*p;
    float r = sqrt(abs(h));

    float x = (h>0.0) ? 
        // 1 root
        pow(q+r,1.0/3.0) - pow(abs(q-r),1.0/3.0)*sign(r-q) :
        // 3 roots
        2.0*cos(atan(r,q)/3.0)*sqrt(p);
    
    float z = (pos.x-x<0.0)?-1.0:1.0;
    vec2 w = pos-vec2(x,k*x*x); float l = length(w); w.x*=s;
    
    return z*vec3(l, w/l );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
        
    // animate
    float t = iTime/2.0;
    float px =  0.0 + 0.4*cos(t*1.1+5.5); // x position
    float py = -0.4 + 0.2*cos(t*1.2+3.0); // y position
    float pk =  8.0 + 7.5*cos(t*1.3+3.5); // width
    
    // sdf
    vec3  dg = sdParabola( p-vec2(px,py), pk );
    float d = dg.x;
    vec2 g = dg.yz;
        
    // central differenes based gradient, for comparison
    //g = vec2(dFdx(d),dFdy(d))/(2.0/iResolution.y);
    
	// coloring
     vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.4,0.7,0.85);
    col *= 1.0 + vec3(0.5*g,0.0);
  //col = vec3(0.5+0.5*g,1.0);
    col *= 1.0 - 0.5*exp(-16.0*abs(d));
	col *= 0.9 + 0.1*cos(150.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );
    
    if( iMouse.z>0.001 )
    {
    d = sdParabola(m-vec2(px,py), pk ).x;
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }

	fragColor = vec4(col,1.0);
}
 