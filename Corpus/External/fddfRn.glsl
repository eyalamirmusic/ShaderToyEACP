// fddfRn - gehtsiegarnixan
// https://www.shadertoy.com/view/fddfRn
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
Rhombic Dodecahedron Tiling perfectly in 3D space.
I made four perfectly overlaying Rhombic Dodecahedron Grid Tiles. In the pattern I
aranged them they have a very useful property. If you add up the edge distance of 
all 4 grids they add up to 1 in all points. This allows us to do bilinear 
interpolation between 4 samples in 3D space. 

This project contains: 
- Rhombic Dodecahedron Distance function. 
- An infinite Rhombic Dodecahedron Gird Tiling with Center Distance, Edge Distance, 
    centered UVW Coordinates, and Cell ID. 
- Four Rhombic Dodecahedron Girds with the grids being offset so that their
    edges get perfectly hidden by each other

I created this for a 3D version of the Hex Directional Flow with only 4 flowmaps 
+ 4 textures samples. In contrast the original directional flow has 8 flowmaps + 
8 textures when used in 3D. But to showcase it here, I need a nice 3D Flow 
and Texture. Maybe I will make it in future.
*/

//#define ZEROTOONE

// show the alpha instead of UVWs
#define ALPHA

#define sqrt2 			1.4142135624 //sqrt(2.)
#define half_sqrt2		0.7071067812 //sqrt(2.)/2.
#define qurt_sqrt2		0.3535533906 //sqrt(2.)/4.

// Increases the steepness of Alpha while preserving 0-1 range and 1 sum
// See 2 value example (https://www.desmos.com/calculator/dpxa6mytnv)
vec4 smoothContrast(vec4 alpha, float contrast) {
    // increase steepness using power
    vec4 powAlpha = pow(alpha, vec4(contrast));
    
    // normalize back to precentage of 1
    return powAlpha/(powAlpha.x + powAlpha.y + powAlpha.z + powAlpha.w);
}

//Distance from the Edge of Rhombic Dodecahedron
float rhomDist(vec3 p) {
    vec3 hra = vec3(0.5, 0.5, half_sqrt2); //vector to Diagonal Edge
    p = abs(p);
    float pBC = max(p.x,p.y); //rigt and top edge
    float pABC = max(dot(p, hra),pBC); //diagonal edge
    
    //optional 0-1 range
    return (.5-pABC)*2.;
}

// struct to hold 5 floats at a time of my tiling functions
struct tilingVal3D 
{
    vec3 grid;       // Coordinates of the cell in the grid (UV centered on cell)
    vec3 id;         // ID values
    float alpha;  // Edge distance from the cell's center to its boundaries
};

//Rhombic Dodecahedron Tiling
tilingVal3D rohmTile(vec3 uvw) {
    vec3 r = vec3(1.0,1.0,sqrt2);
    vec3 h = r*.5;

    vec3 a = mod(uvw, r)-h;
    vec3 b = mod(uvw-h,r)-h;
    
    vec3 gvw = dot(a, a) < dot(b,b) ? a : b; //center rhom uvw
    float edist = rhomDist(gvw); //Edge distance with range 0-1
    //float cdist = dot(gvw, gvw); // squared distance with range 0-1
    vec3 id = uvw-gvw; // simple ID calculation
    
    return tilingVal3D(gvw, id, edist);
}

// scaled with offset Rhombic Dodecahedron tiling
tilingVal3D rohmCell(vec3 uvw, vec3 offset, float gridRes) {
    tilingVal3D rohmTiling = rohmTile(uvw*gridRes + offset);
    vec3 tiledUV = (rohmTiling.id - offset)/gridRes; //rohm pixaltion    
    return tilingVal3D(rohmTiling.grid, tiledUV,rohmTiling.alpha);
}

// 4 Rhombic Dodecahedron tiles offset so their edges get hidden by each other
vec3 quadGrid(vec3 uvw, float gridRes, float contrast) {
    tilingVal3D a = rohmCell(uvw, vec3( .0, .0, .0), gridRes);
    tilingVal3D b = rohmCell(uvw, vec3( .5, .0, qurt_sqrt2), gridRes);
    tilingVal3D c = rohmCell(uvw, vec3( .0, .5, qurt_sqrt2), gridRes);
    tilingVal3D d = rohmCell(uvw, vec3( .0, .0, half_sqrt2), gridRes);
   
    // increase contrast
    vec4 alpha = smoothContrast(vec4(a.alpha, b.alpha, 
                                c.alpha, d.alpha), contrast);
                                
#ifdef ZEROTOONE
    // rescale UVWs to 0-1
    a.grid = a.grid *0.5+0.5;
    b.grid = b.grid *0.5+0.5;
    c.grid = c.grid *0.5+0.5;
    d.grid = d.grid *0.5+0.5;   
#endif
    
    // interpolate UVWs cause shadertoy doesn't have nice 3d Textures
    vec3 col = a.grid * alpha.x +
               b.grid * alpha.y +
               c.grid * alpha.z +
               d.grid * alpha.w;
#ifndef ZEROTOONE
    col *= 2.0;
#endif

#ifdef ALPHA
    col = alpha.xyz;
#endif
    
    return col;
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

void mainImage(out vec4 fragColor, in vec2 fragCoord ) {
    float gridRes = 1.5; //size of Ico
    float contrast = 1.; //1 no contrast, higher values increase contrast
    
    vec2 uv = fragCoord/iResolution.y; //square UV pattern
    float time = (0.1*iTime); // used as z dimension      
    vec3 point = vec3(uv, time); //animated uv cords
    
    //cosmetic rotate for fun hexagons otherwise it looks so square
    point = rotate(point, normalize(vec3(1.,0.,0.))); 
    
    vec3 col = quadGrid(point,gridRes, contrast);
        
    fragColor = vec4(col, 1);
}