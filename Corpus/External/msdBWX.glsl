// msdBWX - virmoesiae
// https://www.shadertoy.com/view/msdBWX
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed libpng by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

/*
    AD BY VIRMODOETIAE, a.k.a VIRMOESIAE ---------------------------
    
    Do you like shaders? Would you like to toy with them offline?
    Would you like an interactive UI to play around with your shader
    variables/uniforms in real-time without compilation? Would you
    like to have a layer-based shader blending, without having to
    pass through obscure buffers all the time? Would like to export
    your shaders directly as GIFs?
    Would you like a stand-alone executable (currently for Windows-
    only, but the source code is cross-platform) in less than 9MB?
    
    Then, my dear friend, come get your free copy of:
        
    >>> SHADERTHING <<<
   
    a live, offline, GUI-based shader editor developed by me,
    virmodoetiae (a.k.a, virmoesiae) freely obtainable at:
    
        https://github.com/virmodoetiae/shaderthing
    
    For the release, head to :
    
        https://github.com/virmodoetiae/shaderthing/releases
    
    Everything, including the source code, is available under a 
    very permissive libz/libpng license, so you can really do
    almost anything you want with it!
    
    Please note that currently no tutorials are available, but the
    core usage should be intuitive to most ShaderToy users.
    
    Enjoy!
*/

// Swap with other noise implementations to check for differences
// (best seen when VIEW is set to fbm). The novel implementations
// are triValueNoise and triGradNoise
#define NOISE triValueNoise
//#define NOISE triGradNoise
//#define NOISE quadValueNoise
//#define NOISE quadGradNoise

#define VIEW pattern
//#define VIEW fbm

// My take on the pseudo-random number thing
float random(vec2 x)
{
    return fract(138912.*sin(dot(x, vec2(138.9, 191.2))));
}

// From iq
vec2 random2(vec2 st){
    st = vec2( dot(st,vec2(127.1,311.7)),
              dot(st,vec2(269.5,183.3)) );
    return -1.0 + 2.0*fract(sin(st)*43758.5453123);
}

// Your average 4-point value noise implementation
float quadValueNoise(vec2 n) 
{
	const vec2 d = vec2(0.0, 1.0);
    vec2 b = floor(n), f = smoothstep(vec2(0.0), vec2(1.0), fract(n));
	return 
        mix
        (
            mix(random(b),        random(b + d.yx), f.x), 
            mix(random(b + d.xy), random(b + d.yy), f.x), 
            f.y
        );
}

// Your average 4-point, Perlin-like noise implementation
float quadGradNoise(vec2 n) 
{
	const vec2 d = vec2(0.0, 1.0);
    vec2 r = fract(n);
    vec2 l = floor(n);
    vec2 f = r*r*(3.0-2.0*r);
	return 
        .5+.5*mix
        (
            mix
            (
                dot(random2(l), r),        
                dot(random2(l + d.yx), r-d.yx), 
                f.x
            ), 
            mix
            (
                dot(random2(l + d.xy), r-d.xy), 
                dot(random2(l + d.yy), r-d.yy), 
                f.x
            ), 
            f.y
        );
}

// A 2D noise implementation I came up with that requires 
// one less call to the pseudo-random number generator and
// one less mixing. Easily extandable to 3D
float triValueNoise(vec2 x)
{
    x.y *= 1.1547;
    x.x -= 0.5*x.y;
    vec2 l = floor(x);
    vec2 r = fract(x);
    float s = float(int(r.x+r.y > 1.));
    vec2 e = vec2(1.,0.);
    float a = random(l+s*e.yx);
    float b = random(l+s*e.yx+e.xy);
    float c = random(l+s*e.xy+(1.-s)*e.yx);
    r.y = s+r.y*(1.-2.*s);
    r.x = (r.x-s*r.y)/(1.-r.y);
    r *= r*(3.-2.*r); // Same cubic profile as smoothstep
    return mix(mix(a, b, r.x), c, r.y);
}

// Same as before but using gradients, much smoother
float triGradNoise(vec2 x)
{
    x.y *= 1.1547;
    x.x -= 0.5*x.y;
    vec2 l = floor(x);
    vec2 r = fract(x);
    float s = float(int(r.x+r.y > 1.));
    vec2 e = vec2(1.,0.);
    float a = dot(random2(l+s*e.yx), r-s*e.yx);
    float b = dot(random2(l+s*e.yx+e.xy), r-s*e.yx-e.xy);
    float c = dot(random2(l+s*e.xy+(1.-s)*e.yx), r-s*e.xy-(1.-s)*e.yx);
    r.y = s+r.y*(1.-2.*s);
    r.x = (r.x-s*r.y)/(1.-r.y);
    // Quintic profile to have null second derivate at 
    // boundaries
    r *= 6.*r*r*r*r-15.*r*r*r+10.*r*r; 
    return .5+.5*mix(mix(a, b, r.x), c, r.y);
}

// Fractional Brownian Motion noise to test the 
// single-octave noise function
float fbm(vec2 x)
{
    float n = 0.;
    float A = 0.;
    vec2 af = vec2(1., 2.);
    for (int i=0; i<4; i++)
    {
        // Rotate each octave
        float s = sin(float(2*i));
        float c = cos(float(2*i));
        mat2 m = mat2(c, s, -s, c);
        n += af.x*NOISE(af.y*m*x);
        A += af.x;
        af *= vec2(.4,2.);
    }
    return n/A;
}

// A warp-based pattern inspired by https://iquilezles.org/articles/warp/
float pattern(vec2 x)
{
    vec2 a = vec2(fbm(x)+iTime/15., fbm(x+vec2(2.2,0.)));
    float b = fbm(x+a+iTime/10.);
    vec2 c = vec2(fbm(x+b), fbm(a-vec2(1.7,0.)));
    return fbm(x+.5*c);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.y;
    vec2 d = 3.*vec2(2.+cos(iTime/10.), 3.+sin(iTime/10.));
    fragColor = vec4(vec3(VIEW(2.*uv+d)), 1.);
}