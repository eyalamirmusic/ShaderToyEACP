// mrange - licence: cc0-1.0
// https://www.shadertoy.com/view/sdVyWt

// License CC0: Mandelbrot variation
//  Tinkered with julia mapping. Not amazing but different enough to share.
#define RESOLUTION  iResolution
#define TIME        iTime

// License: Unknown, author: Unknown, found: don't remember
float hash(vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,58.233))) * 13758.5453);
}

float cell_df(vec2 np, vec2 mp, vec2 off) {
  const vec2 n0 = normalize(vec2(1.0, 1.0));
  const vec2 n1 = normalize(vec2(-1.0, 1.0));

  np += off;
  mp -= off;
  
  float hh = hash(np);
  vec2 n = hh > 0.5 ? n0 : n1;
  vec2 t = vec2(n.y, -n.x);


  vec2  p0 = mp;  
  p0 = abs(p0);
  p0 -= 0.5;
  float d0 = length(p0)-0.0;

  vec2  p1 = mp;
  float d1 = dot(n, p1);
  float px = dot(t, p1);
  d1 = abs(px) > sqrt(0.5) ? d0 : abs(d1); 

  float d = d0;
  d = min(d, d1);
  
  return d;
}

float truchet_df(vec2 p) {
  vec2 np = floor(p+0.5);
  vec2 mp = fract(p+0.5) - 0.5;
  float d = 1E6;
  const float off = 1.0;
  for (float x=-off;x<=off;++x) {
    for (float y=-off;y<=off;++y) {
      vec2 o = vec2(x,y);
      d = min(d,cell_df(np, mp, o));
    }
  }
  return d;
}

void julia_map(inout vec2 p, vec2 c) {
  for (int i = 0; i < 89; ++i) {
    vec2 p2 = p*p;
    p = vec2(p2.x-p2.y, 2.0*p.x*p.y);
    p += c;
  }
}

vec2 transform(vec2 p) {
  p *= 0.0125;
  p.x -= 0.5;
  p += vec2(0.59, 0.62);
  julia_map(p, p);
  p *= 30.0;
  p += 0.2*TIME;
  return p;
}

vec3 effect(vec3 col, vec2 p_, vec2 np_) {
  vec2 p  = transform(p_);
  vec2 np = transform(np_);
  float aa = distance(p, np)*sqrt(0.5);

  float d = truchet_df(p)-aa;
  
  col = mix(col, vec3(0.1), smoothstep(aa, -aa, d));

  return col;
}


void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord/RESOLUTION.xy;
  vec2 p = -1.0 + 2.0*q;
  p.x *= RESOLUTION.x/RESOLUTION.y;
  vec2 np = p+2.0/RESOLUTION.y;
  
  vec3 col = vec3(1.0);
  col = effect(col, p, np);
  
  col = sqrt(col);
  
  fragColor = vec4(col, 1.0);
}