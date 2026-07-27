// ctfcW4 - SnoopethDuckDuck
// https://www.shadertoy.com/view/ctfcW4
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// License: CC0

#define pi 3.14159
#define ss(a) smoothstep(-1./R.y, 1./R.y, .02 - length(u - a))

// Spring easing function:
// https://www.desmos.com/calculator/vluz5j0svo

// Wobble both ways (green) 
// https://www.desmos.com/calculator/9atfimg1ox
#define f(a,b,x) sign(cos(x)) \
              * (1. - exp(-(a) * abs(cos(x))) * cos((b) * abs(cos(x))))

// Instant push -> wobble (red)
// https://www.desmos.com/calculator/gbkax818fx
float g(float a1, float b1, float a2, float b2, float x) {
    x = mod(x, 2.);
    float f1 = 1. - exp(-a1 * x) * cos(b1 * x); 
    float f2 = exp(-a2 * (x-1.)) * cos(b2 * (x-1.));
    f2 = mix(1., f2, step(1., x));
    return 1. - 2. * f1 * f2;
}

// Slow push -> wobble (blue)
// https://www.desmos.com/calculator/rwsnoaj9by
// a: oscillation strength,  a > 0
// b: oscillation amount,    b = anything
// n: Superellipse strength, n = 2, 4, 6, etc.
float h(float a, float b, float n, float x) {
    // Multiply by square wave to flip-flop sign of wave
    float s = sign(mod(x, 4.) - 2.); 
    
    // Make x periodic
    x = mod(x, 2.);
    
    // Clamp x so mix(f,g,v) is a quarter superellipse for 1 < x < 2
    float v = min(1., x);
    
    // Spring equation
    float f = 1. - exp(-a * x) * cos(b * x);
    
    // Half superellipse equation (n = 2. is circle)
    float g = pow(1. - pow(1.-x, n), 1./n); 
    // g = sqrt(1. - (1.-x) * (1.-x));
    
    // Mix spring into circle, then mix with an equation which
    // is vertical at 0 so that the start/end gradients 
    // match at x = 0, 2, 4 etc.
    // (sloppy and expensive)
    float l = mix(mix(f, g, v), 
                  1. - exp(-7. * sqrt(x)), 
                  1. - pow(v, .1)); 
    
    return l * s;    
}
      
void mainImage( out vec4 O, in vec2 I )
{
    float t = iTime;
    
    vec2 R = iResolution.xy,
         u = (I-.5*R)/R.y,
         p = vec2(.5 * f(5., 10., pi/2. * (t + 1.)), .1),
         q = vec2(.5 * g(12., 20., 6., 16., .5 * t), 0),
         r = vec2(.5 * h(8., 22., 4., t), -.1);
         
    O = vec4(ss(q), ss(p), ss(r), 0);
}