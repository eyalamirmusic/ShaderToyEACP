// Dtf3Dl - iq
// https://www.shadertoy.com/view/Dtf3Dl
//
// From Vipitis/Shadereval-inputs, the corpus the coverage tables are
// measured over. Licensed mit by its author,
// which is the line that decides whether a shader may be
// committed to this repository or only measured in it - see
// .licences beside this file for the whole directory.

// The MIT License
// Copyright © 2023 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// The shader I used while designing the Human Shader experiment
//
// https://humanshader.com

int shift( int x, int n )
{
    if( n==1 ) { return (x+5)/10; }
    if( n==2 ) { return (x+50)/100; }
    if( n==3 ) { return (x+500)/1000; }
                 return (x+5000)/10000;
}

// Cost: (6/14 MUL  6/13 ADD)
vec3 compute( int x, int y )
{
    int R, B;

    //-------------------------    
    // Section A (2 MUL, 3 ADD)
    //-------------------------    
    int u = x-36;
    int v = 18-y;
    int u2 = u*u;
    int v2 = v*v;
    int h = u2 + v2;
    //-------------------------  
    
    if( h < 200 ) 
    {
        //-------------------------------------
        // Section B, Sphere (4/7 MUL, 5/9 ADD)
        //-------------------------------------
        R = 420;
        B = 520;

        int t = 5000 + h*8;
        int p = shift(t*u,2);
        int q = shift(t*v,2);
        int s = 2*q;
        
        // bounce light
        int w = 18 + shift(p - s,2);
        if( w>0 ) R += w*w;
        
        // sky light / ambient occlusion
        int o = s + 2200;
        R = shift(R*o,4);
        B = shift(B*o,4);

        // sun/key light
        if( p > -q )
        {
            int w = shift(p+q,1);
            R += w;
            B += w;
        }
        //-------------------------  
	}
    else if( v<0 )
    {
        //-------------------------------------
        // Section C, Ground (5/9 MUL, 6/9 ADD)
        //-------------------------------------
        R = 150 + 2*v;
        B = 50;
        
        int p = h + 8*v2;
        int c = 240*(-v) - p;

        // sky light / ambient occlusion
        if( c>1200 )
        {
            int o = shift(6*c,1);
            o = shift(c*(1500-o),2) - 8360;
            R = shift(R*o,3);
            B = shift(B*o,3);
        }

        // sun/key light with soft shadow
        int r = c + u*v;
        int d = 3200 - h - 2*r;
        if( d>0 ) R += d;
        //-------------------------  
    }
    else
    {
        //------------------------------
        // Section D, Sky (1 MUL, 2 ADD)
        //------------------------------
        int c = x + 4*y;
        R = 132 + c;
        B = 192 + c;
        //-------------------------  
    }
    
    //-------------------------
    // Section E (3 MUL, 1 ADD)
    //-------------------------
    R = min(R,255);
    B = min(B,255);
    
    int G = shift(R*7 + 3*B,1);
    //-------------------------  

    return vec3(R,G,B);
}
    
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    const vec2 resolution = vec2(71,40);

    ivec2 ij = ivec2(floor(resolution*fragCoord/iResolution.xy));
    
    vec3 col = compute( ij.x, 39-ij.y );
    
    // draw grid lines
    {
    ivec2 ijp = ivec2(floor(resolution*(fragCoord-vec2(1,1))/iResolution.xy));
    ivec2 ijn = ivec2(floor(resolution*(fragCoord+vec2(1,1))/iResolution.xy));
    if( ijn.x!=ij.x || ijn.y!=ij.y || ijp.x!=ij.x || ijp.y!=ij.y) col*=0.75;
    }
    
    fragColor = vec4( col/255.0, 1.0 );
}