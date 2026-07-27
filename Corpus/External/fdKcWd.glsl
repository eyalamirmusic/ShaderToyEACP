// fdKcWd - gehtsiegarnixan
// https://www.shadertoy.com/view/fdKcWd
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2022 Gehtsiegarnixan
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
/*
This is an approximation of a tropical cyclone flowmap at sea level. 
The reference cyclone had a diamter of 300km. The maximum velocity was 53m/s. 
It was generated using the CM1 weather model in a super computer. 

The flowmap is just a vector field that can be used for other stuff like this 
(https://www.shadertoy.com/view/7dycDV)

The quiver plot is from Reima (https://www.shadertoy.com/view/ls2GWG)
*/

#define twoPi           6.2831853072
#define pi              3.1415926536
#define ARROW_TILE_SIZE 32.0

// Computes the center pixel of the tile containing pixel pos
vec2 arrowTileCenterCoord(vec2 pos) {
	return (floor(pos / ARROW_TILE_SIZE) + 0.5) * ARROW_TILE_SIZE;
}

// Computes the signed distance from a line segment
float line(vec2 p, vec2 p1, vec2 p2) {
	vec2 center = (p1 + p2) * 0.5;
	float len = length(p2 - p1);
	vec2 dir = (p2 - p1) / len;
	vec2 rel_p = p - center;
	float dist1 = abs(dot(rel_p, vec2(dir.y, -dir.x)));
	float dist2 = abs(dot(rel_p, dir)) - 0.5*len;
	return max(dist1, dist2);
}

// v = field sampled at arrowTileCenterCoord(p), scaled by the length
// desired in pixels for arrows
// Returns a signed distance from the arrow
float arrow(vec2 p, vec2 v) {
	// Make everything relative to the center, which may be fractional
	p -= arrowTileCenterCoord(p);
		
	float mag_v = length(v), mag_p = length(p);
	
	if (mag_v > 0.0) {
		// Non-zero velocity case
		vec2 dir_v = v / mag_v;
		
		// We can't draw arrows larger than the tile radius, so clamp magnitude.
		// Enforce a minimum length to help see direction
		mag_v = clamp(mag_v, 5.0, ARROW_TILE_SIZE * 0.5);

		// Arrow tip location
		v = dir_v * mag_v;

		// Signed distance from shaft
		float shaft = line(p, v, -v);
		// Signed distance from head
		float head = min(line(p, v, 0.4*v + 0.2*vec2(-v.y, v.x)),
		                 line(p, v, 0.4*v + 0.2*vec2(v.y, -v.x)));

		return min(shaft, head);
	} else {
		// Signed distance from the center point
		return mag_p;
	}
}

//shifts value range from 0-1 to -1-1
vec2 makeM1to1(vec2 x) {
    return (x - 0.5) * 2.0;
}

//shifts value range from -1-1 to 0-1
vec2 make0to1(vec2 x) {
    return (1.0 + x) / 2.0;
}

// makes a simple flowmap of a cyclone
vec2 cycloneFlow(vec2 point, float radius, float time) {  
    float size = 1./(1.4 * sqrt(radius)); // of the entire cyclone
    float curl = 2.5; // kind of arbitrary but between 1-3.5 looks good
    float hole = 1./(4.*size); // also kind of arbitrary
    
    //point += vec2(cos(time),sin(time))*0.1*hole; //rotating center
    
    float angle = atan(point.y, point.x); //angle around center
    float dist = length(point); // distance to point
    float spiral = fract(dist/radius + (angle-time)/twoPi);
    
    //right slanted donut https://www.desmos.com/calculator/ocm71awnym
    spiral -= 1.212; //
    spiral = 1.+ (pow(1.57*(spiral)+0.8,2.)/spiral);
        
    float flowAngle = pi + angle -(dist*curl) -(spiral*0.8);
    
    // left slanted donut https://www.desmos.com/calculator/uxyefly7fi
    float spiralStrength = 0.05; // makes sure mask is 0-1 range
    float mask = (1. - spiralStrength)-(pow(dist*size-hole, 2.0)/dist);
    mask += spiral*spiralStrength; 
    mask = clamp(mask, 0.0, 1.0);  // saturate
    
    vec2 flow = normalize(vec2(cos(flowAngle),sin(flowAngle)));
    flow *= mask; // apply strength mask
    
    //flow = (flow+1.0)/2.0; // to save as texture
    //flow += vec2(0.00001,0.00001); //adding tiny offset so it isnt 0
    return flow;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float radius = 0.3; // of the first spiral
    float time = iTime * 1.0; // rotation speed  
    vec2 uv = (fragCoord.xy- (0.5*iResolution.xy))/iResolution.y; // center screen coords 
    
    vec2 flowMap = cycloneFlow(uv, radius, time);    
        
    float arrow_dist = arrow(fragCoord.xy, flowMap* ARROW_TILE_SIZE * 0.4);
	vec4 arrow_col = vec4(0, 0, 0, clamp(arrow_dist, 0.0, 1.0));

    fragColor = mix(arrow_col, vec4(make0to1(flowMap),0.5,1.0), arrow_col.a);
}