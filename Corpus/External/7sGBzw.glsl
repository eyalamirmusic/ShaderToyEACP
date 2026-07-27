// 7sGBzw - gehtsiegarnixan
// https://www.shadertoy.com/view/7sGBzw
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
Simple 3D Cubic Tiling. It looks like triangles and hexagons, because I rotated 
it a bit. What you see is the Edge Distance.

This project contains algorithms for the edge distance, center distance, ID and 
UVW coordinates of a cubeic honeycomb grid.

The caluclation for the cube gird is very fast. I wonder, if this is faster to 
calculate 3D cubes and rotate them compated to making a 2D triangle grid the 
normal way. Maybe I'll test that later.
*/

#define sqrt25 			0.6324555320 //sqrt(2./5.)
#define sqrt35 			0.7745966692 //sqrt(3./5.)

//edge distance of a Cube
float cubeDist(vec3 uvw) {
    vec3 d = abs(uvw); //mirroring along axis
    return max(d.x, max(d.y, d.z))*2.; //*2. for 0-1 range
}

// Cube Tiling
vec4 cubeTile(vec3 uvw) {
    vec3 grid = fract(uvw)-.5; // centered UVW coords
    float edist = 1.-cubeDist(grid); // edge distance
    //float cdist = dot(grid,grid); //squared center distance
    //vec3 id = uvw-grid; // Cells IDs

    return vec4(grid, edist);
}

// scaled with offset cube tiling
vec4 cubeCell(vec3 uvw, vec3 offset, float gridRes) {
    vec4 cubeTiling = cubeTile(uvw*gridRes + offset);
    vec3 tiledUV = (cubeTiling.xyz - offset)/gridRes; //cube pixaltion
    
    return vec4(tiledUV,cubeTiling.w);
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

// makes RdYlBu_r colormap with polynimal 6 https://www.shadertoy.com/view/Nd3fR2
vec3 RdYlBu_r(float t) {
    const vec3 c0 = vec3(0.207621,0.196195,0.618832);
    const vec3 c1 = vec3(-0.088125,3.196170,-0.353302);
    const vec3 c2 = vec3(8.261232,-8.366855,14.368787);
    const vec3 c3 = vec3(-2.922476,33.244294,-43.419173);
    const vec3 c4 = vec3(-34.085327,-74.476041,37.159352);
    const vec3 c5 = vec3(50.429790,67.145621,-1.750169);
    const vec3 c6 = vec3(-21.188828,-20.935464,-6.501427);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
    vec2 uv = fragCoord/iResolution.y; //square UV pattern
    float time = (0.05*iTime); // used as z dimension  
    float gridRes = 2.5; //size of cubes
    
    vec3 point = vec3(uv, time); //uvw cords
    
    //cosmetic rotate for fun triangles otherwise it looks so square
    point = rotate(point, (vec3(sqrt25,sqrt35,0.))); //vec3 must be normalized
    
    vec4 a = cubeCell(point, vec3(0.), gridRes);  
    
    vec3 col = RdYlBu_r(a.w); // cosmetic Colormap
    
    fragColor = vec4(col, 1.);
}