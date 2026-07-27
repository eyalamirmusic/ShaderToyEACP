// NdfBDl - jackakers13
// https://www.shadertoy.com/view/NdfBDl
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed cc0-1.0 by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// Created by Jack Akers on February 22, 2022.
// Made available under the CC0 license - https://creativecommons.org/publicdomain/zero/1.0/
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    
    // Spiral
    vec2 center = vec2(iResolution.x/2.0, iResolution.y/2.0);
    float dist = distance(center, fragCoord);
    float angle = atan(fragCoord.y - iResolution.y/2.0, fragCoord.x - iResolution.x/2.0);
    float col = cos(0.25 * dist + angle + 4.0 * iTime);
    
    // Fade
    float distToEdge = distance(center, vec2(iResolution.x/2.0, iResolution.y));
    float percentDistToEdge = clamp(dist / distToEdge, 0.0, 1.0);
    col = mix(0.0, col, 1.0 - percentDistToEdge);
    
    // Return
    fragColor = vec4(vec3(col), 1.0);
    
}