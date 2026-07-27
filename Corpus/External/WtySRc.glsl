// WtySRc - iq
// https://www.shadertoy.com/view/WtySRc
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2020 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Signed distance and gradient to a hexagon. Probably
// faster than central differences or automatic
// differentiation/dual numbers.

// List of other 2D distances+gradients:
//
// https://iquilezles.org/www/articles/distgradfunctions2d/distgradfunctions2d.htm
//
// and
//
// https://www.shadertoy.com/playlist/M3dSRf


// .x = f(p)
// .y = ∂f(p)/∂x
// .z = ∂f(p)/∂y
// .yz = ∇f(p) with ‖∇f(p)‖ = 1
vec3 sdgHexagon( in vec2 p, in float r ) 
{
    const vec3 k = vec3(-0.866025404,0.5,0.577350269);
    vec2 s = sign(p);
    p = abs(p);
	float w = dot(k.xy,p);    
    p -= 2.0*min(w,0.0)*k.xy;
    p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
    float d = length(p)*sign(p.y);
    vec2  g = (w<0.0) ? mat2(-k.y,-k.x,-k.x,k.y)*p : p;
    return vec3( d, s*g/d );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;

    // size
	float si = 0.3 + 0.2*cos( iTime );
    // corner radious
    float ra = 0.3*(0.5+0.5*sin(iTime*2.0));

    // sdf(p) and gradient(sdf(p))
	vec3 dg = sdgHexagon(p,si);
    float d = dg.x-ra;
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

	fragColor = vec4(col,1.0);
}