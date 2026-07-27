// flsGDH - blackle
// https://www.shadertoy.com/view/flsGDH
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

//CC0 1.0 Universal https://creativecommons.org/publicdomain/zero/1.0/
//To the extent possible under law, Blackle Mori has waived all copyright and related or neighboring rights to this work.

//this is further explorations in how domain repetition works
//and under what scenarios a naively domain repeated object might fail to be an SDF

//this is a visualization of how the closest neighbour SDF inside a domain changes as those SDFs change
//if we imagine a point within a domain, we can ask "what is the closest neighbouring SDF?"
//in this case, we have 6 boxes in the immediate neighbouring domains.
//as we move a point within the central domain around, the closest box to that point will change
//we can visualze the boundaries at which a point stops being closest to one box, and starts being closest to a different box
//inside the middle box of this shader is such a visualization
//as the dimensions of the neighbouring boxes change, the shape of the boundaries change.

//when the boxes are perfect cubes, we can model the boundaries with
//the "face" function in this shader: https://www.shadertoy.com/view/Wl3fD2
//see also the youtube video: https://youtu.be/I8fmkLK1OKg

vec3 erot(vec3 p, vec3 ax, float ro) {
    return mix(dot(ax,p)*ax,p,cos(ro)) + sin(ro)*cross(ax,p);
}

float box(vec3 p, vec3 d) {
    p = abs(p)-d;
    return length(max(p,0.)) + min(0.,max(max(p.x,p.y),p.z));
}

float obj(vec3 p) {
    return box(p, vec3(.25,.25,.25+sin(iTime)*.24)) - .01;
}

bool sort(inout float a, inout float b) {
    if (b < a) {
        float tmp = a;
        a = b; b = tmp;
        return true;
    }
    return false;
}

int gid;
float scene(vec3 p) {
    float u = obj(p - vec3(0,0,1));
    float d = obj(p - vec3(0,0,-1));
    float e = obj(p - vec3(0,1,0));
    float w = obj(p - vec3(0,-1,0));
    float n = obj(p - vec3(1,0,0));
    float s = obj(p - vec3(-1,0,0));
    
    gid = 0;
    if (sort(u,d)) gid = 1;
    sort(d,e);
    sort(e,w);
    sort(w,n);
    sort(n,s);
    
    if (sort(u,d)) gid = 2;
    sort(d,e);
    sort(e,w);
    sort(w,n);
    
    if (sort(u,d)) gid = 3;
    sort(d,e);
    sort(e,w);
    
    if (sort(u,d)) gid = 4;
    sort(d,e);
    
    if (sort(u,d)) gid = 5;
    
    float closest = u;
    float secondclosest = d;
    float boundary = (abs(closest-secondclosest)-.01)/2.;
    boundary = max(boundary, box(p, vec3(.5)));
    
    return min(closest,boundary);
}

vec3 norm(vec3 p) {
    mat3 k = mat3(p,p,p) - mat3(0.0001);
    return normalize(scene(p) - vec3(scene(k[0]),scene(k[1]),scene(k[2])));
}

// https://iquilezles.org/www/articles/palettes/palettes.htm
vec3 palette( float t )
{
    return cos(t+vec3(0,1.8,3.2))*.4+.6;
}

vec3 shade(vec3 p, vec3 cam) {
    float fid = float(gid);
    vec3 n = norm(p);
    vec3 r = reflect(cam,n);
    float fres = 1.-abs(dot(cam,n))*.98;
    float fact = length(sin(r*3.5)*.5+.5)/sqrt(3.0);
    return palette(fid)*(fact*.5 + pow(fact,5.)*4.*fres);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-iResolution.xy*.5)/iResolution.y;

    vec3 cam = normalize(vec3(.8,uv));
    vec3 init = vec3(-2.5,0,0);
    float yrot = .2;
    float zrot = iTime/2.;
    cam = erot(cam,vec3(0,1,0),yrot);
    init = erot(init,vec3(0,1,0),yrot);
    cam = erot(cam,vec3(0,0,1),zrot);
    init = erot(init,vec3(0,0,1),zrot);
    
    vec3 p = init;
    bool hit = false;
    
    
    vec3 col = vec3(0);
    float atten = .7;
    float k = 1.;
    for (int i = 0; i < 200; i++ ) {
        float dist = scene(p);
        p += cam*dist*k;
        if (dist*dist < 1e-7) {
            col += shade(p, cam)*atten;
            atten *= .7;
            p += cam*.005;
            k = sign(scene(p));
        }
        if(distance(p,init)>100.)break;
    }
    vec3 spec = shade(p, cam);
    fragColor = vec4(sqrt(smoothstep(0.,1.,col)),1.0);
}