// wtsBzS - mrange
// https://www.shadertoy.com/view/wtsBzS
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: Double Ended Truchet Experiment
// Been looking at some double ended truchets by BigWings and Shane. 
// After some experiments I got something I felt was interesting enough to share.

#define TIME            iTime
#define RESOLUTION      iResolution
#define PI              3.141592654
#define TAU             (2.0*PI)

const vec2 coords[8] = vec2[8](
  0.5*vec2(-1.0, -0.5),
  0.5*vec2(-1.0, +0.5),
  0.5*vec2(-0.5, +1.0),
  0.5*vec2(+0.5, +1.0),
  0.5*vec2(+1.0, +0.5),
  0.5*vec2(+1.0, -0.5),
  0.5*vec2(+0.5, -1.0),
  0.5*vec2(-0.5, -1.0)
  );

const vec2 dcoords[8] = vec2[8](
  vec2(+1.0, +0.0),
  vec2(+1.0, +0.0),
  vec2(+0.0, -1.0),
  vec2(+0.0, -1.0),
  vec2(-1.0, +0.0),
  vec2(-1.0, +0.0),
  vec2(+0.0, +1.0),
  vec2(+0.0, +1.0)
  );

const int noCorners = 105;
// Using symmetries and reflections should be possible to reduce this 
//  array alot, but that is hard ;)
const int corners[105*8] = int[105*8](
  0, 1, 2, 3, 4, 5, 6, 7, 
  0, 1, 2, 3, 4, 6, 5, 7, 
  0, 1, 2, 3, 4, 7, 5, 6, 
  0, 1, 2, 4, 3, 5, 6, 7, 
  0, 1, 2, 4, 3, 6, 5, 7, 
  0, 1, 2, 4, 3, 7, 5, 6, 
  0, 1, 2, 5, 3, 4, 6, 7, 
  0, 1, 2, 5, 3, 6, 4, 7, 
  0, 1, 2, 5, 3, 7, 4, 6, 
  0, 1, 2, 6, 3, 4, 5, 7, 
  0, 1, 2, 6, 3, 5, 4, 7, 
  0, 1, 2, 6, 3, 7, 4, 5, 
  0, 1, 2, 7, 3, 4, 5, 6, 
  0, 1, 2, 7, 3, 5, 4, 6, 
  0, 1, 2, 7, 3, 6, 4, 5, 
  0, 2, 1, 3, 4, 5, 6, 7, 
  0, 2, 1, 3, 4, 6, 5, 7, 
  0, 2, 1, 3, 4, 7, 5, 6, 
  0, 2, 1, 4, 3, 5, 6, 7, 
  0, 2, 1, 4, 3, 6, 5, 7, 
  0, 2, 1, 4, 3, 7, 5, 6, 
  0, 2, 1, 5, 3, 4, 6, 7, 
  0, 2, 1, 5, 3, 6, 4, 7, 
  0, 2, 1, 5, 3, 7, 4, 6, 
  0, 2, 1, 6, 3, 4, 5, 7, 
  0, 2, 1, 6, 3, 5, 4, 7, 
  0, 2, 1, 6, 3, 7, 4, 5, 
  0, 2, 1, 7, 3, 4, 5, 6, 
  0, 2, 1, 7, 3, 5, 4, 6, 
  0, 2, 1, 7, 3, 6, 4, 5, 
  0, 3, 1, 2, 4, 5, 6, 7, 
  0, 3, 1, 2, 4, 6, 5, 7, 
  0, 3, 1, 2, 4, 7, 5, 6, 
  0, 3, 1, 4, 2, 5, 6, 7, 
  0, 3, 1, 4, 2, 6, 5, 7, 
  0, 3, 1, 4, 2, 7, 5, 6, 
  0, 3, 1, 5, 2, 4, 6, 7, 
  0, 3, 1, 5, 2, 6, 4, 7, 
  0, 3, 1, 5, 2, 7, 4, 6, 
  0, 3, 1, 6, 2, 4, 5, 7, 
  0, 3, 1, 6, 2, 5, 4, 7, 
  0, 3, 1, 6, 2, 7, 4, 5, 
  0, 3, 1, 7, 2, 4, 5, 6, 
  0, 3, 1, 7, 2, 5, 4, 6, 
  0, 3, 1, 7, 2, 6, 4, 5, 
  0, 4, 1, 2, 3, 5, 6, 7, 
  0, 4, 1, 2, 3, 6, 5, 7, 
  0, 4, 1, 2, 3, 7, 5, 6, 
  0, 4, 1, 3, 2, 5, 6, 7, 
  0, 4, 1, 3, 2, 6, 5, 7, 
  0, 4, 1, 3, 2, 7, 5, 6, 
  0, 4, 1, 5, 2, 3, 6, 7, 
  0, 4, 1, 5, 2, 6, 3, 7, 
  0, 4, 1, 5, 2, 7, 3, 6, 
  0, 4, 1, 6, 2, 3, 5, 7, 
  0, 4, 1, 6, 2, 5, 3, 7, 
  0, 4, 1, 6, 2, 7, 3, 5, 
  0, 4, 1, 7, 2, 3, 5, 6, 
  0, 4, 1, 7, 2, 5, 3, 6, 
  0, 4, 1, 7, 2, 6, 3, 5, 
  0, 5, 1, 2, 3, 4, 6, 7, 
  0, 5, 1, 2, 3, 6, 4, 7, 
  0, 5, 1, 2, 3, 7, 4, 6, 
  0, 5, 1, 3, 2, 4, 6, 7, 
  0, 5, 1, 3, 2, 6, 4, 7, 
  0, 5, 1, 3, 2, 7, 4, 6, 
  0, 5, 1, 4, 2, 3, 6, 7, 
  0, 5, 1, 4, 2, 6, 3, 7, 
  0, 5, 1, 4, 2, 7, 3, 6, 
  0, 5, 1, 6, 2, 3, 4, 7, 
  0, 5, 1, 6, 2, 4, 3, 7, 
  0, 5, 1, 6, 2, 7, 3, 4, 
  0, 5, 1, 7, 2, 3, 4, 6, 
  0, 5, 1, 7, 2, 4, 3, 6, 
  0, 5, 1, 7, 2, 6, 3, 4, 
  0, 6, 1, 2, 3, 4, 5, 7, 
  0, 6, 1, 2, 3, 5, 4, 7, 
  0, 6, 1, 2, 3, 7, 4, 5, 
  0, 6, 1, 3, 2, 4, 5, 7, 
  0, 6, 1, 3, 2, 5, 4, 7, 
  0, 6, 1, 3, 2, 7, 4, 5, 
  0, 6, 1, 4, 2, 3, 5, 7, 
  0, 6, 1, 4, 2, 5, 3, 7, 
  0, 6, 1, 4, 2, 7, 3, 5, 
  0, 6, 1, 5, 2, 3, 4, 7, 
  0, 6, 1, 5, 2, 4, 3, 7, 
  0, 6, 1, 5, 2, 7, 3, 4, 
  0, 6, 1, 7, 2, 3, 4, 5, 
  0, 6, 1, 7, 2, 4, 3, 5, 
  0, 6, 1, 7, 2, 5, 3, 4, 
  0, 7, 1, 2, 3, 4, 5, 6, 
  0, 7, 1, 2, 3, 5, 4, 6, 
  0, 7, 1, 2, 3, 6, 4, 5, 
  0, 7, 1, 3, 2, 4, 5, 6, 
  0, 7, 1, 3, 2, 5, 4, 6, 
  0, 7, 1, 3, 2, 6, 4, 5, 
  0, 7, 1, 4, 2, 3, 5, 6, 
  0, 7, 1, 4, 2, 5, 3, 6, 
  0, 7, 1, 4, 2, 6, 3, 5, 
  0, 7, 1, 5, 2, 3, 4, 6, 
  0, 7, 1, 5, 2, 4, 3, 6, 
  0, 7, 1, 5, 2, 6, 3, 4, 
  0, 7, 1, 6, 2, 3, 4, 5, 
  0, 7, 1, 6, 2, 4, 3, 5, 
  0, 7, 1, 6, 2, 5, 3, 4
  );

vec2 mod2_1(inout vec2 p) {
  vec2 c = floor(p + 0.5);
  p = fract(p + 0.5) - 0.5;
  return c;
}

float hash(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,58.233))) * 13758.5453);
}

float psin(float a) {
  return 0.5 + 0.5*sin(a);
}

float dot2(vec2 v) { return dot(v,v); }
    
vec3 alphaBlend(vec3 back, vec4 front) {
  vec3 colb = back.xyz;
  vec3 colf = front.xyz;
  vec3 xyz = mix(colb, colf.xyz, front.w);
  return xyz;
}

// IQ Bezier: https://www.shadertoy.com/view/MlKcDD
float bezier(vec2 pos, vec2 A, vec2 B, vec2 C) {    
  const float sqrt3 = sqrt(3.0);
  vec2 a = B - A;
  vec2 b = A - 2.0*B + C;
  vec2 c = a * 2.0;
  vec2 d = A - pos;

  float kk = 1.0/dot(b,b);
  float kx = kk * dot(a,b);
  float ky = kk * (2.0*dot(a,a)+dot(d,b))/3.0;
  float kz = kk * dot(d,a);      

  float res = 0.0;

  float p = ky - kx*kx;
  float p3 = p*p*p;
  float q = kx*(2.0*kx*kx - 3.0*ky) + kz;
  float h = q*q + 4.0*p3;

  if(h>=0.0) {   // 1 root
      h = sqrt(h);
      vec2 x = (vec2(h,-h)-q)/2.0;
      vec2 uv = sign(x)*pow(abs(x), vec2(1.0/3.0));
      float t = clamp(uv.x+uv.y-kx, 0.0, 1.0);
      res = dot2(d+(c+b*t)*t);
  } else {   // 3 roots
      float z = sqrt(-p);
      float v = acos(q/(p*z*2.0))/3.0;
      float m = cos(v);
      float n = sin(v)*sqrt3;
      vec3  t = clamp(vec3(m+m,-n-m,n-m)*z-kx, 0.0, 1.0);
      res = min(dot2(d+(c+b*t.x)*t.x), dot2(d+(c+b*t.y)*t.y));
      // the third root cannot be the closest. See https://www.shadertoy.com/view/4dsfRS
      // res = min(res,dot2(d+(c+b*t.z)*t.z));
  }
  
  return sqrt(res);
}

float bezier2(vec2 p, float f, vec2 off, vec2 p0, vec2 dp0, vec2 p1, vec2 dp1) {
  float dist = length(p0 - p1);
  float hdist = 0.5*f*dist;
  vec2 mp0 = p0 + hdist*dp0;
  vec2 mp1 = p1 + hdist*dp1;
  vec2 jp = (mp0 + mp1)*0.5+off;
  float d0 = bezier(p, p0, mp0, jp);
  float d1 = bezier(p, p1, mp1, jp);
  
  float d = d0;
  d = min(d, d1);
  return d;
}

vec3 color(vec2 p, float s, float aa, vec3 col) {
  p /= s;
  vec2 cp = p;
  vec2 cn = mod2_1(cp);
  float rr = hash(cn);
  int sel = int(float(noCorners)*rr);
  int off = sel*8;
  
  const vec3 scol = vec3(0.25);
  const vec3 bcol = vec3(1.0);
  const float sw = 0.05;
  
  for (int i = 0; i < 4; ++i) {
    int c0 = corners[off + i*2 + 0];
    int c1 = corners[off + i*2 + 1];    
    int odd = min(c0, c1) & 1;
    
    float r = fract(rr*13.0*float(i+1));
    
    int l = abs(c0 - c1) + odd*8;
    float f = 0.71;
    vec2 off = vec2(0.0, 0.0);

    vec2 p0 = coords[c0];
    vec2 p1 = coords[c1];
    
    vec2 dp0 = dcoords[c0];
    vec2 dp1 = dcoords[c1];

    vec2 dp = mix(dp0, dp1, r);

    switch(l) {
    // Mid shape
    case 1:
    case 15:
      f = mix(0.75, 2.5, r);
      break;
    // L - shape
    case 2:
    case 6:
    case 10:
    case 14:
      f = r > 0.5 ? 0.35 : 1.25;
      break;
    // Big corner shape
    case 3:
    case 13:
      f = mix(0.5, 1.0, r);
      break;
    // Cross line
    case 4:
    case 12:
      f = r>0.5 ? 0.5 : 1.5;
      break;
    // Straight line
    case 5:
    case 11:
      f = 1.5;
      off = (r > 0.5 ? 1.0 : -1.0)*0.15*vec2(dp0.y, -dp0.x);
      break;
    // Small corner shape
    case 7:
    case 9:
      f = r>0.5 ? 0.75 : 2.75;
      break;
    default:
      f = 0.5;
      break;
    }
    
    float dd = (bezier2(cp, f, off, p0, dp0, p1, dp1)-0.025)*s;
    
    vec4 sc = vec4(scol, smoothstep(-sw, sw, -dd));
    vec4 bc = vec4(bcol, smoothstep(-aa, aa, -dd));

    col = alphaBlend(col, sc);
    col = alphaBlend(col, bc);
  }
  
  return col;
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1. + 2. * q;
  p.x *= RESOLUTION.x/RESOLUTION.y;
 
  p += vec2(0.5, sqrt(0.5))*TIME*0.1;
 
  float aa = 2.0/RESOLUTION.y;
  float s = 0.25;

  vec3 col = vec3(0.1);
  col = color(p, s, aa, col);
  
  fragColor = vec4(col, 1.0);
}

