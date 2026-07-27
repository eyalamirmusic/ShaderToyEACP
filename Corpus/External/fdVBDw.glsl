// fdVBDw - iq
// https://www.shadertoy.com/view/fdVBDw
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Computing the SDF of a limited number of copies of a base
// SDF object constrained to a circle.

// Related techniques:
//
// Elongation  : https://www.shadertoy.com/view/Ml3fWj
// Rounding    : https://www.shadertoy.com/view/Mt3BDj
// Onion       : https://www.shadertoy.com/view/MlcBDj
// Metric      : https://www.shadertoy.com/view/ltcfDj
// Combination : https://www.shadertoy.com/view/lt3BW2
// Repetition  : https://www.shadertoy.com/view/3syGzz
// Extrusion2D : https://www.shadertoy.com/view/4lyfzw
// Revolution2D: https://www.shadertoy.com/view/4lyfzw
//
// More information here: https://iquilezles.org/articles/distfunctions

// https://iquilezles.org/articles/distfunctions
float sdBox( in vec2 p, in vec2 b ) 
{
    vec2 q = abs(p) - b;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0));
}

// the SDF we want to repeat
float sdBase( in vec2 p, vec2 id, float sp, in float time )
{
    float d;
    if( sin(time/2.0)>0.0 )
    {
        d = sdBox( p, vec2(0.1,0.1)*sp ) - 0.2*sp;
    }
    else
    {
        if( mod(id.x+id.y,2.0)>0.5 )
          d = sdBox( p, vec2(0.2*sp) );
        else
          d = sdBox( p, vec2(0.2,0.02)*sp ) - 0.3*sp;
    }
    return d;
}

// the point of this shader
float sdCircularRepetition( in vec2 p, float ra, float sp, float time )
{
    // make grid
    vec2 id0 = round(p/sp);
    
    // snap to circle
    if( dot(id0,id0)>ra*ra ) id0 = round(normalize(id0)*ra);
    
    // scan neighbors
    float d = 1e20;
    for( int j=-2; j<=2; j++ ) // increase this search window
    for( int i=-2; i<=2; i++ ) // for large values of ra
    {
        vec2 id = id0 + vec2(i,j);
        if( dot(id,id)<=ra*ra )
        {
            vec2 q = p-sp*id;
            d = min( d, sdBase(q,id,sp,time) );
        }
    }
    return d;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
	
    float time = iTime + 0.001;
    
    // circle radius and cell size, to be tuned for your needs
    float ra = floor(3.0 + 8.0*(0.5-0.5*cos(time)));
    float sp = 0.8/ra;

    // sdf
    float d = sdCircularRepetition( p, ra, sp, time );
    
    // colorize
    vec3 col = (d>0.0) ? vec3(0.9,0.6,0.3) : vec3(0.65,0.85,1.0);
	col *= 1.0 - exp(-32.0*abs(d));
	col *= 0.8 + 0.2*cos( 120.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.009,abs(d)) );
   
    if( iMouse.z>0.001 )
    {
    d = sdCircularRepetition( m, ra, sp, time );
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }
    
    fragColor = vec4(col,1.0);
}