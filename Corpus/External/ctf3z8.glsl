// ctf3z8 - ttg
// https://www.shadertoy.com/view/ctf3z8
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed isc by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

/*

24-bit fixed * 12-mantissa-bit multiply
https://www.shadertoy.com/view/ctf3z8

Multiply 24-bit signed integer by float using 12 bits of mantissa into
whole part and fract part without loss of precision over the integer argument's
range.
Click left/right to compare one at a time.

Copyright 2022 Theron Tarigo.  All rights reserved.
This file may be used and copied under the terms of the ISC License;
see end of file.

*/

// https://www.shadertoy.com/view/ctf3z8
// requires abs(a) < (1<<24), recognizes only 12 significand bits of b
// logical operation: returns fract(a*b+x), ret_n=floor(a*b+x)
float frac_mad_i24_m12_f32 (out int ret_n, int a, float b, float x) {
#ifdef SAFE
  int _M=~0xFFF;
  if (a!=(a&0xFFFFFF)) return 0.;
  b = intBitsToFloat(floatBitsToInt(b)&_M);
#endif
  vec2 p = vec2(a&0xFFF,a&~0xFFF)*b,i=floor(p),f=p-i,r=f+f.y+x;
  ret_n = int(i.x+i.y+(r.y=floor(r.x)));
  return r.x-r.y;
}

void mainImage (out vec4 O, vec2 f) {
  vec2 uv = f/iResolution.xy;
  float yplt=fract(uv.y*2.);
  int i=int(floor(uv.x*160.))+0x1000000; // index
  float b=intBitsToFloat(0x3da3d000); // frequency = 7.9986572e-02
  float x=.2; // phase shift
  
  float Af,Bf;
  int Ai,Bi;
  
  // mad f32 result (imprecise)
  Af=fract(float(i)*b+x);
  Ai=int(floor(float(i)*b+x));
  
  // frac_mad_i24_m12_f32 result
  Bf=frac_mad_i24_m12_f32(Bi,i,b,x);
  
  vec3 col=vec3(0.);
  if(uv.y>.5){
    col.r=float(yplt<Af);
    col.g=float(yplt<Bf);
  }
  else{
    int shift=1341950;
    int range=20;
    col.r=float(yplt<float(Ai-shift)/float(range));
    col.g=float(yplt<float(Bi-shift)/float(range));
  }
  if(iMouse.z>0.){
    float m=iMouse.x/iResolution.x;
    if(m<.5)col=vec3(col.r);
    else col=vec3(col.g);
  }
  
  // sRGB output https://www.shadertoy.com/view/sl3cRs
  {vec3 c=col;O.rgb=min(12.9*c,abs(1.054*pow(c,c-c+.4166)-.095)+.04);}
}

/*
Copyright 2022 Theron Tarigo

Permission to use, copy, modify, and/or distribute this software for any 
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH 
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
*/
