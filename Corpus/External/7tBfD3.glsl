// 7tBfD3 - iq
// https://www.shadertoy.com/view/7tBfD3
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// The Devil's Stairs (https://en.m.wikipedia.org/wiki/Cantor_function) climbs around f(x)=x
// but can be generalize to any monotonic function for which we can compute the inverse.

float fun_smt( float x, float k ) { return pow(x,k)/(pow(x,k)+pow(1.0-x,k)); }
float inv_smt( float x, float k ) { return fun_smt(x,1.0/k); }
float fun_pow( float x, float k ) { return pow(x,k); }
float inv_pow( float x, float k ) { return fun_pow(x,1.0/k); }

float function( float x, float t )
{
    float k = exp2(3.0*(0.5-0.5*cos(t*6.283185/3.0)));
    return (t<3.0) ? fun_smt(x,k) : fun_pow(x,k);
}
float inverse_function( float x, float t )
{
    float k = exp2(3.0*(0.5-0.5*cos(t*6.283185/3.0)));
    return (t<3.0) ? inv_smt(x,k) : inv_pow(x,k);
}

// generalization of Devil's Staircase
float cantor( float x, float t )
{
    float y = 0.0;
    float sc = 0.5;
    float bi = 0.0;
    float xa = 0.0;
    float xb = 1.0;
    for( int i=0; i<9; i++ )
    {
        // choose subdivision intervals
        float ya = function(xa,t);
        float yb = function(xb,t);
        float wa = inverse_function(ya+(yb-ya)/3.0,t);
        float wb = inverse_function(yb-(yb-ya)/3.0,t);
        // recurse
             if( x<wa ) { bi+=0.0*sc; y=bi+sc*(x-xa)/(wa-xa); xb=wa; }
        else if( x>wb ) { bi+=1.0*sc; y=bi+sc*(x-wb)/(xb-wb); xa=wb; }
        else            { bi+=0.0*sc; y=bi+sc;                break; }
        sc *= 0.5;
    }
    return y;
}

// https://iquilezles.org/articles/distfunctions2d/
float sdLine( in vec2 p, in vec2 a, in vec2 b )
{
	vec2 pa = p-a, ba = b-a;
	return length(pa-ba*clamp(dot(pa,ba)/dot(ba,ba),0.0,1.0));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{	
    // pixel coords
    float px = 1.0/iResolution.y;
    vec2  p = (vec2((iResolution.y-iResolution.x)/2.0,0.0)+fragCoord)*px;
    
    // animation loop
    float t = mod(iTime,6.0);

    // render
    vec3 col = vec3(0.0);
    if( p.x>0.0 && p.x<1.0 )
    {
        // background
        col = vec3( 0.04 + 0.008*mod(floor(p.x*10.0)+floor(p.y*10.0),2.0) );

        // plot
        vec2 d = vec2(1e20);
        for( int i=-2; i<2; i++ )
        {
            float x0 = p.x + px*float(i+0);
            float x1 = p.x + px*float(i+1);
            d.x = min( d.x, sdLine(p, vec2(x0, function(x0,t)), 
                                      vec2(x1, function(x1,t))));
            d.y = min( d.y, sdLine(p, vec2(x0, cantor(  x0,t)), 
                                      vec2(x1, cantor(  x1,t))));
        }
        col = mix( col, vec3(0.25,0.25,0.25), 1.0-smoothstep(0.0007,0.0007+px,d.x) );
        col = mix( col, vec3(1.00,0.36,0.04), 1.0-smoothstep(0.0007,0.0007+px,d.y) );
    }
    
    // gamma
    col = sqrt(col);
 
    fragColor = vec4( col, 1.0 );
}