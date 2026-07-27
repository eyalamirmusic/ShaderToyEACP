// wsByDh - andretugan
// https://www.shadertoy.com/view/wsByDh
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc-by-3.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// Author: https://www.shadertoy.com/user/andretugan
// Creative Commons Attribution-NonCommercial 3.0 Unported License
// https://creativecommons.org/licenses/by-nc/3.0

#define NUM_CHORDS 128

#define M_PI 3.14159265358
#define M_2_PI (2. * 3.14159265358)

#define FADE_INNER_RADIUS 0.8
#define FADE_OUTER_RADIUS 1.1
#define LINE_WIDTH 4.

// Function from Inigo Quilez
// https://www.shadertoy.com/view/MsS3Wc
vec3 hsv2rgb( in vec3 c )
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );

	rgb = rgb*rgb*(3.0-2.0*rgb); // cubic smoothing	

	return c.z * mix( vec3(1.0), rgb, c.y);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord )
{    
    vec2 uv = (2.*fragCoord - iResolution.xy)/iResolution.y;                   
    float uv2 = dot(uv, uv);        
    if (uv2 > FADE_OUTER_RADIUS * FADE_OUTER_RADIUS) { 
    	fragColor = vec4(0.0,0.0,0.0,1.0);
        return;
    }
               
    float multiplier = 1.99 + 5. * (.5 - .5 * cos(iTime * 0.03));
    float start = multiplier * M_PI * 0.25;
    float val = 0.;

    for (int i = 0; i < NUM_CHORDS; ++i) {
        float angle1 = start + M_2_PI / float(NUM_CHORDS) * float(i);
        float angle2 = multiplier * angle1;
        vec2 point1 = vec2(cos(angle1), sin(angle1));	                       
        vec2 point2 = vec2(cos(angle2), sin(angle2));

        vec2 diff = point2 - point1;
        vec2 perp = point1 + (dot(uv - point1, diff) / dot(diff, diff)) * diff - uv;
        float dist2 = dot(perp, perp);
        
        float line_width = LINE_WIDTH / iResolution.y;                                        
    	float add_val = smoothstep(line_width * line_width, line_width * line_width * 0.5, dist2);                                                 
        add_val *= smoothstep(FADE_OUTER_RADIUS * FADE_OUTER_RADIUS, FADE_INNER_RADIUS * FADE_INNER_RADIUS, uv2);        
        val += add_val;
    }
    
    val *= 20. / float(NUM_CHORDS);
    val = pow(val, 0.5);
    
    float hue = sin(iTime * 0.05 + uv2 * 0.3);                                  
    fragColor = vec4(hsv2rgb(vec3(hue, 1., val)),1.0);
}