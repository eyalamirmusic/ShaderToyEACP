// Wdd3zs - pineapplemachine
// https://www.shadertoy.com/view/Wdd3zs
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// This shader was written by Sophie Kirschner.
// It is released under a CC0 public domain license.

// Maximum number of reflections/refractions per fragment
// Higher numbers look better but are more demanding
#define MAX_PATHS 8

// Color of the "void" - the space behind the scene
#define VOID_COLOR vec3(0.45, 0.65, 0.8)

// Set to 1.0 for a nice typical viewing experience.
// Set higher to reduce the FOV and produce a zoomed-in effect.
// Set lower to increase FOV and produce a fisheye effect.
#define CAMERA_ZOOM 1.0

// The scene is illuminated by a directional light and
// an ambient light; their parameters are defined here.
#define LIGHT_DIRECTION normalize(vec3(-4.7, -4.2, 9.5))
#define AMBIENT_LIGHT 0.3

// Name the various recognized material numbers.
#define MATERIAL_NONE 0
#define MATERIAL_RED_LIGHTER 1
#define MATERIAL_RED_DARKER 2
#define MATERIAL_GREEN_LIGHTER 3
#define MATERIAL_GREEN_DARKER 4
#define MATERIAL_PLANE 5

// Number of vertices in the scene's vertices[] array
#define NUM_VERTICES 17
// Number of triangles in the scene's triangles[] array
#define NUM_TRIANGLES 14

// Struct returned by the cast_ray function
struct cast_ray_result {
    // Identify the triangle within the triangles[] array
    // that the ray intersected
    int tri_index;
    // UV describing where on the triangle the intersection occurred
    vec2 uv;
    // Distance to the intersected point on the triangle
    float dist;
    // 3D position of the ray/triangle intersection
    vec3 intersection;
};

// Describe the position of verticies in 3D space
const vec3 vertices[NUM_VERTICES] = vec3[NUM_VERTICES](
    // Big Transparent Pyramid
    vec3(+0.0, +2.0, +0.0),
    vec3(+1.0, +0.0, +1.0),
    vec3(-1.0, +0.0, +1.0),
    vec3(+1.0, +0.0, -1.0),
    vec3(-1.0, +0.0, -1.0),
    // Small Green Pyramid
    vec3(+2.0, +1.0, +2.0),
    vec3(+2.5, +0.0, +2.5),
    vec3(+1.5, +0.0, +2.5),
    vec3(+2.5, +0.0, +1.5),
    vec3(+1.5, +0.0, +1.5),
    // Plane
    vec3(-4.0, +0.0, -4.0),
    vec3(-4.0, +0.0, +4.0),
    vec3(+4.0, +0.0, -4.0),
    vec3(+4.0, +0.0, +4.0),
    vec3(+4.0, +1.0, -4.0),
    vec3(+4.0, +1.0, +4.0),
    vec3(-4.0, +1.0, +4.0)
);
    
// Describe triangles by identifying their verticies.
// The w component describes the triangle's material.
const ivec4 triangles[NUM_TRIANGLES] = ivec4[NUM_TRIANGLES](
    // Big Transparent Pyramid
    ivec4(0, 2, 1, MATERIAL_RED_LIGHTER),
    ivec4(0, 4, 2, MATERIAL_RED_DARKER),
    ivec4(0, 3, 4, MATERIAL_RED_LIGHTER),
    ivec4(0, 1, 3, MATERIAL_RED_DARKER),
    // Small Green Pyramid
    ivec4(5, 7, 6, MATERIAL_GREEN_DARKER),
    ivec4(5, 9, 7, MATERIAL_GREEN_LIGHTER),
    ivec4(5, 8, 9, MATERIAL_GREEN_DARKER),
    ivec4(5, 6, 8, MATERIAL_GREEN_LIGHTER),
    // Plane
    ivec4(10, 11, 12, MATERIAL_PLANE),
    ivec4(13, 12, 11, MATERIAL_PLANE),
    ivec4(14, 12, 13, MATERIAL_PLANE),
    ivec4(15, 14, 13, MATERIAL_PLANE),
    ivec4(15, 13, 16, MATERIAL_PLANE),
    ivec4(13, 11, 16, MATERIAL_PLANE)
);

// Get surface color given a material number
// plus ray intersection data.
vec3 get_material_color(int material, cast_ray_result ray) {
    return (
        material == MATERIAL_RED_LIGHTER ? vec3(1.0, 0.8, 0.8) :
        material == MATERIAL_RED_DARKER ? vec3(1.0, 0.4, 0.4) :
        material == MATERIAL_GREEN_LIGHTER ? vec3(0.1, 0.8, 0.3) :
        material == MATERIAL_GREEN_DARKER ? vec3(0.0, 0.6, 0.1) :
        material == MATERIAL_PLANE ? vec3(0.25 + ray.uv * 0.5, 0.75) :
        VOID_COLOR
    );
}

// Get reflectivity of a material.
// 0.0 is not reflective at all.
// 1.0 is maximally reflective, a perfect mirror.
float get_material_reflectivity(int material) {
    return (
        material == MATERIAL_NONE ? 0.0 :
        material == MATERIAL_PLANE ? 0.8 :
        material == MATERIAL_RED_LIGHTER ? 0.25 :
        material == MATERIAL_RED_DARKER ? 0.25 :
        0.125
    );
}

// Get index of refraction of a material.
float get_material_refraction(int material) {
    return (
        material == MATERIAL_RED_LIGHTER ? 1.25 :
        material == MATERIAL_RED_DARKER ? 1.25 :
        0.0
    );
}

// Get opacity of a material.
// 0.0 is totally transparent.
// 1.0 is completely opaque.
float get_material_opacity(int material) {
    return (
        material == MATERIAL_RED_LIGHTER ? 0.25 :
        material == MATERIAL_RED_DARKER ? 0.25 :
        1.0
    );
}

// Determine whether a line intersects a triangle.
// Returns a vector whose components are: (intersected?, U, V)
// https://www.shadertoy.com/view/MlGcDz
vec3 line_intersects_tri(vec3 line_a, vec3 line_b, vec3 tri_a, vec3 tri_b, vec3 tri_c) {
    vec3 v1v0 = tri_b - tri_a;
    vec3 v2v0 = tri_c - tri_a;
    vec3 rov0 = line_a - tri_a;
    vec3 n = cross(v1v0, v2v0);
    vec3 q = cross(rov0, line_b);
    float d = 1.0 / dot(line_b, n);
    float u = d * dot(-q, v2v0);
    float v = d * dot(q, v1v0);
    float t = d * dot(-n, rov0);
    if(u < 0.0 || v < 0.0 || (u + v) > 1.0) t = -1.0;
    return vec3(t, u, v);
}

// Given the three points of a triangle in clockwise order,
// compute the surface normal of that triangle.
// https://www.khronos.org/opengl/wiki/Calculating_a_Surface_Normal#targetText=A%20surface%20normal%20for%20a,winding).
vec3 get_tri_surface_normal(vec3 tri_a, vec3 tri_b, vec3 tri_c) {
    vec3 u = tri_b - tri_a;
    vec3 v = tri_c - tri_a;
    return normalize(cross(u, v));
}

// Generate a look-at rotation matrix based on a camera
// position and view target.
// https://www.scratchapixel.com/lessons/mathematics-physics-for-computer-graphics/lookat-function
mat3 look_at_matrix(vec3 camera_position, vec3 camera_target) {
    vec3 forward = normalize(camera_target - camera_position);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    return mat3(right, up, forward);
}

// Check all triangles in the scene for intersection with a ray.
// Return information about the intersection nearest to ray_origin,
// if there was any intersection.
cast_ray_result cast_ray(vec3 ray_origin, vec3 ray_target) {
    int result_tri_index = -1;
    vec2 result_uv = vec2(0.0);
    float result_dist = 1e18;
    vec3 result_intersection = vec3(0.0);
    for(int tri_index = 0; tri_index < NUM_TRIANGLES; tri_index++) {
        vec3 tri_a = vertices[triangles[tri_index].x];
        vec3 tri_b = vertices[triangles[tri_index].y];
        vec3 tri_c = vertices[triangles[tri_index].z];
        vec3 intersection = line_intersects_tri(
            ray_origin, ray_target, tri_a, tri_b, tri_c
        );
        vec3 intersection_point = (
            (tri_b * intersection.y) +
            (tri_c * intersection.z) +
            (tri_a * (1.0 - intersection.y - intersection.z))
        );
        float tri_distance = length(
            ray_origin - intersection_point
        );
        if(intersection.x > 0.0 &&
            tri_distance > 1e-5 &&
            tri_distance < result_dist
        ) {
            result_tri_index = tri_index;
            result_uv = intersection.yz;
            result_dist = tri_distance;
            result_intersection = intersection_point;
        }
    }
    return cast_ray_result(
        result_tri_index,
        result_uv,
        result_dist,
        result_intersection
    );
}

// Cast a ray from a surface toward the scene's directional light
// source and determine how much in shadow the surface is.
// Considers opacity, but not refraction.
float cast_shadow_ray(vec3 ray_origin, vec3 ray_target) {
    float shadow_amount = 0.0;
    for(int tri_index = 0; tri_index < NUM_TRIANGLES; tri_index++) {
        vec3 tri_a = vertices[triangles[tri_index].x];
        vec3 tri_b = vertices[triangles[tri_index].y];
        vec3 tri_c = vertices[triangles[tri_index].z];
        vec3 intersection = line_intersects_tri(
            ray_origin, ray_target, tri_a, tri_b, tri_c
        );
        vec3 intersection_point = (
            (tri_b * intersection.y) +
            (tri_c * intersection.z) +
            (tri_a * (1.0 - intersection.y - intersection.z))
        );
        float tri_distance = length(
            ray_origin - intersection_point
        );
        if(intersection.x > 0.0 &&
            tri_distance > 1e-5
        ) {
            shadow_amount += (
                get_material_opacity(triangles[tri_index].w)
            );
            if(shadow_amount >= 1.0) {
                break;
            }
        }
    }
    return shadow_amount;
}

// Trace the path of a ray, i.e. from the camera position to a
// ray direction depending on a fragment's position in the render.
// The function will incorporate up to MAX_PATHS reflections and
// refractions in the final sample color.
vec3 sample_ray(vec3 ray_origin, vec3 ray_target) {
    // Initialize the ray queue -
    // list of ray paths that should contribute to this sample
    // It will initially contain only the input sample
    int next_path_index = 1;
    vec3 queued_ray_origin[MAX_PATHS];
    vec3 queued_ray_target[MAX_PATHS];
    float queued_ray_weight[MAX_PATHS];
    float color_accumulator_weight = 0.0;
    vec3 color_accumulator = vec3(0.0);
    queued_ray_origin[0] = ray_origin;
    queued_ray_target[0] = ray_target;
    queued_ray_weight[0] = 1.0;
    // Enumerate rays in the queue
    for(int path_index = 0; path_index < MAX_PATHS; path_index++) {
        // Check for queue exhaustion
        if(path_index >= next_path_index) {
            break;
        }
        // Ignore rays with a very small contribution to the overall
        // sample result
        float this_ray_weight = queued_ray_weight[path_index];
        if(this_ray_weight < 0.02) {
            continue;
        }
        // Time to trace the ray
        vec3 this_ray_origin = queued_ray_origin[path_index];
        vec3 this_ray_target = queued_ray_target[path_index];
        cast_ray_result this_ray = cast_ray(
            this_ray_origin, this_ray_target
        );
        vec3 tri_normal = get_tri_surface_normal(
            vertices[triangles[this_ray.tri_index].x],
            vertices[triangles[this_ray.tri_index].y],
            vertices[triangles[this_ray.tri_index].z]
        );
        // Get material properties for the intersected triangle
        int material = (this_ray.tri_index >= 0 ?
            triangles[this_ray.tri_index].w : MATERIAL_NONE
        );
        vec3 material_color = get_material_color(material, this_ray);
        float material_reflectivity = get_material_reflectivity(material);
        float material_opacity = get_material_opacity(material);
        // Calculate diffuse directional lighting with shadows
        float shadow_amount = cast_shadow_ray(
            this_ray.intersection, -LIGHT_DIRECTION
        );
        float diffuse_light_intensity = AMBIENT_LIGHT + max(0.0,
			(1.0 - AMBIENT_LIGHT) * 2.0 * dot(tri_normal, -LIGHT_DIRECTION)
        );
        float light_intensity = clamp(
			AMBIENT_LIGHT + diffuse_light_intensity - shadow_amount,
            AMBIENT_LIGHT, 1.0
		);
        // Cast a reflection ray
        // http://paulbourke.net/geometry/reflected/
        // https://www.fabrizioduroni.it/2017/08/25/how-to-calculate-reflection-vector.html
        if(material_reflectivity > 1e-3) {
            vec3 reflected_ray_target = this_ray_target - (
                2.0 * tri_normal * dot(this_ray_target, tri_normal)
            );
            queued_ray_weight[next_path_index] = (
                this_ray_weight * material_reflectivity
            );
            queued_ray_origin[next_path_index] = this_ray.intersection;
        	queued_ray_target[next_path_index] = reflected_ray_target;
            next_path_index++;
        }
        // Cast a refracted ray for transparent surfaces
        if(material_opacity < (1.0 - 1e-3)) {
            // Compute the refracted ray direction
            // https://www.scratchapixel.com/lessons/3d-basic-rendering/introduction-to-shading/reflection-refraction-fresnel
            float refraction = get_material_refraction(material);
            float iof_before = 1.0;
            float iof_after = refraction;
            float cos_incidence = dot(tri_normal, this_ray_target);
            vec3 refraction_normal = tri_normal;
            if(cos_incidence < 0.0) {
                cos_incidence = -cos_incidence;
            }
            else {
                iof_before = refraction;
                iof_after = 1.0;
                refraction_normal = -refraction_normal;
            }
            float eta = iof_before / iof_after;
            float k = 1.0 - eta * eta * (1.0 - cos_incidence * cos_incidence);
            vec3 refracted_ray_target = (
                k < 0.0 ? this_ray_target :
                eta * this_ray_target + (eta * cos_incidence - sqrt(k)) * refraction_normal
            );
            // Add refraced ray to the queue
            queued_ray_weight[next_path_index] = (
                this_ray_weight * (1.0 - material_opacity)
            );
            queued_ray_origin[next_path_index] = this_ray.intersection;
        	queued_ray_target[next_path_index] = refracted_ray_target;
            next_path_index++;
        }
        // Determine the color sampled at the end of this ray
        // and add it to the accumulator
        vec3 this_sample_color = light_intensity * material_color;
        float this_sample_weight = max(0.0, (
            this_ray_weight * material_opacity * (1.0 + light_intensity)
        ));
        color_accumulator = (
            color_accumulator * color_accumulator_weight +
            this_sample_color * this_sample_weight
        ) / (
            color_accumulator_weight + this_sample_weight
        );
        color_accumulator_weight += this_sample_weight;
    }
    // No more paths to trace! Return the final sample color.
    return color_accumulator;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Describe the position of the camera in the scene
    float t = 1.5 + 0.75 * iTime;
    vec3 camera_position = vec3(6.0 * cos(t), 3.5, 6.0 * sin(t));
    vec3 camera_target = vec3(0.0, 0.0, 0.0);
    mat3 camera_rot_matrix = look_at_matrix(
        camera_position, camera_target
    );
    // Determine the direction of the ray
    // Rays toward the center of the view travel in a more
    // directly forward direction; rays toward the edges of
    // the view travel at more of an angle to the camera.
    // This produces a nice field-of-view effect.
    vec2 ray_coord = (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    vec3 forward_ray_direction = normalize(
        vec3(ray_coord.x, ray_coord.y, CAMERA_ZOOM)
    );
    vec3 ray_direction = camera_rot_matrix * forward_ray_direction;
    // Calculate the color of the fragment at this location.
    vec3 sample_color = sample_ray(camera_position, ray_direction);
    fragColor = vec4(sample_color, 1.0);
}
