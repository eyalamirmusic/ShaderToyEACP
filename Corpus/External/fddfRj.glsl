// fddfRj - mrange
// https://www.shadertoy.com/view/fddfRj
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: 2nd attempt multiscale truchet
// Everyone loves truchet tiles. Shane did an amazing one: https://www.shadertoy.com/view/4t3BW4
// Been tinkering a bit more with multiscale truchet inspired by Shane's.
// Made a height field and applied lighting to it. Kind of neat

#define TIME        iTime
#define RESOLUTION  iResolution
#define PI          3.141592654
#define TAU         (2.0*PI)
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))
#define DOT2(x)     dot(x,x)

// License: Unknown, author: nmz (twitter: @stormoid), found: https://www.shadertoy.com/view/NdfyRM
vec3 sRGB(vec3 t) {
  return mix(1.055*pow(t, vec3(1./2.4)) - 0.055, 12.92*t, step(t, vec3(0.0031308)));
}

// License: Unknown, author: Matt Taylor (https://github.com/64), found: https://64.github.io/tonemapping/
vec3 aces_approx(vec3 v) {
  v = max(v, 0.0);
  v *= 0.6f;
  float a = 2.51f;
  float b = 0.03f;
  float c = 2.43f;
  float d = 0.59f;
  float e = 0.14f;
  return clamp((v*(a*v+b))/(v*(c*v+d)+e), 0.0f, 1.0f);
}

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,58.233))) * 13758.5453);
}

float tanh_approx(float x) {
//  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

float circle(vec2 p, float r) {
  return length(p) - r;
}

float df0(vec2 p) {
  p -= 0.5;
  vec2 n = round(p);
  p -= n;
  float h0 = hash(n+100.0);

  if (h0 > 0.5) {
    p = vec2(p.y, -p.x);;
  }

  float d0 = circle(p-0.5, 0.5);
  float d1 = circle(p+0.5, 0.5);
  float d = d0;
  d = min(d, d1);
  d = abs(d) - 0.125;
  return d;
}

float df1(vec2 p) {
  vec2 op = p;
  p -= 0.5;
  vec2 n = round(p);
  p -= n;
  float h0 = hash(n+200.0);
  float h1 = fract(8667.0*h0);

  if (h1 < 0.5) {
    return -(df0(2.0*op))*0.5;
  }

  if (h0 > 0.5) {
    p = vec2(p.y, -p.x);;
  }

  float d0 = circle(p-0.5, 0.5);
  float d1 = circle(p+0.5, 0.5);
  p = abs(p);
  float d2 = circle(p-0.5, 0.125*1.5);
  float d = d0;
  d = min(d, d1);
  d = abs(d)-0.125*1.5;
  d = min(d, d2);
  return d;
}

float df2(vec2 p) {
  vec2 op = p;
  p -= 0.5;
  vec2 n = round(p);
  p -= n;
  float h0 = hash(n+300.0);
  float h1 = fract(8667.0*h0);

  if (h1 < 0.5) {
    return -(df1(2.0*op))*0.5;
  }

  if (h0 > 0.666) {
    p = vec2(p.y, -p.x);;
  }

  float d0 = circle(p-0.5, 0.5);
  float d1 = circle(p+0.5, 0.5);
  p = abs(p);
  float d2 = circle(p-0.5, 0.125);
  float d = d0;
  d = min(d, d1);
  d = abs(d)-0.125;
  d = min(d, d2);
  d = abs(d)-0.0125*2.5;
  return d;
}

float df(vec2 p) {
  return df2(p);
}

float hf(vec2 p) {
  float aa = 0.0275;
  float d = df(p);
  return -0.033*smoothstep(aa, -aa, -d);
}

float g_h3 = 0.0;

float height(vec2 p) {
  p *= 0.3333;
  float h = hf(p);
  p *= 3.0;
  h += 0.5*hf(p);
  p *= 3.0;
  float h3 = hf(p);
  h += 0.25*h3;
  g_h3 = h3;
  return h;
}

vec3 normal(vec2 p) {
  vec2 e = vec2(4.0/RESOLUTION.y, 0);
  
  vec3 n;
  n.x = height(p + e.xy) - height(p - e.xy);
  n.y = 2.0*e.x;
  n.z = height(p + e.yx) - height(p - e.yx);
  
  return normalize(n);
}

vec3 effect(vec2 p) {
  const float s = 1.0;
  
  const float amp = 10.0;
  vec2 off = amp*sin(vec2(1.0, sqrt(0.5))*TIME*TAU/(30.0*amp));
  const vec3 lp1 = vec3(1.0, 1.25, 1.0)*vec3(s, 1.0, s);
  const vec3 lp2 = vec3(-1.0, 1.25, 1.0)*vec3(s, 1.0, s);

  vec2 p0 = p;
  p0 += off;
  float h = height(p0);
  float h3= g_h3;
  vec3  n = normal(p0);

  vec3 ro = vec3(0.0, -10.0, 0.0);
  vec3 pp = vec3(p.x, 0.0, p.y);

  vec3 po = vec3(p.x, h, p.y);
  vec3 rd = normalize(ro - po);

  vec3 ld1 = normalize(lp1 - po);
  vec3 ld2 = normalize(lp2 - po);
  
  float diff1 = max(dot(n, ld1), 0.0);
  float diff2 = max(dot(n, ld2), 0.0);

  vec3  rn    = n;
  vec3  ref   = reflect(rd, rn);
  float ref1  = max(dot(ref, ld1), 0.0);
  float ref2  = max(dot(ref, ld2), 0.0);
  float fre   = 1.0+dot(n,rd);
  float mh3  = smoothstep(-0.033, -0.015, h3);
  vec3 mat   = HSV2RGB(vec3(0.66, 0.55, mix(0.75, 0.05, mh3)));
  const vec3 lcol1 = HSV2RGB(vec3(0.60, 0.66, 6.0));
  const vec3 lcol2 = HSV2RGB(vec3(0.05, 0.66, 2.0));
  vec3 col = vec3(0.);
  float dm = tanh_approx(-h*10.0+0.05);
  float dist1 = DOT2(lp1 - po);
  float dist2 = DOT2(lp2 - po);
  col += (lcol1*mat)*(diff1*diff1/dist1);
  col += (lcol2*mat)*(diff2*diff2/dist2);
  col *= dm;
  float rm = mix(0.125, 0.5, fre);
  float spread = mix(80.0, 40.0, mh3);
  col += (rm/dist1)*(pow(ref1, spread)*lcol1);
  col += (rm/dist2)*(pow(ref2, spread)*lcol2);
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord/iResolution.xy;
  vec2 p = -1. + 2. * q;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  vec3 col = effect(p);
  col *= smoothstep(0.0, 4.0, TIME);
  col = aces_approx(col);
  col = sRGB(col);
  fragColor = vec4(col, 1.0);
}
