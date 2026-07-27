// NtKBWh - mrange
// https://www.shadertoy.com/view/NtKBWh
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: Dark chocolate FBM
//  Working on a cake related shader and created kind of dark chocolate
//  background. Nothing unique but different colors than what I usually 
//  do so sharing.

#define TIME        iTime
#define RESOLUTION  iResolution

#define PI          3.141592654
#define TAU         (2.0*PI)
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))
#define TTIME       (TAU*TIME)
#define DOT2(p)     dot(p, p)

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

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

// License: Unknown, author: Unknown, found: don't remember
float tanh_approx(float x) {
//  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/smin/smin.htm
float pmin(float a, float b, float k) {
  float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
  return mix(b, a, h) - k*h*(1.0-h);
}

// License: CC0, author: Mårten Rånge, found: https://github.com/mrange/glsl-snippets
float pabs(float a, float k) {
  return -pmin(a, -a, k);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float heart(vec2 p) {
  p.y -= -0.6;
  p.x = pabs(p.x, 0.125);

  if( p.y+p.x>1.0 )
      return sqrt(DOT2(p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;
  return sqrt(min(DOT2(p-vec2(0.00,1.00)),
                  DOT2(p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}

vec2 mod2_1(inout vec2 p) {
  vec2 n = floor(p + 0.5);
  p = fract(p+0.5)-0.5;
  return n;
}

float hf(vec2 p) {  
  p *= 0.25;
  vec2 p0 = p;
  vec2 n0 = mod2_1(p0);
  vec2 p1 = p*vec2(1.0, -1.0)+vec2(0.5, 0.66);
  vec2 n1 = mod2_1(p1);
  const float ss = 0.60;
  float d0 = heart(p0/ss)*ss;
  float d1 = heart(p1/ss)*ss;
  float d = min(d0, d1);
  return tanh_approx(smoothstep(0.0, -0.1,d)*exp(8.0*-d));
}

float height(vec2 p) {
  const mat2 rot1 = ROT(1.0);
  float tm = 123.0+TTIME/240.0;
  p += 5.0*vec2(cos(tm), sin(tm*sqrt(0.5)));
  const float aa = -0.45;
  const mat2  pp = (1.0/aa)*rot1;
  float h = 0.0;
  float a = 1.0;
  float d = 0.0;
  for (int i = 0; i < 4; ++i) {
    h += a*hf(p);
    d += a;
    a *= aa;
    p *= pp;
  }  
  const float hf = -0.125;
  return hf*(h/d)+hf;
}

vec3 normal(vec2 p) {
  vec2 v;
  vec2 w;
  vec2 e = vec2(4.0/RESOLUTION.y, 0);
  
  vec3 n;
  n.x = height(p + e.xy) - height(p - e.xy);
  n.y = 2.0*e.x;
  n.z = height(p + e.yx) - height(p - e.yx);
  
  return normalize(n);
}

vec3 effect(vec2 p, vec2 q) {
  vec2 ppp = p;
  const float s     = 1.0;
  const vec3 lp1    = vec3(1.0, 1.25, 1.0)*vec3(s, 1.0, s);
  const vec3 lp2    = vec3(-1.0, 1.25, 1.0)*vec3(s, 1.0, s);
  const vec3 lcol1  = HSV2RGB(vec3(0.06, 0.9 , .5));
  const vec3 lcol2  = HSV2RGB(vec3(0.05, 0.25, 1.0));
  const vec3 mcol   = HSV2RGB(vec3(0.1 , 0.95, 0.2));
  const float spe1  = 20.0;
  const float spe2  = 40.0;
  float aa = 2.0/RESOLUTION.y;

  float h = height(p);
  vec3  n = normal(p);

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

  vec3 lpow1 = 0.15*lcol1/DOT2(ld1);
  vec3 lpow2 = 0.25*lcol2/DOT2(ld2);
  vec3 dm = mcol*tanh_approx(-h*5.0+0.125);
  vec3 col = vec3(0.0);
  col += dm*diff1*lpow1;
  col += dm*diff2*lpow2;
  vec3 rm = vec3(1.0)*mix(0.25, 1.0, tanh_approx(-h*1000.0));
  col += rm*pow(ref1, spe1)*lcol1;
  col += rm*pow(ref2, spe2)*lcol2;

  const float top = 10.0;

  col = aces_approx(col);
  col = sRGB(col);

  return col;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ) {
  vec2 q = fragCoord/RESOLUTION.xy;;
  vec2 p = -1. + 2. * q;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  vec3 col = effect(p, q);  
  
  fragColor = vec4(col, 1.0);
}

