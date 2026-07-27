// Ws2cRh - mla
// https://www.shadertoy.com/view/Ws2cRh
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

////////////////////////////////////////////////////////////////////////////////
//
// Projective Conic Envelope
//
// Copyright (c) Matthew Arcus, 2020
// MIT License: https://opensource.org/licenses/MIT
//
// More projective magic - generate an ellipse as an envelope of lines.
// In fact, we start with the ellipse and find a network of lines
// enveloping it: at each point p, find tangents to the ellipse,
// intersect these with a fixed axis at x = -3 - this will be the
// source of the rays. From axis intersection point, map to a radial
// parameter, then find closest displayed ray, map that back to the
// axis and find the tangents from there & these are the lines that
// actually get displayed.
//
// Mouse changes size and orientation of ellipse.
//
////////////////////////////////////////////////////////////////////////////////

const float PI =  3.141592654;

vec3 join(vec3 p, vec3 q) {
  // Return either intersection of lines p and q
  // or line through points p and q, r = kp + jq
  return cross(p,q);
}

float line(vec3 p, vec3 q) {
  return abs(dot(p,q)/(p.z*length(q.xy)));
}

// Set tan1 and tan2 to the two tangents to conic X from point p.
// Return false if no tangents (eg. inside an ellipse).
bool tangents(vec3 p, mat3 X, out vec3 tan1, out vec3 tan2) {
  vec3 polar = X*p; // Line between tangents
  float a = polar.x, b = polar.y, c = polar.z;
  // Two points on the polar line. Q is the nearest point to origin,
  // R is at infinity, ie. is direction vector.
  vec3 Q = vec3(a,b,-(a*a+b*b)/c);
  vec3 R = vec3(-b,a,0);

  // Find intersection of QR with conic, ie. dot(Q+kR,X*(Q+kR)) = 0
  float A = dot(R,X*R), B = dot(Q,X*R), C = dot(Q,X*Q);
  float D = B*B-A*C;
  if (D < 0.0) return false;
  D = sqrt(D);
  float k1,k2;
  if (B > 0.0) {
    k1 = (-B-D)/A; k2 = C/(A*k1);
  } else {
    k2 = (-B+D)/A; k1 = C/(A*k2);
  }
  tan1 = join(p,Q+k1*R); tan2 = join(p,Q+k2*R);
  return true;
}

vec3 hsv2rgb( in vec3 c ) {
  vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
  rgb = rgb*rgb*(3.0-2.0*rgb); // cubic smoothing	
  return c.z * mix( vec3(1.0), rgb, c.y);
}

void mainImage(out vec4 fragColor, vec2 fragCoord ) {
  float scale = 3.0;
  float t = 0.2*iTime+PI/6.0;
  float A = 0.25, B = 1.0;
  if (iMouse.x > 0.0) {
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;
    t += PI*(m.y);
    B = exp(-m.x);
  }
  float cost = cos(t), sint = sin(t);
  // Conic matrix - conic is points p with pXp = 0
  mat3 X = mat3(A,0,0,0,B,0,0,0,-1);
  // Apply tranformation to conic matrix.
  mat3 P = mat3(cost,sint,0, -sint,cost,0, 0,0,1);
  X = transpose(P)*X*P;

  vec3 p = vec3(scale*(2.0*fragCoord - iResolution.xy)/iResolution.y,1);

  vec3 col = vec3(0);
  
  float lwidth0 = 0.0;
  float lwidth1 = max(0.02,fwidth(p.x));

  vec3 tan1,tan2,tan11,tan12,tan21,tan22;
  if (tangents(p,X,tan1,tan2)) {
    float N = 64.0;
    vec3 axis = vec3(1,0,3);
    float index1,index2;

    vec3 p1 = join(tan1,axis);
    float t1 = atan(p1.y/p1.z);
    t1 += 0.1*iTime;
    t1 *= N/PI; t1 = round(t1); index1 = t1; t1 *= PI/N;
    t1 -= 0.1*iTime;
    p1 = vec3(-3,tan(t1),1);
    p1.y = sign(p1.y)*min(abs(p1.y),1e4); // Fix up silly values
    if (tangents(p1,X,tan11,tan12)) {
      vec3 c1 = hsv2rgb(vec3(index1/N,1,1));
      float d = line(p,tan11);
      col = mix(c1,col,smoothstep(lwidth0,lwidth1,d));
      float tt = dot(normalize(tan2.xy),normalize(tan12.xy));
      // Try not to get the wrong tangent here. There must be a better
      // way of doing this.
      if (abs(tt) < 0.99) {
        d = line(p,tan12);
        col = mix(c1,col,smoothstep(lwidth0,lwidth1,d));
      }
    }

    vec3 p2 = join(tan2,axis);
    float t2 = atan(p2.y/p2.z);
    t2 += 0.1*iTime;
    t2 *= N/PI; t2 = round(t2); index2 = t2; t2 *= PI/N;
    t2 -= 0.1*iTime;
    p2 = vec3(-3,tan(t2),1);
    p2.y = sign(p2.y)*min(abs(p2.y),1e4); // Fix up silly values
    if (tangents(p2,X,tan21,tan22)) {
      vec3 c2 = hsv2rgb(vec3(index2/N,1,1));
      float d = line(p,tan22);
      col = mix(c2,col,smoothstep(lwidth0,lwidth1,d));
      float tt = dot(normalize(tan1.xy),normalize(tan21.xy));
      // Try not to get the wrong tangent here.
      if (abs(tt) < 0.99) {
        d = line(p,tan21);
        col = mix(c2,col,smoothstep(lwidth0,lwidth1,d));
      }
    }
  }
  col = pow(col,vec3(0.4545));
  fragColor = vec4(col,1);
}