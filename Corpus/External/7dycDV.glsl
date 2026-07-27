// 7dycDV - gehtsiegarnixan
// https://www.shadertoy.com/view/7dycDV
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
Update: I made a faster version using my Square Directional Flow 
(https://www.shadertoy.com/view/7ddBWl).

This is using my Hex Directional Flow algorithm 
(https://www.shadertoy.com/view/fsGyDG) with Sine waves instead of a texture.
I also made a flowmap that is an aproximation of a tropical cyclone flowmap 
(https://www.shadertoy.com/view/fdKcWd). I wanted to aproximate the water wave height.

I looked up the forumlas for the relationship between windspeed and waves, but the math
is very complicated and I gave up. So I went for what looks alright 
(https://www.desmos.com/calculator/lewikf6y0f).

The easy water wave math can be found here 
(https://en.wikipedia.org/wiki/Dispersion_(water_waves)). Wikipeda explains the 
relationship between water depth, wavelength and wave velocity 
(https://www.desmos.com/calculator/2nlmht2mmy). The amplitude and windspeed don't have
such linear interaction, but there are formuals for observed wave spectra on the ocean
after long periods of steady wind (https://wikiwaves.org/Ocean-Wave_Spectra). I just can
not figure out how to solve for the wavespeed/wavelength for a give depth and windspeed.
A single wave can be described by the gerstner formula 
(https://catlikecoding.com/unity/tutorials/flow/waves/), but I couldn't find how the wind
affects the wave steepness and when exactly they break on the open sea. I found some
hints here (http://hyperphysics.phy-astr.gsu.edu/hbase/Waves/watwav2.html) when they 
break. 

I played around with circular and straight waves, but the circular ones don't look 
that different for how much more work they are. So I kept the straight waves, but see
dD and cD to test for yourself.

Animating the flowmap also turned out to have some significant drawbacks. Since im sampling
a lower res hexagonal version leads to flickering waves, so you can only do it VERY slowly. 
*/

#define pi              3.1415926536
#define sqrtG           3.1320919527
#define twoPi           6.2831853072
#define sqrt3 			1.7320508076 //sqrt(3)
#define half_sqrt3		0.8660254038 //sqrt(3)/2
#define inv_sqrt3		0.5773502693 // 1/sqrt(3)
#define inv_twice_sqrt3	0.2886751346 // 1/(2 sqrt(3))

// if you want flat tops (hex rotated by 30deg) swap xy in hr and the p.x to p.y in hexDist
const vec2 r = vec2(1, sqrt3); // 1, sqrt(3)
const vec2 h = vec2(0.5,half_sqrt3); // 1/2, sqrt(3) /2

// Hexagonal Distanstance from the 0,0 coords
float hexDist(vec2 p) {
	p = abs(p);   
    return max(dot(p, h), p.x);
}

// struct to fill with needed HexTile Parametes
struct hexParams {
  vec2 gv;
  vec2 id;
  float edist;
};

// From BigWIngs "Hexagonal Tiling" https://www.shadertoy.com/view/3sSGWt
hexParams hexTile(vec2 uv) {   
    vec2 a = mod(uv, r)-h;
    vec2 b = mod(uv-h, r)-h;    
    vec2 gv = dot(a, a) < dot(b,b) ? a : b; //center hex UV coords
    
    // float edist = .5-hexDist(gv);  // Edge distance.
    float edist = (.5-hexDist(gv))*2.; //  Edge distance with range 0-1
    // float cdist = dot(gv, gv); // squared distance from the center.
    // float cdist = dot(gv, gv)*3.; // squared distance with range 0-1
    vec2 id = uv-gv; // simple ID calculation
    
    return hexParams(gv,id,edist); // xy hex coords + z distance to edge
}

// makes viridis colormap with polynimal 6 https://www.shadertoy.com/view/Nd3fR2
vec3 viridis(float t) {
    const vec3 c0 = vec3(0.274344,0.004462,0.331359);
    const vec3 c1 = vec3(0.108915,1.397291,1.388110);
    const vec3 c2 = vec3(-0.319631,0.243490,0.156419);
    const vec3 c3 = vec3(-4.629188,-5.882803,-19.646115);
    const vec3 c4 = vec3(6.181719,14.388598,57.442181);
    const vec3 c5 = vec3(4.876952,-13.955112,-66.125783);
    const vec3 c6 = vec3(-5.513165,4.709245,26.582180);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}

//shifts value range from -1-1 to 0-1
float make0to1(float x) {
    return (1.0 + x) / 2.0;
}

//shifts value range from 0-1 to -1-1
vec2 makeM1to1(vec2 x) {
    return (x - 0.5) * 2.0;
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
    spiral -= 1.212;
    spiral = 1.+ (pow(1.57*(spiral)+0.8,2.)/spiral);
        
    float flowAngle = pi + angle -(dist*curl) -(spiral*0.8);
    
    // left slanted donut https://www.desmos.com/calculator/uxyefly7fi
    float spiralStrength = 0.05;
    float mask = (1. - spiralStrength)-(pow(dist*size-hole, 2.0)/dist);
    mask += spiral*spiralStrength; 
    mask = clamp(mask, 0.0, 1.0);  // saturate
    
    vec2 flow = normalize(vec2(cos(flowAngle),sin(flowAngle)));
    flow *= mask; // apply strength mask
    
    //flow = (flow+1.0)/2.0; // to save as texture
    flow += vec2(0.0001,0.0001); //adding tiny offset so it isnt 0
    return flow;
}

// generates pixelated directional waves
float flowHexCell(vec2 uv, vec2 offset, float gridRes, float time, float len) {    
    hexParams hexValues = hexTile(uv * gridRes + offset); 
    hexValues.gv =  hexValues.gv / gridRes;
    hexValues.id = (hexValues.id - offset)/ gridRes;    
    
    float radius = 0.3; // of the first spiral 
    //cyclone like flowmap
    vec2 flowMap = cycloneFlow(hexValues.id - vec2(0.885, 0.5), radius, time*0.2);    
    
    float speed = length(flowMap); // Wind Speed    
    vec2 dir = normalize(flowMap); // Wind Direction    
    len *= pow(speed,0.5); // make slower waves smaller
    float k = twoPi / len; //Wave Number    
    float a = pow(speed,1.5); //Amplitude 
    float s = speed; //Steepness
    time *= sqrtG * sqrt(len); // deep water speed
    
    float dD = dot(uv,dir); //Directional/Straight Wave
    //float cD = length(hexValues.gv + (dir/(gridRes))); //Circular Wave
    
    //add random phase offsets for even FlowMaps or you get interference
    //time += texture( iChannel0, hexValues.id).x;
    
    float wave = make0to1(sin(k * (dD - time))); // make sin wave
    //wave = (1.- pow(wave, (1.-s/2.))); //cheap gerstner height wave aprox
    
    wave *= a * hexValues.edist; // apply amplitue and alpha mask    
    return wave;
}

// 3 hex pixaled flowing sin thier edges get hidden by each other
float triDirectionalFlow(vec2 uv, float gridRes, float time, float len) {
    float a = flowHexCell(uv, vec2(0.,0.), gridRes, time, len);
    float b = flowHexCell(uv, vec2(0,inv_sqrt3), gridRes, time, len);
    float c = flowHexCell(uv, vec2(0.5,inv_twice_sqrt3), gridRes, time, len);

    return a + b + c;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    float gridRes = 32.0; //Hex Grid Resolution
    float waveLen = 1./ (gridRes * 3.0); // Maximum Sin Wave Length
    float time = iTime * 0.05; // flow speed multiplier
    
    vec2 uv = fragCoord/iResolution.y; //square UVs  
    float wave = triDirectionalFlow(uv,gridRes,time, waveLen);
    
    vec3 col = vec3(viridis(wave));
    fragColor = vec4(col,1);
}