// iq - licence: mit
// https://www.shadertoy.com/view/4ssSRl

// The MIT License
// Copyright © 2014 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org
// distance to a line (can't get simpler than this)
float line( in vec2 a, in vec2 b, in vec2 p )
{
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
	return length( pa - ba*h );
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (-iResolution.xy + 2.0*fragCoord.xy) / iResolution.yy;
	vec2 q = p;
	
	vec2 c = vec2(0.0);
	if( iMouse.z>0.0 ) c=(-iResolution.xy + 2.0*iMouse.xy) / iResolution.yy;
	
    // background	
	vec3 col = vec3(0.5,0.85,0.9)*(1.0-0.2*length(p));
	if( q.x>c.x && q.y>c.y ) col = pow(col,vec3(2.2));

    // zoom in and out	
	p *= 1.0 + 0.2*sin(iTime*0.4);
	
	
	// compute distance to a set of lines
    float d = 1e20;	
	for( int i=0; i<7; i++ )
	{
        float anA = 6.2831*float(i+0)/7.0 + 0.15*iTime;
        float anB = 6.2831*float(i+3)/7.0 + 0.20*iTime;
		vec2 pA = 0.95*vec2( cos(anA), sin(anA) );		
        vec2 pB = 0.95*vec2( cos(anB), sin(anB) );		
		float h = line( pA, pB, p );
		d = min( d, h );
	}

    // lines/start, left side of screen	: not filtered
	if( q.x<c.x )
	{
		if( d<0.12 ) col = vec3(0.0,0.0,0.0); // black 
		if( d<0.04 ) col = vec3(1.0,0.6,0.0); // orange
	}
    // lines/start, right side of the screen: filtered
	else
	{
		float w = 0.5*fwidth(d); 
		w *= 1.5; // extra blur
		
		if( q.y<c.y )
		{
		col = mix( vec3(0.0,0.0,0.0), col, smoothstep(-w,w,d-0.12) ); // black
		col = mix( vec3(1.0,0.6,0.0), col, smoothstep(-w,w,d-0.04) ); // orange
		}
		else
		{
		col = mix( pow(vec3(0.0,0.0,0.0),vec3(2.2)), col, smoothstep(-w,w,d-0.12) ); // black
		col = mix( pow(vec3(1.0,0.6,0.0),vec3(2.2)), col, smoothstep(-w,w,d-0.04) ); // orange
		}
	}
	

	if( q.x>c.x && q.y>c.y )
		col = pow( col, vec3(1.0/2.2) );
	
    // draw left/right separating line
	col = mix( vec3(0.0), col, smoothstep(0.007,0.008,abs(q.x-c.x)) );
	col = mix( col, vec3(0.0), (1.0-smoothstep(0.007,0.008,abs(q.y-c.y)))*step(0.0,q.x-c.x) );
	
	
	fragColor = vec4( col, 1.0 );
}