// ssdBWS - mrange
// https://www.shadertoy.com/view/ssdBWS
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: Rainbow boxes
//  Wednesday hack to reproduce a commonly seen effect

#define TIME        iTime
#define RESOLUTION  iResolution

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))


// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float hexagon(vec2 p, float r) {
//  const vec3 k = vec3(-0.866025404,0.5,0.577350269);
  const vec3 k = 0.5*vec3(-sqrt(3.0),1.0,sqrt(4.0/3.0));
  p = abs(p);
  p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
  p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
  return length(p)*sign(p.y);
}

// License: Unknown, author: Martijn Steinrucken, found: https://www.youtube.com/watch?v=VmrIDyYiJBA
vec2 hextile(inout vec2 p) {
  // See Art of Code: Hexagonal Tiling Explained!
  // https://www.youtube.com/watch?v=VmrIDyYiJBA
  const vec2 sz       = vec2(1.0, sqrt(3.0));
  const vec2 hsz      = 0.5*sz;

  vec2 p1 = mod(p, sz)-hsz;
  vec2 p2 = mod(p - hsz, sz)-hsz;
  vec2 p3 = dot(p1, p1) < dot(p2, p2) ? p1 : p2;
  vec2 n = ((p3 - p + hsz)/sz);
  p = p3;

  n -= vec2(0.5);
  // Rounding to make hextile 0,0 well behaved
  return round(n*2.0)*0.5;
}

float cellf(vec2 p, vec2 n) {
  const float lw = 0.01;
  return -hexagon(p.yx, 0.5-lw);
}

vec2 df(vec2 p, out vec2 hn0, out vec2 hn1) {
  const float sz = 0.25;
  p /= sz;
  vec2 hp0 = p;
  vec2 hp1 = p+vec2(1.0, sqrt(1.0/3.0));

  hn0 = hextile(hp0);
  hn1 = hextile(hp1);

  float d0 = cellf(hp0, hn0);
  float d1 = cellf(hp1, hn1);
  float d2 = length(hp0);

  float d = d0;
  d = min(d0, d1);

  return vec2(d, d2)*sz;
}

// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,58.233))) * 13758.5453);
}

vec3 effect(vec2 p) {
  float aa = 2.0/RESOLUTION.y;
  vec2 hn0;
  vec2 hn1;
  p .x+= 0.05*TIME;
  vec2 d2 = df(p, hn0, hn1);

  
  vec3 col = vec3(0.01);

  float h0 = hash(hn1);
  float h = fract(-0.025*hn1.x+0.1*hn1.y-0.2*TIME);
  float l = mix(0.25, 0.75, h0);

  if (hn0.x <= hn1.x+0.5) {
    l *= 0.5;
  }

  if (hn0.y <= hn1.y) {
    l *= 0.75;
  }
  
  col += hsv2rgb(vec3(h, 0.5, l));
  
  col = mix(col, vec3(0.), smoothstep(aa, -aa, d2.x));
  col *= mix(0.75, 1.0, smoothstep(0.01, 0.2, d2.y));
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord/iResolution.xy;
  vec2 p = -1. + 2. * q;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  
  vec3 col = effect(p);
  col *= smoothstep(0.0, 4.0, TIME-0.5*length(p));
  col = clamp(col, 0.0, 1.0);
  col = sqrt(col);
  
  fragColor = vec4(col, 1.0);
}
