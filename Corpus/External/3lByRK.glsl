// 3lByRK - blackle
// https://www.shadertoy.com/view/3lByRK
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

//CC0 1.0 Universal https://creativecommons.org/publicdomain/zero/1.0/
//To the extent possible under law, Blackle Mori has waived all copyright and related or neighboring rights to this work.

//shitty way to prevent division by zero. if b is zero, add a little bit to it.
vec3 div(vec3 a, vec3 b) {
    b += vec3(equal(b,vec3(0)))*.01;
    return a/b;
}

float antiderivative(float x, vec3 origin, vec3 dir) {
    //antiderivative for pow(dot(sin(origin + x*dir), vec3(1), 2.);
    mat3 A = mat3(1,1,0,-1,0,1,0,-1,-1);
    mat3 B = mat3(1,1,0,1,0,1,0,1,1);
    vec3 Q = origin + dir*x;
    vec3 integral = div(sin(A*Q),(A*dir)) - div(sin(B*Q),(B*dir)) + div((2.*Q-sin(2.*Q)),(4.*dir));
    return dot(integral, vec3(1));
}

float lineintegral(vec3 a, vec3 b) {
    float len = distance(a, b);
    vec3 dir = (b-a)/len;
    return antiderivative(len,a,dir) - antiderivative(0.,a,dir);
}

float scene(vec3 p) {
    p = asin(sin(p+1.));
    return length(p)-1.;
}

vec3 erot(vec3 p, vec3 ax, float ro) {
    return mix(dot(ax,p)*ax,p,cos(ro))+sin(ro)*cross(ax,p);
}

#define FK(k) floatBitsToInt(k*k/7.)^floatBitsToInt(k)
float hash(float a, float b) {
    int x = FK(a), y = FK(b);
    return float((x*x-y)*(y*y+x)-x)/2.14e9;
}

vec3 hash3(float a, float b) {
    float s1 = hash(a, b);
    float s2 = hash(s1, b);
    float s3 = hash(s2, b);
    return vec3(s1,s2,s3);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = (fragCoord-.5*iResolution.xy)/iResolution.y;

    vec3 cam = normalize(vec3(1,uv));
	vec3 init = vec3(-4,0,0);
    cam = erot(cam, vec3(0,1,0), .2);
    init = erot(init, vec3(0,1,0), .2);
    cam = erot(cam, vec3(0,0,1), iTime/5.);
    init = erot(init, vec3(0,0,1), iTime/5.);
    init.x += iTime;
    vec3 p = init;
    bool hit = false;
    for (int i = 0; i < 100 && !hit; i++) {
        float dist = scene(p);
        hit = dist*dist < 1e-6;
        p += dist * cam;
        if (distance(p,init)>50.) break;
    }
    vec3 a = p; vec3 b = init; float scale = 1.;
    float fog = lineintegral(a,b)/20.;
    
    if (uv.x > 0.) {
    	//sum up multiple different versions of the fog
    	for (int i = 0; i < 50; i++) {
            //random rotation
        	vec3 ax = normalize(tan(hash3(float(i),14353.)));
        	float ro = hash(float(i),66123.)*10.;
        	a = erot(a,ax,ro);
        	b = erot(b,ax,ro);
        	fog += lineintegral(a*scale,b*scale)/sqrt(scale);
       		scale *= 1.06;
    	}
		fog /= 2500.;
	}

    fragColor = sqrt(vec4(fog));
}