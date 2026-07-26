// Stage 9: the preprocessor a real Shadertoy is written through.
//
// Nothing here is a gap in the EDSL and nothing here reaches it: the whole file
// is notation, and a front end that stops at `#` fails a shader over spelling
// rather than over any capability. Which is the point - this is the gate the
// measurement was standing behind.

#define QUALITY 2
#define R iResolution.xy
#define T iTime

#define SQ(x) ((x) * (x))
#define BLEND(a, b, t) mix(a, b, clamp(t, 0.0, 1.0))

#if QUALITY > 1 && !defined(CHEAP)
    #define BANDS 0x6
    #define WARP(p) (p + 0.1 * sin(p.yx * 6.0 + T))
#else
    #define BANDS 0x2
    #define WARP(p) (p)
#endif

#ifdef NEVER_DEFINED
    #define TINT vec3(1.0, 0.0, 0.0)
#else
    #define TINT vec3(0.35, 0.55, 0.85)
#endif

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - R * 0.5) / R.y;
    vec2 p = WARP(uv);

    float radius = sqrt(SQ(p.x) + SQ(p.y));
    float rings = fract(radius * float(BANDS) - T * 0.25);

    vec3 col = BLEND(TINT * 0.2, TINT, rings);
    col = BLEND(col, vec3(1.0), SQ(1.0 - radius) * 0.5);

    fragColor = vec4(col, 1.0);
}
