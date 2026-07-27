// dls3Wr - mkeeter
// https://www.shadertoy.com/view/dls3Wr
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// Using distance-to-quadratic and winding number to generate a closed-form
// distance field of a font outline, which is specified as lines + quadratic
// Bézier curves.
//
// Quadratic solver is based on https://www.shadertoy.com/view/MlKcDD, which
// includes the following copyright notice:
//
//      Copyright © 2018 Inigo Quilez
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// Curves are baked by an external tool
#define QUAD_COUNT 38
const vec2 QUADS[QUAD_COUNT * 3] = vec2[QUAD_COUNT * 3](
    vec2(0.5758487, -4.5724106), vec2(0.5758487, -4.9204984), vec2(0.7176622, -5.221315),
    vec2(0.7176622, -5.221315), vec2(0.8594757, -5.5221314), vec2(1.1216158, -5.758487),
    vec2(0.7520412, -2.0842285), vec2(0.8594757, -1.6974645), vec2(1.0034379, -1.3859046),
    vec2(0.86162436, -3.5904598), vec2(0.5758487, -3.9664803), vec2(0.5758487, -4.5724106),
    vec2(1.0034379, -1.3859046), vec2(1.1474, -1.0743446), vec2(1.3837559, -0.8036098),
    vec2(1.1216158, -5.758487), vec2(1.3708637, -5.9819508), vec2(1.7103566, -6.1087236),
    vec2(1.3794585, -4.9591746), vec2(1.3794585, -4.563816), vec2(1.5642458, -4.3038244),
    vec2(1.3837559, -0.8036098), vec2(1.6072196, -0.55006444), vec2(1.9058874, -0.3996562),
    vec2(1.5642458, -4.3038244), vec2(1.7490331, -4.0438333), vec2(2.101418, -3.8762355),
    vec2(1.6630855, -2.9823806), vec2(1.1474, -3.2144392), vec2(0.86162436, -3.5904598),
    vec2(1.6673828, -5.599484), vec2(1.3794585, -5.337344), vec2(1.3794585, -4.9591746),
    vec2(1.6974645, -0.0021486892), vec2(1.2892135, -0.12892136), vec2(0.99269444, -0.30941126),
    vec2(1.7103566, -6.1087236), vec2(2.0498495, -6.235496), vec2(2.419424, -6.235496),
    vec2(1.9058874, -0.3996562), vec2(2.2045553, -0.24924795), vec2(2.599914, -0.24924795),
    vec2(2.101418, -3.8762355), vec2(2.4151268, -3.7258272), vec2(2.718092, -3.616244),
    vec2(2.2862053, -2.7266867), vec2(1.9252255, -2.862054), vec2(1.6630855, -2.9823806),
    vec2(2.363558, -5.8616242), vec2(1.9553072, -5.8616242), vec2(1.6673828, -5.599484),
    vec2(2.419424, -6.235496), vec2(2.840567, -6.235496), vec2(3.173614, -6.106575),
    vec2(2.5139663, 0.12462398), vec2(2.1057155, 0.12462398), vec2(1.6974645, -0.0021486892),
    vec2(2.599914, -0.24924795), vec2(2.896433, -0.24924795), vec2(3.117748, -0.32660076),
    vec2(2.718092, -3.616244), vec2(3.0210571, -3.506661), vec2(3.3046842, -3.382037),
    vec2(2.9265146, -2.4795873), vec2(2.647185, -2.5913193), vec2(2.2862053, -2.7266867),
    vec2(3.0167596, -5.7133646), vec2(2.7503223, -5.8616242), vec2(2.363558, -5.8616242),
    vec2(3.117748, -0.32660076), vec2(3.3390632, -0.40395358), vec2(3.4765792, -0.54576707),
    vec2(3.173614, -6.106575), vec2(3.506661, -5.9776535), vec2(3.781693, -5.8057585),
    vec2(3.3046842, -3.382037), vec2(3.5625267, -3.270305), vec2(3.8010314, -3.1284916),
    vec2(3.4679844, -5.315857), vec2(3.2831972, -5.565105), vec2(3.0167596, -5.7133646),
    vec2(3.4765792, -0.54576707), vec2(3.6140952, -0.6875806), vec2(3.6807046, -0.8788139),
    vec2(3.54104, -2.0004296), vec2(3.3347657, -2.316287), vec2(2.9265146, -2.4795873),
    vec2(3.6807046, -0.8788139), vec2(3.747314, -1.0700473), vec2(3.747314, -1.3192952),
    vec2(3.747314, -1.3192952), vec2(3.747314, -1.6845723), vec2(3.54104, -2.0004296),
    vec2(3.775247, -4.7400084), vec2(3.657069, -5.0580144), vec2(3.4679844, -5.315857),
    vec2(3.8010314, -3.1284916), vec2(4.039536, -2.9866781), vec2(4.2157283, -2.7975934),
    vec2(3.9879673, -4.073915), vec2(3.893425, -4.4220023), vec2(3.775247, -4.7400084),
    vec2(3.996562, -0.3996562), vec2(3.3992264, 0.12462398), vec2(2.5139663, 0.12462398),
    vec2(4.2157283, -2.7975934), vec2(4.4091105, -2.5827246), vec2(4.501504, -2.3270304),
    vec2(4.501504, -2.3270304), vec2(4.593898, -2.0713365), vec2(4.593898, -1.7318435),
    vec2(4.593898, -1.7318435), vec2(4.593898, -0.92393637), vec2(3.996562, -0.3996562)
);

#define LINE_COUNT 8
const vec2 LINES[LINE_COUNT * 2] = vec2[LINE_COUNT * 2](
    vec2(0.40395358, -2.0842285), vec2(0.7520412, -2.0842285),
    vec2(0.46411687, 0.0042973785), vec2(0.40395358, -2.0842285),
    vec2(0.80790716, 0.0042973785), vec2(0.46411687, 0.0042973785),
    vec2(0.99269444, -0.30941126), vec2(0.80790716, 0.0042973785),
    vec2(3.781693, -5.8057585), vec2(3.9578855, -6.09798),
    vec2(3.9578855, -6.09798), vec2(4.301676, -6.09798),
    vec2(4.301676, -6.09798), vec2(4.336055, -4.073915),
    vec2(4.336055, -4.073915), vec2(3.9879673, -4.073915)
);

float dot2(in vec2 v) { return dot(v, v); }
float cro(in vec2 a, in vec2 b) { return a.x * b.y - a.y * b.x; }

// signed distance to a quadratic bezier
float sdBezier(in vec2 pos, in vec2 A, in vec2 B, in vec2 C) {
    vec2 a = B - A;
    vec2 b = A - 2.0 * B + C;
    vec2 c = a * 2.0;
    vec2 d = A - pos;

    float kk = 1.0 / dot(b, b);
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);

    float res = 0.0;
    float sgn = 0.0;

    float p  = ky - kx * kx;
    float q  = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float p3 = p * p * p;
    float q2 = q * q;
    float h  = q2 + 4.0 * p3;

    if(h >= 0.0) { // 1 root
        h = sqrt(h);
        vec2 x = (vec2(h, -h) - q) / 2.0;

        // When p≈0 and p<0, h - q has catastrophic cancelation. So, we do
        // h=√(q² + 4p³)=q·√(1 + 4p³/q²)=q·√(1 + w) instead. Now we approximate
        // √ by a linear Taylor expansion into h≈q(1 + ½w) so that the q's
        // cancel each other in h - q. Expanding and simplifying further we
        // get x=vec2(p³/q, -p³/q - q). And using a second degree Taylor
        // expansion instead: x=vec2(k, -k - q) with k=(1 - p³/q²)·p³/q
        if(abs(abs(h/q) - 1.0) < 0.0001) {
            float k = (1.0 - p3 / q2) * p3 / q;  // quadratic approx
            x = vec2(k, -k - q);
        }

        vec2 uv = sign(x) * pow(abs(x), vec2(1.0/3.0));
        float t = clamp(uv.x + uv.y - kx, 0.0, 1.0);
        vec2  q = d + (c + b * t) * t;
        res = dot2(q);
        sgn = cro(c + 2.0 * b * t, q);
    } else { // 3 roots
        float z = sqrt(-p);
        float v = acos(q / (p * z * 2.0)) / 3.0;
        float m = cos(v);
        float n = sin(v) * 1.732050808;
        vec3  t = clamp(vec3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
        vec2  qx=d + (c + b * t.x) * t.x;
        float dx = dot2(qx), sx = cro(c + 2.0 * b * t.x, qx);
        vec2  qy=d + (c + b * t.y) * t.y;
        float dy = dot2(qy);
        float sy = cro(c + 2.0 * b * t.y, qy);
        if (dx<dy) {
            res=dx;
            sgn=sx;
        } else {
            res=dy;
            sgn=sy;
        }
    }

    return sqrt(res) * sign(sgn);
}

// Source: https://www.shadertoy.com/view/wdBXRW
float winding_sign(in vec2 p, in vec2 a, in vec2 b) {
    vec2 e = b - a;
    vec2 w = p - a;

    // winding number from http://geomalgorithms.com/a03-_inclusion.html
    bvec3 cond = bvec3(p.y >= a.y, 
                       p.y < b.y, 
                       e.x*w.y > e.y*w.x);
    if( all(cond) || all(not(cond))) {
        return -1.0;
    } else {
        return 1.0;
    }
}

float winding_angle(in vec2 p, in vec2 a, in vec2 b) {
    float pa = dot2(a - p);
    float pb = dot2(b - p);
    float ab = dot2(a - b);
    float ang = acos((pa + pb - ab) / (2.0 * sqrt(pa * pb)));
    return sign(cro(a - p, b - p)) * ang;
}

float udSegment(in vec2 p, in vec2 a, in vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba)/dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 p = (2.0 * fragCoord - iResolution.xy) / iResolution.y;
    p = (p + vec2(0.5, 0.75)) * vec2(4.0, -4.0);
    vec2 m = (2.0 * iMouse.xy - iResolution.xy) / iResolution.y;
    m = (m + vec2(0.5, 0.75)) * vec2(4.0, -4.0);

    float d = 1e10;
    float winding = 1.0;
    for (int i=0; i < QUAD_COUNT; i++) {
        vec2 v0 = QUADS[i * 3];
        vec2 v1 = QUADS[i * 3 + 1];
        vec2 v2 = QUADS[i * 3 + 2];

        float sd = sdBezier(p, v0, v1, v2);
        d = min(d, abs(sd));

        if (sd > 0.0 == cro(v1 - v2, v1 - v0) < 0.0) {
            winding *= winding_sign(p, v0, v1);
            winding *= winding_sign(p, v1, v2);
        } else {
            winding *= winding_sign(p, v0, v2);
        }
    }
    for (int i=0; i < LINE_COUNT; i++) {
        vec2 v0 = LINES[i * 2];
        vec2 v1 = LINES[i * 2 + 1];
        d = min(d, udSegment(p, v0, v1));
        winding *= winding_sign(p, v0, v1);
    }

    d *= winding;

    // Apply a color based on signed distance
    vec3 col = vec3(1.0) - vec3(0.1, 0.4, 0.7) * sign(d);
    col *= 1.0 - exp(-4.0 * abs(d));
    col *= 0.8 + 0.2 * cos(60.0 * d);
    col = mix(col, vec3(1.0), 1.0 - smoothstep(0.0, 0.015, abs(d)));

    // Draw the mouse stuff
    if(iMouse.z > 0.001) {
        float d = 1e10;
        for (int i=0; i < QUAD_COUNT; i++) {
            vec2 v0 = QUADS[i * 3];
            vec2 v1 = QUADS[i * 3 + 1];
            vec2 v2 = QUADS[i * 3 + 2];
            d = min(d, abs(sdBezier(m, v0, v1, v2)));
        }
        for (int i=0; i < LINE_COUNT; i++) {
            vec2 v0 = LINES[i * 2];
            vec2 v1 = LINES[i * 2 + 1];
            d = min(d, udSegment(m, v0, v1));
        }
        col = mix(col, vec3(1.0, 1.0, 0.0), 1.0 - smoothstep(0.0, 0.005, abs(length(p - m) - abs(d)) - 0.01));
        col = mix(col, vec3(1.0, 1.0, 0.0), 1.0 - smoothstep(0.0, 0.005, length(p - m) - 0.05));
    }

    { // Draw the skeleton of the Bezier curves
        float d = 1e10;
        for (int i=0; i < QUAD_COUNT; i++) {
            vec2 v0 = QUADS[i * 3];
            vec2 v1 = QUADS[i * 3 + 1];
            vec2 v2 = QUADS[i * 3 + 2];
            d = min(d, min(udSegment(p, v0, v1), udSegment(p, v1, v2)));
            d = min(d, length(p - v0) - 0.05);
            d = min(d, length(p - v1) - 0.05);
            d = min(d, length(p - v2) - 0.05);
        }
        for (int i=0; i < LINE_COUNT; i++) {
            vec2 v0 = LINES[i * 2];
            vec2 v1 = LINES[i * 2 + 1];
            d = min(d, udSegment(p, v0, v1));
            d = min(d, length(p - v0) - 0.05);
            d = min(d, length(p - v1) - 0.05);
        }
        col = mix(col, vec3(1, 0, 0), 1.0 - smoothstep(0.0, 0.014, d));
    }

    fragColor = vec4(col, 1.0);
}