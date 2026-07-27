// ssKfRw - gehtsiegarnixan
// https://www.shadertoy.com/view/ssKfRw
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
I made this simple edge distance function for the Cuboctahedron. 
It's basically a cube with cut of corners.

It has mouse controls to rotated around the center.

This shape is one of the two shapes best for close packing of spheres (FCC). 
This shape is not part of the Honeycomb group, so it doesn't tile seamlessly. 
*/

#define pi              3.1415926536

//Distance from the Edge of Cuboctahedron
float cubocDist(vec3 p) {
    vec3 hra = vec3(0.5); //vector to Diagonal Edge
    
    p = abs(p);
    float pAB = max(p.x,p.y); //rigt and left edge  
    float pCD = max(dot(p, hra),p.z); //diagonal and top edge
    
    float pABCD = max(pAB, pCD);
    
    //optional 0-1 range
    return (.5-pABCD)*2.;
}

// makes winter colormap with polynimal 6
vec3 winter(float t) {
    const vec3 c0 = vec3(-0.000000,-0.000941,1.000471);
    const vec3 c1 = vec3(0.000000,1.001170,-0.500585);
    const vec3 c2 = vec3(-0.000000,0.004744,-0.002369);
    const vec3 c3 = vec3(0.000000,-0.011841,0.005901);
    const vec3 c4 = vec3(-0.000000,0.012964,-0.006433);
    const vec3 c5 = vec3(0.000000,-0.005110,0.002500);
    const vec3 c6 = vec3(-0.000000,-0.000046,0.000045);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}

// rotates a vetor from SirBelfer4 (https://www.shadertoy.com/view/ssc3z4)
vec3 rotate(vec3 v, vec3 a)
{
    // https://math.stackexchange.com/questions/2975109/how-to-convert-euler-angles-to-quaternions-and-get-the-same-euler-angles-back-fr
    vec4 q;
    vec3 c = cos(a * 0.5), s = sin(a * 0.5);
    q.x = s.x * c.y * c.z - c.x * s.y * s.z;
    q.y = c.x * s.y * c.z + s.x * c.y * s.z;
    q.z = c.x * c.y * s.z - s.x * s.y * c.z;
    q.w = c.x * c.y * c.z + s.x * s.y * s.z;
    
    // https://blog.molecular-matters.com/2013/05/24/a-faster-quaternion-vector-multiplication/
    vec3 qt = 2.0 * cross(q.xyz, v);
    return v + q.w * qt + cross(q.xyz, qt);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = (fragCoord - iResolution.xy*.5)/iResolution.y; //centered square UVs
    float time = fract(0.2*iTime-0.5)-0.5; // used as z dimension    
    float size = 0.9; //size of Ico
    
    vec3 point = vec3(uv, time)/size; //animated uv cords    
    
    // controls rotates around the center
    vec3 camRot = vec3(0.5 - iMouse.yx / iResolution.yx, 0) * 2.0 * pi;
    camRot.y = -camRot.y;
    point = rotate(point, camRot);
    
    float ico = cubocDist(point); 
    
    ico = clamp(ico, 0.,1.); //saturate so the cmap doesn't break
    vec3 col = winter(1.-ico); // applying cosmetic colormap
    
    fragColor = vec4(col,0);
}