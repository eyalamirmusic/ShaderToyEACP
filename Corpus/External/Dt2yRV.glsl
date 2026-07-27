// Dt2yRV - iY0Yi
// https://www.shadertoy.com/view/Dt2yRV
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// Hash without Sine
// MIT License...
// Copyright (c)2014 David Hoskins.
//https://www.shadertoy.com/view/4djSRW
float hash12(vec2 p){
	vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

int getDigits(float f, int digc, int index) {
    // Note: For 32-bit floats, the precision is typically up to about 7 decimal places.
    // Exceeding this may lead to accuracy issues.
    // 1. Multiply the float by a power of 10 to shift the desired digits to the integer part.
    //    This depends on both the desired number of digits (dig) and the offset (id).
    f = f * pow(10., float(digc + index));
    // 2. Convert the float to an integer to discard any fractional part.
    // 3. Return the last 'dig' digits of the integer.
    return int(f) % int(pow(10., float(digc)));
}

bool inRange(float v, float min, float max) {
    return v > min && v < max;
}

bool inRange(int v, int min, int max) {
    return v > min && v < max;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    fragCoord=floor(fragCoord/8.+(iTime*8.));
    
    float f = hash12(fragCoord);
    
    const int ans0 = 123;
    const int ans1 = 456;
    const int ans2 = 789;
    
    int digt = getDigits(f, 3, 1);
    
    if(ans0==digt)
        fragColor = vec4(1,0,0,1);
    else
    if(ans1==digt)
        fragColor = vec4(0,1,0,1);
    else
    if(ans2==digt)
        fragColor = vec4(0,0,1,1);
    else
    if(inRange(digt, ans2-5, ans2+5))
        fragColor = vec4(1,1,0,1);
    else
    fragColor = vec4(f*.0125);
    
    fragColor = pow(fragColor,vec4(.4545));
}