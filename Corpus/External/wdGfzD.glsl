// wdGfzD - IWBTShyGuy
// https://www.shadertoy.com/view/wdGfzD
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc-by-4.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// Copyright © 2020 IWBTShyGuy
// Attribution 4.0 International (CC BY 4.0)

const float PI = 3.141592653;
const float PI2 = 2.0 * PI;

// square
const int N = 4;

// the circumradius of polygon
const float R_POLY = 0.4;

const float SCREW_THICKNESS = 0.02;

// the half of thickness of polygon edges
const float THICKNESS = 0.025;

// Good Colors!!
const vec3 COLOR[N] = vec3[](
    vec3(226.0, 133.0, 27.0) / 255.0,
    vec3(126.0, 107.0, 152.0) / 255.0,
    vec3(238.0, 200.0, 80.0) / 255.0,
    vec3(136.0, 175.0, 34.0) / 255.0
);

// the radius of the vertex of square
const float R_DOT = 0.04;

// normalized fragment coordinate
vec2 uv_coord(vec2 coord) {
    int max_idx = iResolution.x > iResolution.y ? 0 : 1;
    int min_idx = 1 - max_idx;
    vec2 aspect_vec = vec2(1.0, 1.0);
    aspect_vec[max_idx] = iResolution[max_idx] / iResolution[min_idx];
    return 2.0 * coord / iResolution[min_idx] - aspect_vec;
}

// Creates vertices of polygon
vec2[N] createVertex() {
    vec2 vertex[N];
    for (int i = 0; i < N; i++) {
        float theta = float(i) / float(N) * PI2;
        vertex[i] = vec2(cos(theta), sin(theta)) * R_POLY;
    }
    return vertex;
}

float get_angle(in vec2 uv) {
    float theta = acos(uv.x / length(uv));
    if (uv.y < 0.0) theta = 2.0 * PI - theta;
    return theta;
}

float torus_distance(in float x, in float y) {
    float a = abs(x - y);
    float b = abs(PI2 + x - y);
    float c = abs(x - y - PI2);
    return min(a, min(b, c));
}

vec4 renderScrew(in vec2 uv) {
    float len = length(uv);
    float theta = get_angle(uv);
    float c = 0.0;
    int idx = 0;
    for (int i = 0; i < N; i++) {
        if (len < R_POLY) continue;
        float delta = float(i) / float(N);
        float phase = fract((iTime - PI2 * len + PI2 * delta) / PI2) * PI2;
        float dist = smoothstep(0.0, 1.0, (torus_distance(phase, theta) / PI2) / SCREW_THICKNESS);
        if (c < 1.0 - dist * dist * dist) {
            c = 1.0 - dist * dist * dist;
            idx = i % N;
        }
    }
    return vec4(c * COLOR[idx], 1.0);    
}

vec4 renderSquare(in vec4 fragColor, in vec2 uv, in vec2 vertex[N]) {
    float theta = iTime - 2.0 * PI * R_POLY;
    uv = mat2(cos(theta), -sin(theta), sin(theta), cos(theta)) * uv;
    float plus = abs(uv.x + uv.y);
    float minus = abs(uv.x - uv.y);
    if (plus < R_POLY - THICKNESS && minus < R_POLY - THICKNESS)
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    else if (plus < R_POLY + THICKNESS && minus < R_POLY + THICKNESS) {
        float k = 1.0 - abs(plus - R_POLY) / THICKNESS;
        k = max(k, 1.0 - abs(minus - R_POLY) / THICKNESS);
        k = 1.0 - pow(1.0 - k, 5.0);
        vec3 col = vec3(0.0);
        for (int i = 0; i < N; i++) {
            float c = distance(vertex[i], uv) / R_POLY;
            c = smoothstep(0.0, 1.0, c);
            c = 1.0 - pow(c, 3.0);
            col += c * COLOR[i] * k;
        }
        fragColor = vec4(col, 1.0);
    }
    return fragColor;
}

vec4 renderVertices(in vec4 fragColor, in vec2 uv, in vec2 vertex[N]) {
    float theta = iTime - 2.0 * PI * R_POLY;
    uv = mat2(cos(theta), -sin(theta), sin(theta), cos(theta)) * uv;
    for (int i = 0; i < N; i++) {
        if (distance(uv, vertex[i]) < R_DOT) {
            float c = distance(uv, vertex[i]) / R_DOT;
            c = 1.0 - pow(c, 5.0);
            fragColor = vec4(COLOR[i] * c, 1.0);
        }
    }
    return fragColor;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = uv_coord(fragCoord);
    vec2 vertex[N] = createVertex();
    fragColor = renderScrew(uv);
    fragColor = renderSquare(fragColor, uv, vertex);
    fragColor = renderVertices(fragColor, uv, vertex);
}