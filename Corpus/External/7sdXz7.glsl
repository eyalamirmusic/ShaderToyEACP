// 7sdXz7 - mrange
// https://www.shadertoy.com/view/7sdXz7
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: Simple circle tiling
//  Been working too much lately to do shader stuff.
//  But today I experimented a bit with tiling so thought I share
#define TIME        iTime
#define RESOLUTION  iResolution
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))
#define PI          3.141592654
#define TAU         (2.0*PI)

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

float circle(vec2 p, float r) {
  return length(p) - r;
}

// License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size*0.5)/size);
  p = mod(p + size*0.5,size) - size*0.5;
  return c;
}

// License: Unknown, author: Hexler, found: Kodelife example Grid
float hash(vec2 uv) {
  return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float df(vec2 p, out float n, out float sc) {
  vec2 pp = p;
  
  float sz = 2.0;
  
  float r = 0.0;
  
  for (int i = 0; i < 5; ++i) {
    vec2 nn = mod2(pp, vec2(sz));
    sz /= 3.0;
    float rr = hash(nn+123.4);
    r += rr;
    if (rr < 0.5) break;
  }
  
  float d = circle(pp, 1.25*sz);
  
  n = fract(r);
  sc = sz;
  return d;
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/index.htm
vec3 postProcess(vec3 col, vec2 q) {
  //  Found this somewhere on the interwebs
  col = clamp(col, 0.0, 1.0);
  // Gamma correction
  col = pow(col, 1.0/vec3(2.2));
  col = col*0.6+0.4*col*col*(3.0-2.0*col);
  col = mix(col, vec3(dot(col, vec3(0.33))), -0.4);
  // Vignetting
  col*= 0.5+0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.7);
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  float aa = 2.0/RESOLUTION.y;

  const float r = 25.0;
  float a = 0.05*TAU*TIME/r;
  const float z = 1.0;
  p /= z;
  p += r*vec2(cos(a), sin(a));
  p *= ROT(-a+0.25);
  float n = 0.0;
  float sc = 0.0;
  float d = df(p, n, sc)*z;

  vec3 col = vec3(0.0);
  vec3 hsv = vec3(n-0.25*d/sc, 0.5+0.5*d/sc, 1.0);
  vec3 rgb = hsv2rgb(hsv);
  col = mix(col, rgb, smoothstep(aa, -aa, d));

  col = postProcess(col, q);

  fragColor = vec4(col, 1.0);
}

