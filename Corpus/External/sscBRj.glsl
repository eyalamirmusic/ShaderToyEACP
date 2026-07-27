// sscBRj - mrange
// https://www.shadertoy.com/view/sscBRj
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: 1st attempt multiscale truchet
// Everyone loves truchet tiles. Shane did an amazing one: https://www.shadertoy.com/view/4t3BW4
// I was trying to understand what was going and my brain hurt.
// Anyway after some tinkering I think I got the gist of it. The idea is brilliant!
// Compared to Shane's this looks awful but I have a low barrier to what I chose to share :)

#define TIME        iTime
#define RESOLUTION  iResolution
#define PI          3.141592654
#define TAU         (2.0*PI)

// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,58.233))) * 13758.5453);
}

float circle(vec2 p, float r) {
  return length(p) - r;
}

// Classic truchet pattern
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

// Multiscale truchet
float df1(vec2 p) {
  vec2 op = p;
  p -= 0.5;
  vec2 n = round(p);
  p -= n;
  float h0 = hash(n+100.0);
  float h1 = fract(8667.0*h0);

  // Recurse to df0 for 50% of the tiles
  if (h1 < 0.5) {
    // Invert the distance to make inside into outside
    return -(df0(2.0*op))*0.5;
  }

  if (h0 > 0.5) {
    p = vec2(p.y, -p.x);;
  }

  // Classic truchet with an added circle
  // so that the outside areas matches up with the nested truchet 
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

float df(vec2 p) {
  return df1(p);
}

vec3 effect(vec2 p) {
  float aa = 2.0/RESOLUTION.y;
  const float amp = 10.0;
  p += amp*sin(vec2(1.0, sqrt(0.5))*TIME*TAU/(10.0*amp));
  const float sz = 0.25;
  float d = df(p/sz)*sz;
  vec3 col = vec3(0.01);
  col = mix(col, vec3(0.5), smoothstep(aa, -aa, d));
  return col;
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
  vec2 q = fragCoord/iResolution.xy;
  vec2 p = -1. + 2. * q;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  vec3 col = effect(p);  
  col = sqrt(col);
  fragColor = vec4(col, 1.0);
}
