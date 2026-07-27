// NdyyWy - gehtsiegarnixan
// https://www.shadertoy.com/view/NdyyWy
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
This is a donut shaped flowmap I did for testing. 

The quiver plot is from Reima (https://www.shadertoy.com/view/ls2GWG)
*/

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

//shifts value range from -1-1 to 0-1
vec2 make0to1(vec2 x) {
    return (1.0 + x) / 2.0;
}

// makes a simple flowmap in the shape a donut swirl centered on point
vec2 donutFlow(vec2 point, float spread, float offset)
{    
    float cenderDistance = length(point); // distance to center    
    // simple inverted x^2 https://www.desmos.com/calculator/ibidozowyh
    float donut =  1.0-pow(2.0*(cenderDistance-offset)/spread, 2.0);     
    donut = clamp(donut, 0.0, 1.0);  // saturate
    
    vec2 flow = normalize(vec2(-point.y, point.x)); // flow vectors
    flow *= donut;  // masked by donut
    //flow = (flow+1.0)/2.0; // generates a flowmap texture
    //flow += vec2(0.0001,0.0001); //adding tiny offset so it isnt 0
    return flow;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord.xy- (0.5*iResolution.xy))/iResolution.y; // center screen coords 
    uv += vec2(cos(iTime),sin(iTime))*0.1; //rotating center
    float spread = mix(0.4, 0.3, sin(0.9*iTime)*0.5+0.5); //changing donut size
    
    // making flowmap
    vec2 flowMap = donutFlow(uv, spread, 0.33);
     
    //adding arrows
    float arrow_dist = arrow(fragCoord.xy, flowMap* ARROW_TILE_SIZE * 0.4);
	vec4 arrow_col = vec4(0, 0, 0, clamp(arrow_dist, 0.0, 1.0));
    
    fragColor = mix(arrow_col, vec4(make0to1(flowMap),0.5,1.0), arrow_col.a);
}