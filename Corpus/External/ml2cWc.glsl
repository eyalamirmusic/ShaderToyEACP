// ml2cWc - MattOstgard
// https://www.shadertoy.com/view/ml2cWc
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2016 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


// Intersection of a ray and a capped cylinder oriented in an arbitrary direction
//
// List of ray-surface intersectors at https://www.shadertoy.com/playlist/l3dXRf
//
// and https://iquilezles.org/articles/intersectors
//
// Other cylinder functions:
//   Cylinder intersection: https://www.shadertoy.com/view/4lcSRn
//   Cylinder bounding box: https://www.shadertoy.com/view/MtcXRf
//   Cylinder distance:     https://www.shadertoy.com/view/wdXGDr


// Intersection of a ray and a capped cylinder oriented in an arbitrary direction.
//
// Arguments:
//     - ro: The origin of the ray being cast.
//     - rd: The direction of the ray being cast.
//     - pa: One endpoint of the cylinder's axis.
//     - pb: The other endpoint of the cylinder's axis.
//     - ra: Cylinder's radius.
//
// Returns vec4:
//     - x: -1 if no hit, otherwise the distance from the ray to the hit point.
//     - yzw: Hit surface's normal.
vec4 iCylinder( in vec3 ro, in vec3 rd, in vec3 pa, in vec3 pb, float ra ) 
{
    // Vector from point A to point B, defining the cylinder's main axis
    vec3  ba = pb - pa;
    // Vector from ray origin (ro) to point A on the cylinder
    vec3  oc = ro - pa;
    
    // Dot product of ba with itself, representing the squared length of the cylinder's axis
    float baba = dot(ba,ba);
    // Dot product of ba with ray direction (rd), representing alignment of ray with cylinder's axis
    float bard = dot(ba,rd);
    // Dot product of ba with oc, representing alignment of the cylinder's axis with the vector to the ray origin
    float baoc = dot(ba,oc);
    
    // Quadratic coefficients for solving ray-cylinder intersection
    float k2 = baba            - bard*bard;
    float k1 = baba*dot(oc,rd) - baoc*bard;
    float k0 = baba*dot(oc,oc) - baoc*baoc - ra*ra*baba;
    
    /*
    // In case you really need to handle parallel raycasts.
    if( k2==0.0 )
    {
        // Handle the case where the ray is parallel to the cylinder's axis.

        // If this special case is detected (i.e., k2 == 0.0), calculate intersections with the two endpoints of the
        // cylinder and verify that the intersection is within the cylinder's radius. If so, it returns the intersection
        // point and surface normal information. If not, it returns -1.0, indicating no intersection.
        
        // Parameters for intersection with the two endpoints of the cylinder.
        float ta = -dot(ro-pa,ba)/bard;
        float tb = ta + baba/bard;
        
        // Determining the intersection point based on ray direction.
        vec4 pt = (bard>0.0) ? vec4(pa,-ta) : vec4(pb,tb);
        
        // Calculating the offset from the intersection point to determine if the intersection is within the cylinder's radius.
        vec3 q = ro + rd*abs(pt.w) - pt.xyz;
        if( dot(q,q)>ra*ra ) return vec4(-1.0);
        
        // Returning the intersection point and surface normal information.
        return vec4( abs(pt.w), sign(pt.w)*ba/sqrt(baba) );
    }
    */
    
    // Discriminant of the quadratic equation; determines whether there is an intersection.
    float h = k1*k1 - k2*k0;
    if( h<0.0 ) return vec4(-1.0); // No intersection.
    h = sqrt(h);
    float t = (-k1-h)/k2; // The "t" value where the intersection occurs.
    
    // Checking intersection with the body of the cylinder.
    float y = baoc + t*bard;
    if( y>0.0 && y<baba ) return vec4( t, (oc+t*rd - ba*y/baba)/ra );
    
    // Checking intersection with the end caps of the cylinder.
    t = ( ((y<0.0) ? 0.0 : baba) - baoc)/bard;
    if( abs(k1+k2*t)<h ) return vec4( t, ba*sign(y)/sqrt(baba) );
    
    return vec4(-1.0); // No intersection.
}


// Get the normal of a cylinder's body from a point on the surface.
//
// Arguments:
//     - p: Point on the cylinder body.
//     - 'a' and 'b': Points along the axis of the cylinder, defining its direction.
//     - 'ra': The radius of the cylinder.
//
// Returns the cylinder body's normal.
//
vec3 nCylinder( in vec3 p, in vec3 a, in vec3 b, in float ra )
{
    // 'pa' is the vector from point 'a' to the point 'p' where we want to find the normal.
    vec3  pa = p - a;

    // 'ba' is the vector from point 'a' to point 'b', defining the direction of the cylinder's axis.
    vec3  ba = b - a;

    // 'baba' is the squared length of vector 'ba', used to normalize 'ba'.
    float baba = dot(ba,ba);

    // 'paba' is the projection of 'pa' onto 'ba', giving us the portion of 'pa' that is parallel to the cylinder's axis.
    float paba = dot(pa,ba);

    // Subtracting the projected vector (ba * paba / baba) from 'pa' gives us the vector perpendicular to the axis, 
    // pointing towards the surface of the cylinder from 'p'. Dividing by 'ra' scales it to the normal direction.
    return (pa - ba*paba/baba)/ra;
}


// Same as above, but specialized to the Y axis.
//
// Arguments:
//     - ro: The origin of the ray being cast.
//     - rd: The direction of the ray being cast.
//     - he: Cylinder's height.
//     - ra: Cylinder's radius.
//
// Returns vec4:
//     - x: -1 if no hit, otherwise the distance from the ray to the hit point.
//     - yzw: Hit surface's normal.
//
vec4 iCylinderVertical( in vec3 ro, in vec3 rd, float he, float ra )
{
    // Quadratic coefficients for ray-cylinder intersection with a vertical axis.
    float k2 = 1.0        - rd.y*rd.y;
    float k1 = dot(ro,rd) - ro.y*rd.y;
    float k0 = dot(ro,ro) - ro.y*ro.y - ra*ra;

    // Discriminant of the quadratic equation; determines whether there is an intersection.
    float h = k1*k1 - k2*k0;
    if( h<0.0 ) return vec4(-1.0); // No intersection.
    h = sqrt(h);
    float t = (-k1-h)/k2;

    // Checking intersection with the body of the cylinder.
    float y = ro.y + t*rd.y;
    if( y>-he && y<he ) return vec4( t, (ro + t*rd - vec3(0.0,y,0.0))/ra );

    // Checking intersection with the end caps of the cylinder.
    t = ( ((y<0.0)?-he:he) - ro.y)/rd.y;
    if( abs(k1+k2*t)<h ) return vec4( t, vec3(0.0,sign(y),0.0) );

    return vec4(-1.0); // No intersection
}

// Generate a pattern (grid-like) based on the given UV coordinates.
vec3 pattern( in vec2 uv )
{
    vec3 col = vec3(0.6);
    col += 0.4*smoothstep(-0.01,0.01,cos(uv.x*0.5)*cos(uv.y*0.5)); 
    col *= smoothstep(-1.0,-0.98,cos(uv.x))*smoothstep(-1.0,-0.98,cos(uv.y));
    return col;
}

#define AA 3

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Define camera rotation and position.
    float an = 0.5*iTime;
    vec3 ro = vec3( 1.0*cos(an), 0.4, 1.0*sin(an) );
    vec3 ta = vec3( 0.0, 0.0, 0.0 );
    
    // Create camera's orthonormal basis (u,v,w).
    vec3 ww = normalize( ta - ro );
    vec3 uu = normalize( cross(ww,vec3(0.0,1.0,0.0) ) );
    vec3 vv = normalize( cross(uu,ww));
    
    vec3 tot = vec3(0.0);

    // Anti-aliasing loop (if AA > 1).
    #if AA>1
    for( int m=0; m<AA; m++ )
    for( int n=0; n<AA; n++ )
    {
        // Subpixel sampling.
        vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
        vec2 p = (-iResolution.xy + 2.0*(fragCoord+o))/iResolution.y;
        #else    
        vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y;
        #endif

        // Create view ray.
        vec3 rd = normalize( p.x*uu + p.y*vv + 1.5*ww );

        // Define cylinder.
        const vec3  capA = vec3(-0.3,-0.1,-0.1);
        const vec3  capB = vec3(0.3,0.1,0.4);
        const float capR = 0.2;

        // Initialize background color.
        vec3 col = vec3(0.08)*(1.0-0.3*length(p)) + 0.02*rd.y;

        // Cylinder-ray intersection.
        vec4 tnor = iCylinder( ro, rd, capA, capB, capR );
        if( tnor.x>0.0 )
        {
            // Compute shading, texture, and lighting if intersection occurred.

            // SHADING
            // Calculating the position and normal at the intersection.
            float t = tnor.x;
            vec3  pos = ro + t*rd;
            vec3  nor = tnor.yzw;

            // LIGHTING
            // Define the light direction and halfway vector.
            vec3  lig = normalize(vec3(0.7,0.6,0.3));
            vec3  hal = normalize(-rd+lig);

            // Calculate the diffuse and ambient components using dot products.
            float dif = clamp( dot(nor,lig), 0.0, 1.0 ); // Diffuse lighting
            float amb = clamp( 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0)), 0.0, 1.0 ); // Ambient lighting
            float occ = 0.5 + 0.5*nor.y; // Occlusion factor, contributes to ambient shading

            // TEXTURING
            // Coordinate transformation for texture mapping on the cylinder.
            vec3 w = normalize(capB-capA);
            vec3 u = normalize(cross(w,vec3(0,0,1)));
            vec3 v = normalize(cross(u,w) );
            vec3 q = (pos-capA)*mat3(u,v,w);
            col = pattern( vec2(12.0,64.0)*vec2(atan(q.y,q.x),q.z) ); // Apply texture pattern.

            // Combine shading, texturing, and lighting
            col *= vec3(0.2,0.3,0.4)*amb*occ + vec3(1.0,0.9,0.7)*dif; // Apply ambient and diffuse components.
            col += 0.4*pow(clamp(dot(hal,nor),0.0,1.0),12.0)*dif; // Apply specular reflection.
        }
        col = sqrt( col );

        // Accumulate color.
        tot += col;
    #if AA>1
    }
    // Average color for anti-aliasing.
    tot /= float(AA*AA);
    #endif

    // Add dithering to remove banding in the background.
    tot += fract(sin(fragCoord.x*vec3(13,1,11)+fragCoord.y*vec3(1,7,5))*158.391832)/255.0;

    // Output final color.
    fragColor = vec4( tot, 1.0 );
}
