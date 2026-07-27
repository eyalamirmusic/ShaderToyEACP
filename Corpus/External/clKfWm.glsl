// clKfWm - afl_ext
// https://www.shadertoy.com/view/clKfWm
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// afl_ext 2017-2023
// MIT License

// Use your mouse to move the camera around! Press the Left Mouse Button on the image to look around!

#define NormalizedMouse (iMouse.xy / iResolution.xy) // normalize mouse coords

// settings for the shader
#define STEP_SIZE_SCALE 500.0 // lower means more steps

#define CloudsFloor 1000.0
#define CloudsCeil 5000.0

// decide how much clouds coverage there is, this can dramatically affect performance
// basically this shader works better when there are more than less clouds
#define COVERAGE_START 0.02
#define COVERAGE_END 0.23

#define CLOUDS_FBM_STEPS 5

#define EXPOSURE 0.5


// this shader supports view from inside and over the clouds too, 
// give it a try by uncommenting this line
//#define FLYING_CAMERA

#ifndef FLYING_CAMERA
    #define CAMERA_HEIGHT (200.0)
    #define FOG_COLOR vec3(0.04)
#endif
#ifdef FLYING_CAMERA
    #define CAMERA_HEIGHT (10.0 + (0.5 + 0.5 * sin(iTime * 0.2)) * 7000.0)
    #define FOG_COLOR vec3(0.00)
#endif

// Helper function generating a rotation matrix around the axis by the angle
mat3 createRotationMatrixAxisAngle(vec3 axis, float angle) {
  float s = sin(angle);
  float c = cos(angle);
  float oc = 1.0 - c;
  return mat3(
    oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 
    oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 
    oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c
  );
}

// Helper function that generates camera ray based on UV and mouse
vec3 getRay(vec2 fragCoord) {
  vec2 uv = ((fragCoord.xy / iResolution.xy) * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
  // for fisheye, uncomment following line and comment the next one
  //vec3 proj = normalize(vec3(uv.x, uv.y, 1.0) + vec3(uv.x, uv.y, -1.0) * pow(length(uv), 2.0) * 0.05);  
  vec3 proj = normalize(vec3(uv.x, uv.y, 1.5));
  if(iResolution.x < 600.0 || NormalizedMouse.x == 0.0) {
    return proj * createRotationMatrixAxisAngle(vec3(1.0, 0.0, 0.0), -0.6);
  }
  return createRotationMatrixAxisAngle(vec3(0.0, -1.0, 0.0), 3.0 * ((NormalizedMouse.x + 0.5) * 2.0 - 1.0)) 
    * createRotationMatrixAxisAngle(vec3(1.0, 0.0, 0.0), 0.5 + 1.5 * ((NormalizedMouse.y * 1.5) * 2.0 - 1.0))
    * proj;
}

// Standard 2d noise
float rand2dTime(vec2 co){
    co *= iTime;
    return fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453);
}

// Hash for 3d vectors
float rand3d(vec3 p){
    return fract(4768.1232345456 * sin((p.x+p.y*43.0+p.z*137.0)));
}

// 3D value noise
float noise3d(vec3 x){
    vec3 p = floor(x);
    vec3 fr = fract(x);
    vec3 LBZ = p + vec3(0.0, 0.0, 0.0);
    vec3 LTZ = p + vec3(0.0, 1.0, 0.0);
    vec3 RBZ = p + vec3(1.0, 0.0, 0.0);
    vec3 RTZ = p + vec3(1.0, 1.0, 0.0);

    vec3 LBF = p + vec3(0.0, 0.0, 1.0);
    vec3 LTF = p + vec3(0.0, 1.0, 1.0);
    vec3 RBF = p + vec3(1.0, 0.0, 1.0);
    vec3 RTF = p + vec3(1.0, 1.0, 1.0);

    float l0candidate1 = rand3d(LBZ);
    float l0candidate2 = rand3d(RBZ);
    float l0candidate3 = rand3d(LTZ);
    float l0candidate4 = rand3d(RTZ);

    float l0candidate5 = rand3d(LBF);
    float l0candidate6 = rand3d(RBF);
    float l0candidate7 = rand3d(LTF);
    float l0candidate8 = rand3d(RTF);

    float l1candidate1 = mix(l0candidate1, l0candidate2, fr[0]);
    float l1candidate2 = mix(l0candidate3, l0candidate4, fr[0]);
    float l1candidate3 = mix(l0candidate5, l0candidate6, fr[0]);
    float l1candidate4 = mix(l0candidate7, l0candidate8, fr[0]);


    float l2candidate1 = mix(l1candidate1, l1candidate2, fr[1]);
    float l2candidate2 = mix(l1candidate3, l1candidate4, fr[1]);


    float l3candidate1 = mix(l2candidate1, l2candidate2, fr[2]);

    return l3candidate1;
}

// 3D simplex noise, cool trick
float supernoise3d(vec3 p){

	float a =  noise3d(p);
	float b =  noise3d(p + 10.5);
	return (a + b) * 0.5;
}

// Sphere raytracing
struct Ray { vec3 o; vec3 d; };
struct Sphere { vec3 pos; float rad; };
float minhit = 0.0;
float maxhit = 0.0;
float raySphereIntersect(in Ray ray, in Sphere sphere)
{
    vec3 oc = ray.o - sphere.pos;
    float b = 2.0 * dot(ray.d, oc);
    float c = dot(oc, oc) - sphere.rad*sphere.rad;
    float disc = b * b - 4.0 * c;
    vec2 ex = vec2(-b - sqrt(disc), -b + sqrt(disc))/2.0;
    minhit = min(ex.x, ex.y);
    maxhit = max(ex.x, ex.y);
    //return mix(ex.y, ex.x, step(0.0, ex.x));
    //return max(ex.x, ex.y);
    if(minhit < 0.0 && maxhit > 0.0)
        return maxhit;
    if(minhit < maxhit && minhit > 0.0)
        return minhit;
    return 0.0;    
}
float hitLimit = 678000.0;
float higherHitLimit = 6780000.0;
#define isHitBoolean(v) (v > 0.0 && v < hitLimit)
#define isHitStep(v) step(0.0, v)

// Clouds code

#define VECTOR_UP vec3(0.0,1.0,0.0)

// Pretty self explanatory FBM with some precisely adjusted behavior
float cloudsFBM(vec3 p){
    float a = 0.0;
    float w = 0.5;
    for(int i=0;i<CLOUDS_FBM_STEPS;i++){
        float x = abs(0.5 - supernoise3d(p))*2.0;
        a += x * w;
        p = p * 2.9;
        w *= 0.60;
    }
    return a;
}


float planetradius = 6378000.1;
    
float getHeightOverSurface(vec3 p){
    return length(p) - planetradius;
}

// this function probes the clouds densite at a point
// returns XY
// X = coverage of clouds at this point, 
// Y = cloud color at this point, basically incoming radiance
vec2 cloudsDensity3D(vec3 pos){
    float h = getHeightOverSurface(pos);
    pos -= vec3(0,planetradius,0);
   
    // make sure the clouds look like clouds by making the density
    // scale with height between the layers, make it a height coefficent
    // this coeff is 1.0 in between the layers, and 0.0 at the edges
    float measurement = (CloudsCeil - CloudsFloor) * 0.5;
    float mediana = (CloudsCeil + CloudsFloor) * 0.5;
    float mlt = (( 1.0 - (abs( h - mediana ) / measurement )));
    
    // probe the fbm with moving position so the clouds move
    float density = cloudsFBM(pos * 0.01 * 0.021 + vec3(iTime * 0.04, 0.0, 0.0));
    
    // calculate the radiance
    float scattering = (h - CloudsFloor) / (CloudsCeil - CloudsFloor);
    
    return vec2(density * mlt, scattering);
}
     
vec4 raymarchClouds(vec3 p1, vec3 p2, float randomValue){
    // non constant step size, directly coupled to distance between points
    // this is required to make in cloud rendering right
    // also makes coverage calculation consistent with different distances raymarched
    float stepsize = STEP_SIZE_SCALE / distance(p1, p2);
    // coverage is inverted to have less calculations inside the loop
    float coverageinv = 1.0;
    vec3 color = vec3(0.0);
    // start of the raymarching position is nudged by a bit with a random value to make
    // the sampling better
    float iter = randomValue * stepsize;
    while(iter < 1.0 && coverageinv > 0.0){
        vec2 density = cloudsDensity3D(mix(p1, p2, iter));
        
        // final coverage at point is calculated here
        float clouds = smoothstep(COVERAGE_START, COVERAGE_END, clamp(density.x, 0.0, 1.0));
        
        // adjust the color taking into account the coverage left, this is basically alpha blending
        color += clouds * max(0.0, coverageinv) * density.y;//vec3(pow(density.y * 1.0, 2.0));

        // add coverage by subtracting from the inverted coverage, and subtract a bit more for fog rendering
        coverageinv -= clouds + 0.001;
        
        // variable next step size
        // if density is 0 then step should be larger to skip not interesting areas
        // if density is higher then step lower to sample the interesting areas more
        iter += stepsize * 0.1 + stepsize * 2.0 * max(0.0, 0.2 - density.x);
    }
    float coverage = 1.0 - clamp(coverageinv, 0.0, 1.0);  
    return vec4(pow(color, vec3(2.0)) * 20.0, coverage);
}

    
// very native rendering for the ground, shadow is basically clouds sampled directly above
// this doesnt look that great, but at least look like something...
// by adjusting the direction and smoothstepping the coverage, really nice sun shadows can be achieved
// but with so high clouds coverage no light will peek through so its done like that here
vec3 renderGround(vec3 point, float dist, float random){
    float shadow = raymarchClouds(
            point + vec3(0.0, CloudsFloor, 0.0), 
            point + vec3(0.0, CloudsCeil, 0.0), 
            random
        ).x;

    vec3 color = vec3(0.2, 0.2, 0.2) * vec3(0.8 + 0.2 * shadow);
        
    float fogIntensity = 1.0 - 1.0 / (0.001 * dist);
    return mix(color, FOG_COLOR, clamp(fogIntensity, 0.0, 1.0));
}

    
// Straightforward, render raymarch, apply fog, alpha blend with the background, return
vec3 renderClouds(vec3 pointStart, vec3 pointEnd, vec3 background, float dist, float random){
    vec4 clouds = raymarchClouds(
            pointStart,
            pointEnd, 
            random
        );
    vec3 color = mix(background, clouds.xyz, clouds.a);
    float fogIntensity = 1.0 - 1.0 / (0.0001 * dist);
    return mix(color, FOG_COLOR, clamp(fogIntensity, 0.0, 1.0));
}


// Great tonemapping function from my other shader: https://www.shadertoy.com/view/XsGfWV
vec3 aces_tonemap(vec3 color) {  
  mat3 m1 = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
  );
  mat3 m2 = mat3(
    1.60475, -0.10208, -0.00327,
    -0.53108,  1.10813, -0.07276,
    -0.07367, -0.00605,  1.07602
  );
  vec3 v = m1 * color;  
  vec3 a = v * (v + 0.0245786) - 0.000090537;
  vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
  return pow(clamp(m2 * (a / b), 0.0, 1.0), vec3(1.0 / 2.2));  
}

// Main
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // get the ray direction
    vec3 dir = getRay(fragCoord);
    vec2 uv = fragCoord.xy / iResolution.xy;
    
    // sky color as the default initial color
    vec3 C = vec3(0.5, 0.7, 0.8);
    
    // random for clouds raymarching
    float random = fract(rand2dTime(uv));
    
    // define clouds height and planet ground
    Sphere sphereCeilLayer = Sphere(vec3(0), planetradius + CloudsCeil);
    Sphere sphereFloorLayer = Sphere(vec3(0), planetradius + CloudsFloor);
    Sphere sphereGround = Sphere(vec3(0), planetradius);

    // define camera origin relative to surface
    vec3 origin = vec3(100.0, CAMERA_HEIGHT, 100.0);
    // define camera origin relative to the planet
    vec3 atmorg = vec3(0.0, planetradius, 0.0) + origin;
    Ray ray = Ray(atmorg, dir);
    
    // adjust the ray hit detection if above the clouds, this could be done better
    if(origin.y >= CloudsCeil){
        hitLimit = higherHitLimit;
    }
    
    // Intersections
    float hitceil = raySphereIntersect(ray, sphereCeilLayer);
    float hitfloor = raySphereIntersect(ray, sphereFloorLayer);
    float hitGround = raySphereIntersect(ray, sphereGround);
    
    if(origin.y < CloudsFloor){
        // below clouds
        if(isHitBoolean(hitGround)){
            vec3 groundHitPoint = atmorg + (dir * hitGround);
            C = renderGround(groundHitPoint, hitGround, random);
        } else {
            vec3 cloudsPointStart = atmorg + (dir * min(hitfloor, hitceil));
            vec3 cloudsPointEnd = atmorg + (dir * max(hitfloor, hitceil));
            C = renderClouds(cloudsPointStart, cloudsPointEnd, C, min(hitfloor, hitceil), random);
        }
    
    } else if(origin.y >= CloudsFloor && origin.y < CloudsCeil){
        // inside the clouds
        vec3 background = C;
        if(isHitBoolean(hitGround)){
            vec3 groundHitPoint = atmorg + (dir * hitGround);
            background = renderGround(groundHitPoint, hitGround, random);
        }
        vec3 cloudsPointStart = atmorg;
        float targetDistance = 0.0;
        if(isHitBoolean(hitfloor) && isHitBoolean(hitceil)){
            targetDistance = max(hitfloor, hitceil);
        } else if(isHitBoolean(hitfloor)){
            targetDistance = hitfloor;
        } else if(isHitBoolean(hitceil)){
            targetDistance = hitceil;
        }
        vec3 cloudsPointEnd = atmorg + (dir * targetDistance);
        C = renderClouds(cloudsPointStart, cloudsPointEnd, background, 0.0, random);
        
    } else if(origin.y >= CloudsCeil){
        // above the clouds
        vec3 background = C;
        if(isHitBoolean(hitGround)){
            vec3 groundHitPoint = atmorg + (dir * hitGround);
            background = renderGround(groundHitPoint, hitGround, random);
        }
        float targetDistanceStart = 0.0;
        float targetDistanceEnd = 0.0;
        if(isHitBoolean(hitfloor) && isHitBoolean(hitceil)){
            targetDistanceStart = hitceil;
            targetDistanceEnd = hitfloor;
        } else if(isHitBoolean(hitceil)){
            raySphereIntersect(ray, sphereCeilLayer);
            targetDistanceStart = minhit;
            targetDistanceEnd = maxhit;
        }        
        if(isHitBoolean(targetDistanceStart) && isHitBoolean(targetDistanceEnd)){
            vec3 cloudsPointStart = atmorg + (dir * targetDistanceStart);
            vec3 cloudsPointEnd = atmorg + (dir * targetDistanceEnd);
            C = renderClouds(cloudsPointStart, cloudsPointEnd, background, 0.0, random);
        }
    }
    
    
    // adjust exposure, tonemap and return
    fragColor = vec4( aces_tonemap(C * EXPOSURE * vec3(1.0, 0.9, 0.8)),1.0);      
}