// NdS3WW - mrange
// https://www.shadertoy.com/view/NdS3WW
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License CC0: The monolith, 1x4x9

#define TOLERANCE         0.0001
#define TIME              iTime
#define RESOLUTION        iResolution
#define ROT(a)            mat2(cos(a), sin(a), -sin(a), cos(a))
#define L2(x)             dot(x, x)
#define PCOS(x)           (0.5 + 0.5*cos(x))
#define SKYCOLOR(ro, rd)  skyColor(ro, rd)

const float miss          = 1E4;
const float refrIndex     = 0.8;
const vec3  lightPos      = 2.0*vec3(1.5, 2.0, 1.0);

const vec3 skyCol1        = vec3(0.2, 0.4, 0.6);
const vec3 skyCol2        = vec3(0.4, 0.7, 1.0);
const vec3 sunCol         =  vec3(8.0,7.0,6.0)/8.0;

const vec3 boxDim         = vec3(1.0, 9.0, 4.0)/18.0;
const vec4 plane          = vec4(vec3(0.0, 1.0, 0.0), 0.5);

float tanh_approx(float x) {
//  return tanh(x);
  float x2 = x*x;
  return clamp(x*(27.0 + x2)/(27.0+9.0*x2), -1.0, 1.0);
}

// IQ's polynominal min
float pmin(float a, float b, float k) {
  float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
  
  return mix(b, a, h) - k*h*(1.0-h);
}

// https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl
vec3 hsv2rgb(vec3 c) {
  const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// IQ's ray sphere intersection
vec2 raySphere(vec3 ro, vec3 rd, vec4 s) {
    vec3 ce = s.xyz;
    float ra = s.w;
    vec3 oc = ro - ce;
    float b = dot( oc, rd );
    float c = dot( oc, oc ) - ra*ra;
    float h = b*b - c;
    if( h<0.0 ) return vec2(miss); // no intersection
    h = sqrt( h );
    return vec2( -b-h, -b+h );
}

// IQ's ray box intersection
vec2 rayBox(vec3 ro, vec3 rd, vec3 boxSize, out vec3 outNormal )  {
    vec3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    vec3 n = m*ro;   // can precompute if traversing a set of aligned boxes
    vec3 k = abs(m)*boxSize;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    if( tN>tF || tF<0.0) return vec2(miss); // no intersection
    outNormal = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
    return vec2( tN, tF );
}

float rayPlane(vec3 ro, vec3 rd, vec4 p ) {
  return -(dot(ro,p.xyz)+p.w)/dot(rd,p.xyz);
}

vec3 postProcess(vec3 col, vec2 q)  {
  col=pow(clamp(col,0.0,1.0),vec3(1.0/2.2)); 
  col=col*0.6+0.4*col*col*(3.0-2.0*col);  // contrast
  col=mix(col, vec3(dot(col, vec3(0.33))), -0.4);  // satuation
  col*=0.5+0.5*pow(19.0*q.x*q.y*(1.0-q.x)*(1.0-q.y),0.7);  // vigneting
  return col;
}

vec3 skyColor(vec3 ro, vec3 rd) {
  const vec3 sunDir = normalize(lightPos);
  float sunDot = max(dot(rd, sunDir), 0.0);  
  vec3 final = vec3(0.);

  final += mix(skyCol1, skyCol2, rd.y);
  final += 0.5*sunCol*pow(sunDot, 20.0);
  final += 4.0*sunCol*pow(sunDot, 400.0);    

  float tp  = rayPlane(ro, rd, plane);
  if (tp > 0.0) {
    vec3 pos  = ro + tp*rd;
    vec3 ld   = normalize(lightPos - pos);
    vec3 snor;
    vec2 rb   = rayBox(pos, ld, boxDim, snor);
    vec3 spos = pos + ld*rb.x;
    float it  = rb.y - rb.x;
    // Extremely fake soft shadows
    float sha = rb.x == miss ? 1.0 : (1.0-1.0*tanh_approx(it*6.0/(0.1+rb.x)));
    vec3 nor  = vec3(0.0, 1.0, 0.0);
    vec3 icol = 1.5*skyCol1 + 4.0*sunCol*sha*dot(-rd, nor);
    vec2 ppos = pos.xz*0.75+0.23;
    ppos = fract(ppos+0.5)-0.5;
    float pd  = min(abs(ppos.x), abs(ppos.y));
    vec3  pcol= mix(vec3(0.4), vec3(0.3, 0.3, 0.3), exp(-60.0*pd));

    vec3 col  = icol*pcol;
    col = clamp(col, 0.0, 1.25);
    float f   = exp(-10.0*(max(tp-10.0, 0.0) / 100.0));
    return mix(final, col , f);
  } else{
    return final;
  }
}


vec3 innerRender(vec3 ro, vec3 rd, vec3 enor) {
  const float spr = 0.25;

  vec3 spc = vec3(-enor*spr);
  vec4 sp  = vec4(spc, spr);
  vec2 rs = raySphere(ro,rd, sp);
  vec3 bhsv = vec3(fract(0.05*TIME+dot(enor, rd)*2.0), 0.5, 1.0);
  vec3 bcol = hsv2rgb(bhsv);

  vec3 col = vec3(0.0);
  
  if (rs.x < miss) {
    float t = rs.x;
    vec3 pos = ro + rd*t;
    vec3 nor = normalize(pos - sp.xyz);
    vec3 ld   = normalize(lightPos - pos);
    float dif = pow(max(dot(nor,ld),0.0), 2.0);
    float l   = dif;
    float lin = mix(0.005, 1.0, l);
    float itd = rs.y - rs.x;
    col += lin*bcol;
    col = mix(col, vec3(0.0), tanh_approx(1E-3/(itd*itd)));
  }

  return col;
}

vec3 render(vec3 ro, vec3 rd) {
  vec3 skyCol = SKYCOLOR(ro, rd);
  vec3 col = vec3(0.0);

  float t   = 1E6;
  vec3 nor;
  vec2 rb = rayBox(ro, rd, boxDim, nor);  

  if (rb.x < miss) {
    t = rb.x;
    float itd = rb.y - rb.x;
    vec3 pos  = ro + t*rd;
    vec3 anor = abs(nor);
    vec2 tp   = anor.x == 1.0 ? pos.yz : (anor.y == 1.0 ? pos.xz : pos.xy);
    vec2 bd   = anor.x == 1.0 ? boxDim.yz : (anor.y == 1.0 ? boxDim.xz : boxDim.xy);
    vec3 refr = refract(rd, nor, refrIndex);
    vec3 refl = reflect(rd, nor);
    vec3 rcol = SKYCOLOR(pos, refl);
    float fre = mix(0.0, 1.0, pow(1.0-dot(-rd, nor), 3.0));
    vec3 ld   = normalize(lightPos - pos);
    float dif = pow(max(dot(nor,ld),0.0), 3.0);
    float spe = pow(max(dot(reflect(-ld, nor), -rd), 0.), 50.);
    float lin = mix(0.0, 1.0, dif);
    vec3 lcol = 2.0*sqrt(sunCol);

    col = innerRender(pos, refr, nor);

    vec2 btp = (1.0*bd - abs(tp));
    float bdd = pmin(btp.x, btp.y, 0.0125);    
    float bddd = exp(-10000.0*bdd*bdd);
//    col += vec3(0.5, 0.5, 1.0)*bddd*10;
    col *= 1.0 - bddd;

    vec3 diff = hsv2rgb(vec3(0.7, fre, 0.075*lin))*lcol;
    col += fre*rcol+diff+spe*lcol;
    if (refr == vec3(0.0)) {
      // Not expected to happen as the refraction index < 1.0
      col = vec3(1.0, 0.0, 0.0);
    }
    
    col = mix(col, skyCol, tanh_approx(1E-5/(itd*itd)));
  } else {
    // Ray intersected sky
    return skyCol;
  }

  return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 q = fragCoord.xy/RESOLUTION.xy; 
  vec2 p = -1.0 + 2.0*q;
  p.x *= RESOLUTION.x/RESOLUTION.y;

  const float mul = 0.05;
  float mm = mix(0.25, 0.5, PCOS(TIME*mul*sqrt(3.0)));
  vec3 ro = mm*vec3(2.0, 0, 0.2);
  ro.xz *= ROT((TIME*mul));
  ro.yz *= ROT(sin(TIME*mul*sqrt(0.5))*0.5);
  ro += vec3(0.0, mm, 0.0);

  vec3 ww = normalize(vec3(0.0, 0.0, 0.0) - ro);
  vec3 uu = normalize(cross( vec3(0.0,1.0,0.0), ww));
  vec3 vv = normalize(cross(ww,uu));
  const float rdd = 2.00;
  vec3 rd = normalize( p.x*uu + p.y*vv + rdd*ww);

  vec3 col = render(ro, rd);
  fragColor = vec4(postProcess(col, q),1.0);
}
