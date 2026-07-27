// NtsGWH - blackle
// https://www.shadertoy.com/view/NtsGWH
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

//CC0 1.0 Universal https://creativecommons.org/publicdomain/zero/1.0/
//To the extent possible under law, Blackle Mori has waived all copyright and related or neighboring rights to this work.

float nozerosgn(float x) { return step(0.,x)*2.-1.; }
vec2  nozerosgn(vec2  x) { return step(0.,x)*2.-1.; }

//returns the vectors pointing to each edge of the box with dimensions d,
//ordered by closeness to the point p. only valid inside the rectangle
void edge4(vec2 p, vec2 d, inout vec2 e1, inout vec2 e2, inout vec2 e3, inout vec2 e4) {
//this probably has some really elegant underlying structure, but I'm too tired to figure it out
    vec3 p3 = vec3(nozerosgn(p), 0); //this lets us construct the edge vectors
    p = abs(p);
    float c2 = nozerosgn(p.x+p.y-d.x-d.y+min(d.x,d.y)*2.);
    e1 = (p.x-d.x < p.y-d.y) ? p3.zy : p3.xz;
    e2 =  c2*((c2 < 0. == p.x-d.x < p.y-d.y) ? p3.zy : p3.xz);
    e3 = -c2*((c2 < 0. == p.x+d.x < p.y+d.y) ? p3.zy : p3.xz);
    e4 = (p.x+d.x < p.y+d.y) ? -p3.zy : -p3.xz;
}

//rest of this is visualization code
//colours in box cycle between the boundaries for the 1st, 2nd, 3rd, and 4th closest edge.
float linedist(vec2 p, vec2 a, vec2 b) {
    float k = dot(p-a,b-a)/dot(b-a,b-a);
    return length(p-mix(a,b,clamp(k,0.,1.)));
}
vec2 closestonline(vec2 p, vec2 a, vec2 b) {
    float k = dot(p-a,b-a)/dot(b-a,b-a);
    return mix(a,b,clamp(k,0.,1.));
}

float aa(float x) {
    return smoothstep(0., 1.5/iResolution.y, x);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-iResolution.xy*.5)/iResolution.y;
    vec2 mouse = (iMouse.xy-iResolution.xy*.5)/iResolution.y;

    vec2 d = vec2(sin(iTime/3.)*.5+1., -sin(iTime/3.)*.5+1.)*.3;
    vec2 p = vec2(sin(iTime), cos(iTime*3./2.))*min(d.x,d.y);
    if (iMouse.z > 0.) p = mouse;

    vec2 e1, e2, e3, e4;
    edge4(p, d, e1, e2, e3, e4);

    float d1 = linedist(uv, d*e1 + d*e1.yx, d*e1 - d*e1.yx);
    float d2 = linedist(uv, d*e2 + d*e2.yx, d*e2 - d*e2.yx);
    float d3 = linedist(uv, d*e3 + d*e3.yx, d*e3 - d*e3.yx);
    float d4 = linedist(uv, d*e4 + d*e4.yx, d*e4 - d*e4.yx);
    
    vec2 c1 = closestonline(p, d*e1 + d*e1.yx, d*e1 - d*e1.yx);
    vec2 c2 = closestonline(p, d*e2 + d*e2.yx, d*e2 - d*e2.yx);
    vec2 c3 = closestonline(p, d*e3 + d*e3.yx, d*e3 - d*e3.yx);
    vec2 c4 = closestonline(p, d*e4 + d*e4.yx, d*e4 - d*e4.yx);
    float dd1 = linedist(uv, p, c1);
    float dd2 = linedist(uv, p, c2);
    float dd3 = linedist(uv, p, c3);
    float dd4 = linedist(uv, p, c4);

    edge4(uv, d, e1, e2, e3, e4);
    bool vb1 = sin(iTime/4.) < 0.;
    bool vb2 = sin(iTime/2.) < 0.;
    vec2 vis = vb1 ? (vb2 ? e1 : e3) : (vb2 ? e2 : e4);
    
    vec3 col = length(max(abs(uv)-d,0.)) > 0. ? vec3(1) : vec3(vis*.3+.7,1.);
    float dmin = min(min(min(d1,dd1),min(d2,dd2)),min(min(d3,dd3),min(d4,dd4)));
    col = mix(vec3(.00), col, aa(dmin-.007));
    col = mix(vec3(.75), col, aa(min(d4,dd4)-.005));
    col = mix(vec3(.50), col, aa(min(d3,dd3)-.005));
    col = mix(vec3(.25), col, aa(min(d2,dd2)-.005));
    col = mix(vec3(.00), col, aa(min(d1,dd1)-.005));
    col = mix(vec3(.85,.05,.05), col, aa(distance(p,uv)-.020));

    // Output to screen
    fragColor = vec4(sqrt(col),1.0);
}