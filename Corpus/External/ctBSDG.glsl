// ctBSDG - Paul_31415
// https://www.shadertoy.com/view/ctBSDG
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org

// Analytical distance to an 2D ellipse, which is more
// complicated than it seems. It ends up being a quartic
// equation, which can be resolved through a cubic, then
// a quadratic. Some steps through the derivation can be
// found in this article: 
//
// https://iquilezles.org/articles/ellipsedist
//
//
// Ellipse distances related shaders:
//
// Analytical     : https://www.shadertoy.com/view/4sS3zz
// Newton Trig    : https://www.shadertoy.com/view/4lsXDN
// Newton No-Trig : https://www.shadertoy.com/view/tttfzr 
// ?????????????? : https://www.shadertoy.com/view/tt3yz7

// List of some other 2D distances: https://www.shadertoy.com/playlist/MXdSRf
//
// and iquilezles.org/articles/distfunctions2d

float msign(in float x) { return (x<0.0)?-1.0:1.0; }





// MIT License
// Copyright © 2023 Paul Soulanille
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

float cbrt(in float x) {
    return sign(x)*pow(abs(x),1.0/3.0);
}
float quart(in float x) {
    x *= x;
    return x*x;
}

// Hyperbola 
//  
// y=1/t       |
// x=t         \__
// rotate 45°  (we do this to be able to change the open angle via x and y scaling)
// x = t-1/t     \_/
// y = t+1/t
// has min Y at 2 and focus at 2√2
//     
//  z,w s.t. |(x,y)-(z,w)| is min
//       https://www.wolframalpha.com/input?i=d%2Fdt+%28%28a*%28t-1%2Ft%29-z%29%5E2%2B%28b*%28t%2B1%2Ft%29-w%29%5E2+%29+
//  (2 a^2 t^4 - 2 a^2 - 2 a t^3 z - 2 a t z + 2 b^2 t^4 - 2 b^2 - 2 b t^3 w + 2 b t w)/t^3 = 0
//  t^4 : 2 a^2 + 2 b^2 
//  t^3 : - 2 a z - 2 b w
//  t^2 : 0
//  t   : - 2 a z + 2 b w
//  1   : - 2 a^2 - 2 b^2
// using: https://en.wikipedia.org/wiki/Quartic_equation#Summary_of_Ferrari's_method
// let r^2 = a^2 + b^2
// coeffs (A…E): 2r^2, -2(ab•zw), 0, -2((a,b)•(z,-w)), -2r^2
//  α = -3/8 (B/A)^2 + C/A
//  β = 1/8 (B/A)^3 - 1/2 BC/A^2 + D/A
//  γ = - 3/256 (B/A)^4 + 1/16 CB^2/A^3 - 1/4 BD/A^2 + E/A
// 
// when β = 0
//  t = -B/4A ± √((-α ± √(α^2-4γ))/2)
// else
//  P = - α^2/12 - γ
//  Q = - α^3/108 + αγ/3 - β^2/8
//  R = - Q/2 ± √((Q/2)^2 + (P/3)^3)
//  U = ∛R
//
//  d = -5/6 α + (U==0? -∛Q : U - P/(3U))
//  W = √(α + 2d)
//  t = -B/4A + 1/2( ±_s W ± √(-(3α + 2d ±_s 2β/W)))
//
//


// currently suffers from precision loss in some areas
//  which can be shown by uncommenting "col = p.x<m.x?ploss: col;" in mainImage
//
vec2 pHyperbola( vec2 p, in vec2 ab){
    
    //vec2 s1 = pHyperbola_sols(p,ab,1.0,1.0);
    //vec2 s2 = pHyperbola_sols(p,ab,-1.0,1.0);
    //vec2 s3 = pHyperbola_sols(p,ab,-1.0,-1.0);
    //vec2 s4 = pHyperbola_sols(p,ab,1.0,-1.0);
    //s1 = (length(s1-p)<length(s2-p))?s1:s2;
    //s2 = (length(s3-p)<length(s4-p))?s3:s4;
    //s1 = (length(s1-p)<length(s2-p))?s1:s2; 
    //return s1;
    float sx = sign(p.x);
    
    float r2 = ab.x*ab.x+ab.y*ab.y;
    float az = ab.x*abs(p.x);
    float bw = ab.y*p.y;
    
    float A = 2.0*r2;
    float B = -2.0*(az+bw);
    float D = -2.0*(az-bw);
    
    
    float boa = B/A;
    float doa = D/A;
    float boa2 = boa*boa;
    
    
    //  α = -3/8 (B/A)^2 + C/A
    float alpha = -0.375 * boa2;
    //  β = 1/8 (B/A)^3 - 1/2 BC/A^2 + D/A
    float beta  = 0.125 * boa2*boa + doa;
    //  γ = - 3/256 (B/A)^4 + 1/16 CB^2/A^3 - 1/4 BD/A^2 + E/A
    float gamma = -3.0/256.0 * (boa2*boa2) - 0.25 * boa*doa - 1.0;
    //          = (-3/256 boa^3 - 1/4 doa)*boa - 1
    //          _     ⎛az+bw⎞4   ⎛az+bw⎞⎛az-bw⎞
    //          ¯  -3 ⎝¯4¯r2⎠  - ⎝¯4¯r2⎠⎝¯r2¯¯⎠ - 1
    //          = 
    //          -(3 x^4)/(256 d^4) - (3 x^3 y)/(64 d^4) - (9 x^2 y^2)/(128 d^4) - (3 x y^3)/(64 d^4) - (3 y^4)/(256 d^4) - x^2/(4 d^2) + y^2/(4 d^2) - 1
    //float gamma = -3.0/256.0 * quart(az / r2) - 3.0*(az
    
    
    // when β = 0
    //  t = -B/4A ± √((-α ± √(α^2-4γ))/2)
    //t = -0.25*boa + s1*sqrt(0.5*(-alpha + s2*sqrt(alpha * alpha - 4.0*gamma)));
    // else
    float alpha2 = alpha * alpha;
    //  P = - α^2/12 - γ
    //float P = - alpha2 / 12.0 - gamma;
    //  P = - (3/8 * boa2)^2/12 - (-3.0/256.0 * (boa2*boa2) - 0.25 * boa*doa - 1.0);
    //    = - 3/256 boa^4 + 3.0/256.0 * (boa2*boa2) + 0.25 * boa*doa + 1.0;
    //    = 0.25 * boa*doa + 1.0;
    float P = 0.25 * boa*doa + 1.0;
    
    //  Q = - α^3/108 + αγ/3 - β^2/8
    float Q = - alpha*(alpha2 / 108.0 - gamma/3.0) - beta*beta / 8.0;
    //  R = - Q/2 ± √((Q/2)^2 + (P/3)^3)
    float R = - Q * 0.5 + sign(-Q)*sqrt(abs(Q*Q*0.25 + P*P*P/27.0));
    //                     ^^^ lowers cancellation error
    
    
    //  U = ∛R
    float U = cbrt(R);
    
    //  d = -5/6 α + (U==0? -∛Q : U - P/(3U))
    float dp56a = (abs(U)<=0.0? -cbrt(Q) : U - P/(3.0*U));
    float d = -5.0/6.0 * alpha + dp56a;
    //  W = √(α + 2d)
    //float W = sqrt(abs(alpha + 2.0 * d));
    //  W = √(α + -5/3 α + (U==0? -2∛Q : 2U - 2P/(3U))
    //    = √(-2/3 α + )
    float W = sqrt(abs(-2.0/3.0 * alpha + 2.0 * dp56a));
    //  W = √(-2/3 α + (U==0? -∛Q : U - P/(3U))
    // case U==0
    //  W = √(-2/3 α -∛Q)
    //    = √(-2/3 α -∛(- α^3/108 + αγ/3 - β^2/8))
    // case U!=0
    //  W = √(-2/3 α + U + (α^2/12 + γ)/(3U))
    //    = √(-2/3 α + U - P/(3U))
    //  W = √(-2/3 α + ∛R - P/(3∛R))
    
    
    //  t = -B/4A + 1/2( ±_s W ± √(-(3α + 2d ±_s 2β/W)))
    //float t1 = -boa*0.25 + 0.5 * (W + sqrt(abs(3.0*alpha + 2.0*d + 2.0*beta/W)));
    //float t2 = -boa*0.25 + 0.5 * (-W + sqrt(abs(3.0*alpha + 2.0*d + -2.0*beta/W)));
    //        3α + 2d = 3α + 2(-5/6 α  + dp56a)
    //                = (3-5/3) α  + 2 dp56a
    //                =  4/3 α  + 2 dp56a
    float t1 = -boa*0.25 + 0.5 * (W + sqrt(abs(4.0/3.0*alpha + 2.0*dp56a + 2.0*beta/W)));
    float t2 = -boa*0.25 + 0.5 * (-W + sqrt(abs(4.0/3.0*alpha + 2.0*dp56a + -2.0*beta/W)));
    
    float recip_t1 = 1.0/t1;
    float recip_t2 = 1.0/t2;
    vec2 p1 = vec2((t1-recip_t1)*sx,t1+recip_t1)*ab;
    vec2 p2 = vec2((t2-recip_t2)*sx,t2+recip_t2)*ab;
    return (length(p1-p)<length(p2-p) && p1.y>=0.0) || p2.y < 0.0?p1:p2;
    
}

//using the "locus of points" geometric defn of hyperbola
float inside_Hyperbola( vec2 p, in vec2 ab){
    float sqrt2 = sqrt(2.0);//foci are at (0,±√2)
    p /= ab;
    p /= 2.0;
    return sign(length(p-vec2(0,sqrt2))-length(p-vec2(0,-sqrt2))+2.0);
}


//precision loss testing
float add_ploss(in float a, in float b){
    return -log2(abs(a+b)/(abs(a)+abs(b)))/24.0;
}
vec3 pHyperbola_loss( vec2 p, in vec2 ab)
{
    
                                                                                                  
    float loss1 = 0.0;
    float loss2 = 0.0;
    float loss3 = 0.0;
    
    float sx = sign(p.x);
    
    float r2 = ab.x*ab.x+ab.y*ab.y;
    float az = ab.x*abs(p.x);
    float bw = ab.y*p.y;
    
    float A = 2.0*r2;
    float B = -2.0*(az+bw);
    float D = -2.0*(az-bw);
    
    
    float boa = B/A;
    float doa = D/A;
    float boa2 = boa*boa;
    
    
    //  α = -3/8 (B/A)^2 + C/A
    float alpha = -0.375 * boa2;
    //  β = 1/8 (B/A)^3 - 1/2 BC/A^2 + D/A
    float beta  = 0.125 * boa2*boa + doa;
    //loss3 = add_ploss(0.125 * boa2*boa, doa);
    //  γ = - 3/256 (B/A)^4 + 1/16 CB^2/A^3 - 1/4 BD/A^2 + E/A
    float gamma = -3.0/256.0 * (boa2*boa2) - 0.25 * boa*doa - 1.0;
    //loss3 = add_ploss(-3.0/256.0 * (boa2*boa2) ,- 0.25 * boa*doa-1.0);
    loss3 = add_ploss(-3.0/256.0 * (boa2*boa2) - 0.25 * boa*doa,-1.0);
    // when β = 0
    //  t = -B/4A ± √((-α ± √(α^2-4γ))/2)
    //t = -0.25*boa + s1*sqrt(0.5*(-alpha + s2*sqrt(alpha * alpha - 4.0*gamma)));
    // else
    float alpha2 = alpha * alpha;
    //  P = - α^2/12 - γ
    float P = - alpha2 / 12.0 - gamma;
    loss1 = add_ploss(alpha2 / 12.0,gamma);
    //  Q = - α^3/108 + αγ/3 - β^2/8
    float Q = - alpha*(alpha2 / 108.0 - gamma/3.0) - beta*beta / 8.0;
    //loss3 = add_ploss(alpha2 / 108.0, - gamma/3.0);
    //loss3 = add_ploss(- alpha*(alpha2 / 108.0 - gamma/3.0),- beta*beta / 8.0); 
    //  R = - Q/2 ± √((Q/2)^2 + (P/3)^3)
    float R = - Q * 0.5 + sign(-Q)*sqrt(abs(Q*Q*0.25 + P*P*P/27.0));
    //loss3 = add_ploss(Q*Q*0.25,P*P*P/27.0);
    //loss3 = add_ploss(- Q * 0.5,sqrt(abs(Q*Q*0.25 + P*P*P/27.0))); //lines up with P in upper half, fixed
    //  U = ∛R
    float U = cbrt(R);
    
    //  d = -5/6 α + (U==0? -∛Q : U - P/(3U))
    float d = -5.0/6.0 * alpha + (abs(U)<=0.0? -cbrt(Q) : U - P/(3.0*U));
    //loss3 = add_ploss(-5.0/6.0 * alpha, (abs(U)<=0.0? -cbrt(Q) : U - P/(3.0*U))); //not here
    //loss3 = add_ploss(U, - P/(3.0*U));// not here
    //  W = √(α + 2d)
    //float W = sqrt(abs(alpha + 2.0 * d));
    //loss2 = add_ploss(alpha,2.0*d);
    float W = sqrt(abs(-2.0/3.0 * alpha + 2.0 * (abs(U)<=0.0? -cbrt(Q) : U - P/(3.0*U))));
    loss2 = add_ploss(-2.0/3.0 * alpha,2.0*(abs(U)<=0.0? -cbrt(Q) : U - P/(3.0*U)));
    //  t = -B/4A + 1/2( ±_s W ± √(-(3α + 2d ±_s 2β/W)))
    //  W = √(-2/3 α + (U==0? -∛Q : U - P/(3U))
    // case U==0
    //  W = √(-2/3 α -∛Q)
    //    = √(-2/3 α -∛(- α^3/108 + αγ/3 - β^2/8))
    // case U!=0
    //  W = √(-2/3 α + U + (α^2/12 + γ)/(3U))
    //    = √(-2/3 α + U - P/(3U))
    //  W = √(-2/3 α + ∛R - P/(3∛R))
    //loss3 = add_ploss(-2.0/3.0 *alpha, + U);
    
    float t1 = -boa*0.25 + 0.5 * (W + sqrt(abs(3.0*alpha + 2.0*d + 2.0*beta/W)));
    //loss3 = add_ploss(-boa*0.25,0.5*(W+sqrt(abs(3.0*alpha + 2.0*d + 2.0*beta/W))));
    float t2 = -boa*0.25 + 0.5 * (-W + sqrt(abs(3.0*alpha + 2.0*d + -2.0*beta/W)));
    //loss3 = add_ploss(-boa*0.25,0.5*(-W+sqrt(abs(3.0*alpha + 2.0*d - 2.0*beta/W))));
    
    
    float recip_t1 = 1.0/t1;
    float recip_t2 = 1.0/t2;
    vec2 p1 = vec2((t1-recip_t1)*sx,t1+recip_t1)*ab;
    vec2 p2 = vec2((t2-recip_t2)*sx,t2+recip_t2)*ab;
    vec2 result = (length(p1-p)<length(p2-p) && p1.y>=0.0) || p2.y < 0.0?p1:p2;
    
    
    return vec3(loss1,loss2,loss3);
    
}


//for highlighting individual solutions
vec2 pHyperbola_sols( vec2 p, in vec2 ab, in float s1, in float s2 )
{
    float t = 0.0;
    
    float r2 = ab.x*ab.x+ab.y*ab.y;
    float az = ab.x*p.x;
    float bw = ab.y*p.y;
    
    float A = 2.0*r2;
    float B = -2.0*(az+bw);
    float C = 0.0;
    float D = -2.0*(az-bw);
    float E = -2.0*r2;
    
    
    float boa = B/A;
    float coa = C/A;
    float doa = D/A;
    float eoa = E/A;
    float boa2 = boa*boa;
    
    
    //  α = -3/8 (B/A)^2 + C/A
    float alpha = -0.375 * boa2 + coa;
    //  β = 1/8 (B/A)^3 - 1/2 BC/A^2 + D/A
    float beta  = 0.125 * boa2*boa - 0.5*boa*coa + doa;
    //  γ = - 3/256 (B/A)^4 + 1/16 CB^2/A^3 - 1/4 BD/A^2 + E/A
    float gamma = -3.0/256.0 * (boa2*boa2) + 0.0625 * coa*boa2 - 0.25 * boa*doa + eoa;
    // when β = 0
    //  t = -B/4A ± √((-α ± √(α^2-4γ))/2)
    //t = -0.25*boa + s1*sqrt(0.5*(-alpha + s2*sqrt(alpha * alpha - 4.0*gamma)));
    // else
    float alpha2 = alpha * alpha;
    //  P = - α^2/12 - γ
    float P = - alpha2 / 12.0 - gamma;
    //  Q = - α^3/108 + αγ/3 - β^2/8
    float Q = - alpha*(alpha2 / 108.0 - gamma/3.0) - beta*beta / 8.0;
    //  R = - Q/2 ± √((Q/2)^2 + (P/3)^3)
    float R = - Q * 0.5 + sign(-Q)*sqrt(abs(Q*Q*0.25 + P*P*P/27.0));
    //  U = ∛R
    float U = cbrt(R);
    
    //  d = -5/6 α + (U==0? -∛Q : U - P/(3U))
    float d = -5.0/6.0 * alpha + (U==0.0? -cbrt(Q) : U - P/(3.0*U));
    //  W = √(α + 2d)
    float W = sqrt(alpha + 2.0 * d);
    //  t = -B/4A + 1/2( ±_s W ± √(-(3α + 2d ±_s 2β/W)))
    t = -boa*0.25 + 0.5 * (s1*W + s2*sqrt(abs(3.0*alpha + 2.0*d + s1*2.0*beta/W)));
    
    float recip_t = 1.0/t;
    return vec2(t-recip_t,t+recip_t)*ab;
}







void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
	vec2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    vec2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;

    vec2 ra = (vec2(0.25,0.25) + 0.25*cos(iTime*vec2(1.1,1.3)+vec2(1.0,1.0) ))*0.25*(1.0625-sin(iTime));
	
 	vec2 pd = pHyperbola( p, ra);
    float d = length(pd-p)*inside_Hyperbola(p,ra);
    
    vec3 col = vec3(1.0) - sign(d)*vec3(0.1,0.4,0.7);
	col *= 1.0 - exp(-2.0*abs(d));
	col *= 0.8 + 0.2*cos(120.0*d);
	col = mix( col, vec3(1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );
    
    vec3 ploss = pHyperbola_loss(p,ra);
    //uncomment the next line to see a map of floating point precision loss on the solution
    col = p.x<m.x?ploss: col;
    
    
    if( iMouse.z>0.001 )
    {
    pd = pHyperbola(m, ra);
    d = length(pd-m);
    col = mix(col, vec3(1.0,1.0,1.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0030));
    col = mix(col, vec3(1.0,1.0,1.0), 1.0-smoothstep(0.0, 0.005, length(p-pd)-0.030));
    
    pd = pHyperbola_sols(m, ra,1.0,1.0);
    d = length(pd-m);
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-pd)-0.025));
    
    pd = pHyperbola_sols(m, ra,-1.0,1.0);
    d = length(pd-m);
    col = mix(col, vec3(1.0,0.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0020));
    col = mix(col, vec3(1.0,0.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-pd)-0.020));
    
    pd = pHyperbola_sols(m, ra,1.0,-1.0);
    d = length(pd-m);
    col = mix(col, vec3(0.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0015));
    col = mix(col, vec3(0.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-pd)-0.015));
    
    pd = pHyperbola_sols(m, ra,-1.0,-1.0);
    d = length(pd-m);
    col = mix(col, vec3(0.0,0.0,1.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0010));
    col = mix(col, vec3(0.0,0.0,1.0), 1.0-smoothstep(0.0, 0.005, length(p-pd)-0.010));
    
    col = mix(col, vec3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }

	fragColor = vec4( col, 1.0 );;
}