// dltcW4 - hasse
// https://www.shadertoy.com/view/dltcW4
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// Forked from https://www.shadertoy.com/view/ll3Xzf
// Original license text:

// The MIT License
// Copyright © 2016 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Disk projection code (project_disk()) is by me and is CC0.
// Currently, there's some float instability near grazing angles.
// https://math.stackexchange.com/questions/2411047/parameters-of-the-conic-curve-resulting-from-the-perspective-projection-of-a-cir/2411591#comment4978079_2411047
// https://en.wikipedia.org/wiki/Ellipse#General_ellipse
void project_disk(
    vec3 center,
    vec3 normal,
    float radius,
    vec2 proj_info,
    out vec2 proj_center,
    out vec2 major,
    out vec2 minor
){
    float nc = dot(normal, center);
    float r2 = radius * radius;
    float c2r2 = dot(center, center) - r2;
    vec3 n2 = normal * normal;

    vec3 ACF = nc * nc - 2.0f * center * normal * nc + c2r2 * n2;
    float A = ACF.x, C = ACF.y, F = ACF.z;
    float B = 2.0f * c2r2 * normal.x * normal.y - 2.0f * (center.x * normal.y + center.y * normal.x) * nc;

    proj_center = (normal.xy * normal.z * r2 + center.xy * center.z) / (r2 - r2 * n2.z - center.z * center.z);

    float angle = -0.5f * atan(B, A-C);
    float cos_a = cos(angle);
    float sin_a = sin(angle);
    float cos2_a = cos_a * cos_a;

    // TODO: It may be possible to simplify this further.
    float K = A*proj_center.x*proj_center.x + B*proj_center.x*proj_center.y + C*proj_center.y*proj_center.y - F;

    float radius_num = sqrt(abs(K * (2.0f * cos2_a - 1.0f)));
    float major_radius = radius_num * inversesqrt(abs((A + C) * cos2_a - A));
    float minor_radius = radius_num * inversesqrt(abs((A + C) * cos2_a - C));
    
    major = vec2(sin_a, cos_a) * major_radius;
    minor = vec2(cos_a, -sin_a) * minor_radius;

    proj_center *= 2.0f / proj_info;
    major *= 2.0f / proj_info;
    minor *= 2.0f / proj_info;
}

// ray-disk intersection
float iDisk( in vec3 ro, in vec3 rd,               // ray: origin, direction
             in vec3 cen, in vec3 nor, float rad ) // disk: center, normal, radius
{
	vec3  q = ro - cen;
    float t = -dot(nor,q)/dot(rd,nor);
    if( t<0.0 ) return -1.0;
    vec3 d = q + rd*t;
    if( dot(d,d)>(rad*rad) ) return -1.0;
    return t;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec3 tot = vec3(0.0);
    

    vec2 p = (fragCoord.xy/iResolution.xy) * 2.0f - 1.0f;
    float aspect = iResolution.x / iResolution.y;
    p.x *= aspect;


    // camera position
	vec3 ro = vec3( 0,0,1.5 );
	// create view ray
	vec3 rd = normalize(vec3(p.xy, -1.5) );

    // disk animation
	vec3  disk_center = 0.3*sin(iTime*vec3(1.11,1.27,1.47)+vec3(2.0,5.0,6.0));
	vec3  disk_axis = normalize( sin(iTime*vec3(1.23,1.41,1.07)+vec3(0.0,1.0,3.0)) );
    float disk_radius = 0.4 + 0.2*sin(iTime*1.3+0.5);


    // render
   	vec3 col = vec3(0.4)*(1.0-0.3*length(p));

    // raytrace disk
    float t = iDisk( ro, rd, disk_center, disk_axis, disk_radius );
	float tmin = 1e10;
    if( t>0.0 )
	{
    	tmin = t;
		col = vec3(1.0,0.75,0.3)*(0.7+0.2*abs(disk_axis.y));
	}

    tot += col;

    float proj_plane_dist = 1.5 * aspect * 0.5f;
    vec2 proj_info = vec2(proj_plane_dist, proj_plane_dist);
    vec2 proj_center;
    vec2 major;
    vec2 minor;
    project_disk(
        disk_center-ro,
        disk_axis,
        disk_radius,
        proj_info,
        proj_center,
        major,
        minor
    );

    vec2 nmajor = normalize(major);
    vec2 nminor = normalize(minor);

    // Paint major axis point
    if(distance(p, proj_center + major) < 0.015f)
        tot = vec3(0,1,0);

    // Paint major axis line
    if(distance(p, proj_center + dot(p-proj_center, nmajor) * nmajor) < 0.005f && abs(dot(p-proj_center, nmajor)) < length(major))
        tot = vec3(0,1,0);

    // Paint minor axis point
    if(distance(p, proj_center + minor) < 0.015f)
        tot = vec3(0,0,1);

    // Paint minor axis line
    if(distance(p, proj_center + dot(p-proj_center, nminor) * nminor) < 0.005f && abs(dot(p-proj_center, nminor)) < length(minor))
        tot = vec3(0,0,1);

    // Paint center of projected ellipse
    if(distance(p, proj_center) < 0.015f)
        tot = vec3(1,0,0);

	fragColor = vec4( tot, 1.0 );
}