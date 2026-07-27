// 7ttcDj - mrange
// https://www.shadertoy.com/view/7ttcDj
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: Cable nest v2
//  Revisited the old Cable nest shader and recoloured + tweaked distance field
//  Thought it turned out nice enough to share again


// ---

// Some parameters to play with.

#define BPM 120.0

// Controls camera "fisheye" 
//#define RDD0
//#define RDD1

// cable shapes
#define ROUNDEDX
//#define BOX

// Colour themes
//#define THEME0
#define THEME1
//#define THEME2

// If using aces approx 
#define HDR

// Another distance field, slightly different
//#define DF0

// Number of iterations used for distance field
#define MAX_ITER  3

// ---


#define TOLERANCE       0.0001
#define NORMTOL         0.00125
#define MAX_RAY_LENGTH  20.0
#define MAX_RAY_MARCHES 90
#define TIME            iTime
#define RESOLUTION      iResolution
#define ROT(a)          mat2(cos(a), sin(a), -sin(a), cos(a))
#define PI              3.141592654
#define TAU             (2.0*PI)

#define PATHA vec2(0.1147, 0.2093)
#define PATHB vec2(13.0, 3.0)


// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}
// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))


const float cam_amp = 1.0;

mat2 g_rot = ROT(0.0);
float g_quad = 0.0;
int g_hit = 0;

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

// License: MIT, author: Inigo Quilez, found: https://www.iquilezles.org/www/articles/spherefunctions/spherefunctions.htm
float sphered(vec3 ro, vec3 rd, vec4 sph, float dbuffer) {
    float ndbuffer = dbuffer/sph.w;
    vec3  rc = (ro - sph.xyz)/sph.w;
  
    float b = dot(rd,rc);
    float c = dot(rc,rc) - 1.0;
    float h = b*b - c;
    if( h<0.0 ) return 0.0;
    h = sqrt( h );
    float t1 = -b - h;
    float t2 = -b + h;

    if( t2<0.0 || t1>ndbuffer ) return 0.0;
    t1 = max( t1, 0.0 );
    t2 = min( t2, ndbuffer );

    float i1 = -(c*t1 + b*t1*t1 + t1*t1*t1/3.0);
    float i2 = -(c*t2 + b*t2*t2 + t2*t2*t2/3.0);
    return (i2-i1)*(3.0/4.0);
}

// License: Unknown, author: Unknown, found: don't remember
float hash(float co) {
  return fract(sin(co*12.9898) * 13758.5453);
}

vec3 cam_path(float z) {
  return vec3(cam_amp*sin(z*PATHA)*PATHB, z);
}

vec3 dcam_path(float z) {
  return vec3(cam_amp*PATHA*PATHB*cos(PATHA*z), 1.0);
}

vec3 ddcam_path(float z) {
  return cam_amp*vec3(cam_amp*-PATHA*PATHA*PATHB*sin(PATHA*z), 0.0);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float box(vec2 p, vec2 b, float r) {
  b -= r;
  vec2 d = abs(p)-b;
  return length(max(d,0.0)) + min(max(d.x,d.y),0.0)-r;
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float roundedX(vec2 p, float w, float r) {
  p = abs(p);
  return length(p-min(p.x+p.y,w)*0.5) - r;
}

float cables(vec3 p3) {
  const float cylr = 0.2;
  vec2 p = p3.xy;
  float t = p3.z;
  
  const float ss = 1.5;
  mat2 pp = ss*ROT(1.0+0.5*p3.z);

  p *= g_rot;
  float s = 1.0;
  
  float d = 1E6;
  float quad = 1.0;
  int hit = 0; 
  for (int i = 0; i < MAX_ITER; ++i) {
    p *= pp;
    p = abs(p);
#if defined(DF0)
    const float scaling = 3.0;
    p -= 0.5*s*scaling;
    s *= 1.0/ss;
    float sz = scaling*s;
#else
    p -= 1.35*s;
    s *= 1.0/ss;
    const float sz = 1.0;
#endif    
    
#if defined(ROUNDEDX)
    float dd = roundedX(p, sz*1.5*cylr, sz*0.25*cylr)*s;
#elif defined(BOX)
    float dd = box(p, vec2(sz*cylr), sz*cylr*0.1)*s;
#else
    float dd = (length(p)-sz*cylr)*s;
#endif
    vec2 s = sign(p);
    float q = s.x*s.y;
    
    if (dd < d) {
      d = dd;
      quad = q;
      hit = i;
    }
    
  }
  
  g_quad = quad;
  g_hit = hit;
  
  return d;
}

float df(vec3 p) {
  // Found this world warping technique somewhere but forgot which shader :(
  vec3 cam = cam_path(p.z);
  vec3 dcam = normalize(dcam_path(p.z));
  p.xy -= cam.xy;
  p -= dcam*dot(vec3(p.xy, 0), dcam)*0.5*vec3(1,1,-1);
  float d = cables(p);
  
  return d; 
} 

float rayMarch(in vec3 ro, in vec3 rd, out int iter) {
  float t = 0.1;
  int i = 0;
  for (i = 0; i < MAX_RAY_MARCHES; i++) {
    float d = df(ro + rd*t);
    if (d < TOLERANCE || t > MAX_RAY_LENGTH) break;
    t += d;
  }
  iter = i;
  return t;
}

vec3 normal(in vec3 pos) {
  vec3  eps = vec3(NORMTOL,0.0,0.0);
  vec3 nor;
  nor.x = df(pos+eps.xyy) - df(pos-eps.xyy);
  nor.y = df(pos+eps.yxy) - df(pos-eps.yxy);
  nor.z = df(pos+eps.yyx) - df(pos-eps.yyx);
  return normalize(nor);
}

float softShadow(in vec3 pos, in vec3 ld, in float ll, float mint, float k) {
  const float minShadow = 0.25;
  float res = 1.0;
  float t = mint;
  for (int i=0; i<25; ++i) {
    float distance = df(pos + ld*t);
    res = min(res, k*distance/t);
    if (ll <= t) break;
    if(res <= minShadow) break;
    t += max(mint*0.2, distance);
  }
  return clamp(res,minShadow,1.0);
}

vec3 render(vec3 ro, vec3 rd) {
  vec3 lightPos0  = cam_path(TIME-0.5);
  vec3 lightPos1  = cam_path(TIME+6.5);

  vec3 skyCol = vec3(0.0);

  int iter = 0;
  float t = rayMarch(ro, rd, iter);
  float quad = g_quad;
  float hit  = float(g_hit);

  float tt = float(iter)/float(MAX_RAY_MARCHES);
  float bs = 1.0-tt*tt*tt*tt;
 
  vec3 pos = ro + t*rd;    
  
  float lsd1  = sphered(ro, rd, vec4(lightPos1, 2.5), t);
  float beat  = smoothstep(0.25, 1.0, sin(TAU*TIME*BPM/60.0));
  vec3 bcol   = mix(HSV2RGB(vec3(0.6, 0.6, 3.0)), HSV2RGB(vec3(0.55, 0.8, 7.0)), beat);
  vec3 gcol   = lsd1*bcol;

  if (t >= MAX_RAY_LENGTH) {
    return skyCol+gcol;
  }
  
  vec3 nor    = normal(pos);

  vec3 lv0    = lightPos0 - pos;
  float ll20  = dot(lv0, lv0);
  float ll0   = sqrt(ll20);
  vec3 ld0    = lv0 / ll0;
  float dm0   = 8.0/ll20;
  float sha0  = softShadow(pos, ld0, ll0, 0.125, 32.0);
  float dif0  = max(dot(nor,ld0),0.0)*dm0;

  vec3 lv1    = lightPos1 - pos;
  float ll21  = dot(lv1, lv1);
  float ll1   = sqrt(ll21);
  vec3 ld1    = lv1 / ll1;
  float spe1  = pow(max(dot(reflect(ld1, nor), rd), 0.), 100.)*tanh_approx(3.0/ll21);

  vec3 col = vec3(0.0);

  const vec3 black = vec3(0.0);
#if defined(THEME0)
  const vec3 dcol0 = HSV2RGB(vec3(0.6, 0.5, 1.0));
  const vec3 dcol1 = dcol0;
#elif defined(THEME1)
  const vec3 dcol0 = black;
  const vec3 dcol1 = HSV2RGB(vec3(0.08, 1.0, 1.0));
#elif defined(THEME2)
  vec3 dcol0 = hsv2rgb(vec3(0.6-0.05*hit, 0.75, 1.0));
  const vec3 dcol1 = HSV2RGB(vec3(0.8, 1.0, 0.));
#else
  const vec3 dcol0 = black;
  const vec3 dcol1 = dcol0;
#endif
  col += dif0*sha0*mix(dcol0, dcol1, 0.5+0.5*quad);
  col += spe1*bcol*bs;
  col += gcol;

  return col;
}

vec3 effect(vec2 p) {
  float tm = TIME;
  g_rot = ROT(-0.2*tm);
  vec3 cam  = cam_path(tm);
  vec3 dcam = dcam_path(tm);
  vec3 ddcam= ddcam_path(tm);

  vec3 ro = cam;
  vec3 ww = normalize(dcam);
  vec3 uu = normalize(cross(vec3(0.0,1.0,0.0)+ddcam*2.0, ww ));
  vec3 vv = normalize(cross(ww,uu));
#if defined(RDD0)
  float rdd = (2.0-0.5*tanh_approx(dot(p, p)));
#elif defined(RDD1)
  float rdd = (2.0+0.75*tanh_approx(dot(p, p)));
#else
  const float rdd = 2.5;
#endif  
  vec3 rd = normalize(p.x*uu + p.y*vv + rdd*ww);

  vec3 col = render(ro, rd);
  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1.0 + 2.0*q;
  p.x *= RESOLUTION.x/RESOLUTION.y;

  vec3 col = effect(p);
#if defined(HDR)
  col = aces_approx(col);
  col = sRGB(col);
#else  
  col = sqrt(col);
#endif  
  
  fragColor = vec4(col, 1.0);
}
