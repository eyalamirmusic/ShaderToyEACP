// NstSDn - mrange
// https://www.shadertoy.com/view/NstSDn
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: Adaptive tile sizes
//  Been working too much lately to do shader stuff.
//  But today I experimented a bit with tiling so thought I share

#define TIME        iTime
#define RESOLUTION  iResolution
#define ROT(a)      mat2(cos(a), sin(a), -sin(a), cos(a))
#define PI          3.141592654
#define TAU         (2.0*PI)
#define DOT2(x)     dot(x, x)

const int max_iter = 6;

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
const vec4 hsv2rgb_K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www);
  return c.z * mix(hsv2rgb_K.xxx, clamp(p - hsv2rgb_K.xxx, 0.0, 1.0), c.y);
}

// License: WTFPL, author: sam hocevar, found: https://stackoverflow.com/a/17897228/418488
//  Macro version of above to enable compile-time constants
#define HSV2RGB(c)  (c.z * mix(hsv2rgb_K.xxx, clamp(abs(fract(c.xxx + hsv2rgb_K.xyz) * 6.0 - hsv2rgb_K.www) - hsv2rgb_K.xxx, 0.0, 1.0), c.y))

// License: MIT OR CC-BY-NC-4.0, author: mercury, found: https://mercury.sexy/hg_sdf/
vec2 mod2(inout vec2 p, vec2 size) {
  vec2 c = floor((p + size*0.5)/size);
  p = mod(p + size*0.5,size) - size*0.5;
  return c;
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float heart(vec2 p) {
    p.x = abs(p.x);

    if( p.y+p.x>1.0 )
        return sqrt(DOT2(p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;
    return sqrt(min(DOT2(p-vec2(0.00,1.00)),
                    DOT2(p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}

// License: MIT, author: Inigo Quilez, found: https://iquilezles.org/www/articles/distfunctions2d/distfunctions2d.htm
float box(vec2 p, vec2 b) {
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float shape(vec2 p) {
  const float z = 1.6;
  p /= z;
  p *= ROT(TIME*0.25);
  p.y += 0.58;
  float d = heart(p)*z;
  return d;
}

float df(vec2 p, out int ii, out bool inside) {
  float aa = 3.0/RESOLUTION.y;

  float sz = 0.9;
  float ds = shape(p);
  vec2 pp = p;

  float r = 0.0;

  ii = max_iter;
  for (int i=0; i<max_iter; ++i) {
    pp = p;
    vec2 nn = mod2(pp, vec2(sz));
  
    vec2 cp = nn*sz;
    float d = shape(cp);
    
    r = sz*0.5; 

    if (abs(d) > 0.5*sz*sqrt(2.0)) {
      ii = i;
      inside = d < 0.0;
      break;
    }

    sz /= 3.0;
  }
  
  return box(pp, vec2(r-aa));
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
  int i;
  bool inside;
  float d = df(p, i, inside)*z;
  float ds = shape(p)*z;
  float ii = float(i)/float(max_iter);

  if (!inside) d = abs(d)-aa;

  vec3 col = vec3(0.0);
  vec3 hsv = vec3((inside ? 0.1 : 0.6) +1.1*ii, 0.7, sqrt(max(1.0-ii, 0.0)));
  vec3 rgb = hsv2rgb(hsv);
  col = mix(col, rgb, smoothstep(aa, -aa, d));

  col = postProcess(col, q);

  fragColor = vec4(col, 1.0);
}

