# ShaderToyEACP

Turning Shadertoy's GLSL into [eacp](https://github.com/eyalamirmusic/eacp) GPU
programs — shaders authored as C++ structs, compiled to Metal and HLSL from one
source, with no shader strings anywhere.

The ported shaders are the visible half. The point of the project is the other
half: Shadertoy is a corpus of thousands of real, demanding fragment shaders,
and running it through eacp's shader EDSL turns "what is the EDSL missing?" from
a matter of opinion into a measurement. Every shader that fails to convert names
a specific gap, and the number of shaders blocked on each gap is what decides
which one to close next.

> **⚠️ Early days.** Stages 0 to 3 are done: straight-line GLSL converts,
> constant-trip-count loops unroll, helper functions inline, the intrinsic and
> swizzle gaps are closed, and the generated C++ compiles and runs. Branches,
> texture channels and data-dependent loops are still ahead — see the plan and
> the coverage table below.

## Why this works better than it looks like it should

Three things about Shadertoy line up with eacp's EDSL:

**The shape already matches.** `mainImage(out vec4 fragColor, in vec2 fragCoord)`
is one fragment expression over a fullscreen quad, which is precisely what
`ShaderProgram::setFragment` takes. `Shadertoy::Program` supplies the covering
triangle, the clip-space position and the uniform set, so a port is the body of
`mainImage` and nothing else.

**GLSL locals need no new IR.** eacp's value handles are `{ShaderGraph*, int}`
pairs, so `col = col + x` in GLSL is the identical line of C++ — it just rebinds
the handle to a new graph node. Straight-line shader code translates one for one.
A GLSL helper costs nothing either: a C++ function over handles records its body
inline wherever it is called, so the transpiler can substitute the body at the
source level and a port holds no functions of its own however many the shader
was written with.

**Constant-trip-count loops are unrolled by the transpiler**, so a large slice of
the corpus is reachable before the EDSL grows control flow at all.
`for (int i = 0; i < 8; i++)` becomes eight recorded copies of the body. This
does not blow up the emitted source: eacp's emitter already promotes any node
used more than once to a named local, so an unrolled 64-step march emits linear
MSL/HLSL rather than a nested expression. fbm, value noise, fixed-iteration
Mandelbrot and fixed-step raymarchers all land inside this.

## What is here now

```
Lib/shadertoy/Glsl/       lexer, parser, AST, diagnostics  (no GPU dependency)
                          Lower (unrolling, inlining, constant folding)
Lib/shadertoy/Emit/       the AST -> C++ EDSL emitter
Lib/shadertoy/Runtime/    Program (the Shadertoy uniform set + fullscreen pass)
                          ShaderView (clock, pointer, resolution, redraw)
Tools/Transpile/          the shadertoy-transpile CLI
Corpus/                   shaders the coverage report is measured against
Apps/Plasma/              a hand port, for comparison
Apps/PlasmaPort/          the same shader, converted from GLSL at build time
Tests/Glsl/               lowering and diagnostics
Tests/Runtime/            vertex layout, uniform block layout, generated stages,
                          and corpus ports compiled from their GLSL by the build
```

A port looks like this — hand-written or generated, the shape is the same:

```cpp
struct PlasmaShader final : Shadertoy::Program
{
    PlasmaShader() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        auto resolution = iResolution.xy();
        auto uv = (fragCoord - resolution * 0.5f) / resolution.y();

        auto waves = sin(uv.x() * 8.0f + iTime) + sin(uv.y() * 8.0f + iTime * 1.3f);
        auto color = 0.5f + 0.5f * cos(float3(waves, waves + 2.1f, waves + 4.2f));

        return float4(color, 1.0f);
    }
};
```

`fragCoord` arrives in pixels with the origin at the bottom-left, exactly as
Shadertoy hands it over. Two deviations from the real uniform set, both because
the EDSL has no integer type usable in float arithmetic yet: `iFrame` is a float,
and `iDate` is absent. Texture channels arrive with stage 4.

## The plan

Each stage is independently useful, and each one ends by producing a coverage
report over a fixed corpus rather than a subjective sense of progress.

**Stage 0 — runtime substrate.** *Done.* `Program`, `ShaderView`, the fullscreen
triangle, the uniform set, and a hand port proving the path end to end.

**Stage 1 — straight-line transpiler.** *Done.* A hand-written recursive-descent
parser over the GLSL subset Shadertoy uses, lowering to a readable `mainImage`
body: locals, arithmetic, swizzles, vector constructors, compound assignment,
object-like `#define`s, and the seventeen builtins the EDSL already spells. Every
construct it cannot express becomes a structured diagnostic, and those aggregate
into the coverage table below.

Deliberately *not* routed through glslang or SPIRV-Cross: SPIR-V is already
lowered to a control-flow graph with phi nodes, which is the wrong shape to
re-emit as structured C++ — that would be decompiling. It also keeps the
dependency footprint at zero, matching eacp.

The parser accepts more than the emitter can lower, on purpose. Rejecting `if`
at the parser would collapse every such shader into one useless "syntax error"
instead of the list of capabilities it actually needs — and an unsupported
construct is skipped rather than fatal, so one shader reports every wall it hits
rather than the first.

**Stage 2 — unrolling and inlining.** *Done.* A `for` whose trip count the
transpiler can work out becomes that many copies of its body, with the counter
substituted as a literal — which is also what keeps `int` off the gap list,
since after unrolling there is no integer left to express. A call to a helper
becomes the helper's body, arguments and all, including helpers that call
helpers and helpers that write back through an `inout` parameter. Flattening
puts every local in one C++ scope, so a name declared inside a body is renamed
per copy.

`Lib/shadertoy/Glsl/Lower.cpp` is where both happen, between the parser and the
emitter, and it is the only place that knows what a loop or a helper *was*: what
will not flatten is reported there and expanded once into a list the emitter
walks for diagnostics and then throws away. That is what stops one loop the
transpiler cannot count from hiding every intrinsic inside it.

It found the first eacp gap the corpus paid for, too — see below.

**Stage 3 — close the intrinsic gaps.** *Done.* The whole set, in eacp's
`ShaderValue.h`: `tan`, `asin`, `acos`, `atan`/`atan2`, `exp`, `exp2`, `log`,
`log2`, `rsqrt`, `sign`, `ceil`, `round`, `trunc`, `mod`, `distance`, `reflect`,
`refract`, `faceforward`, `dfdx`, `dfdy`, `fwidth` — plus every swizzle and
`mat2`/`mat3`.

Three of those turned out not to be mechanical at all, which is the return on
measuring rather than guessing — see below.

**Stage 4 — texture channels.** `iChannel0..3`, `texelFetch`, `textureLod`.

**Stage 5 — real control flow.** `Var`, `Select`, `If`, `While` in eacp's shader
IR, driven by the shaders unrolling cannot reach: `break`-on-hit raymarchers,
dynamic bounds, `while`. This is the stage that turns the EDSL from an
expression tree into a language, and it is the largest single payoff to eacp.

**Stage 6 — multi-buffer Shadertoys.** Buffer A–D with feedback, which needs
render-to-texture and float texture formats in eacp.

## Using it

Convert one shader:

```bash
build/Tools/Transpile/shadertoy-transpile Corpus/Gradient.glsl -o Gradient.h
```

It writes nothing and exits non-zero if the shader hit a gap, so a port never
silently drops something it could not express. `--force` overrides that while a
gap is being worked on.

Or let the build do it, which is how `Apps/PlasmaPort` works — a `.glsl` in, a
struct out, no C++ written by hand:

```cmake
shadertoy_add_port(PlasmaPort GLSL Plasma.glsl NAME Plasma)
```

```cpp
#include <Plasma.h>
Shadertoy::Ports::Plasma shader;   // ready to hand to a ShaderView
```

Measure the corpus — this is the exact command the table below comes from:

```bash
build/Tools/Transpile/shadertoy-transpile --report Corpus/*.glsl \
    Apps/PlasmaPort/Plasma.glsl
```

## The coverage table

Over the seven shaders in `Corpus/` plus `Apps/PlasmaPort/Plasma.glsl`, as of
the end of stage 3. `Shaders` is the number blocked by that gap, which is what
the roadmap is sorted by:

| Blocker | Shaders | Occurrences |
| --- | ---: | ---: |
| control-flow: break | 1 | 1 |
| control-flow: if | 1 | 1 |
| control-flow: for | 1 | 1 |
| texture: texture | 1 | 1 |
| user-function: march | 1 | 1 |

6 of 8 shaders converted with no gaps.

Every intrinsic and swizzle row is gone, and what is left is two shaders and two
stages: `Tunnel.glsl` wants a texture channel (stage 4), and `Raymarch.glsl`
wants real control flow (stage 5) — the `user-function: march` row is that same
`break` seen from outside, a helper the port had to leave as a call because the
loop in it cannot be unrolled.

`Kaleido.glsl` was added with stage 3 and is the shader that measures it: a
`mat2` rotation built inline, polar coordinates through the two-argument `atan`,
`mod` tiling, `exp` falloff, `inversesqrt` and `sign` in the shaping, and
swizzles of every width up to `.wzyx`. It converts with nothing left over, which
is a claim only worth making because `Tests/Runtime` then compiles it.

The corpus is still far too small for these counts to rank anything. What it
establishes is that the measurement works end to end — and stage 3 is the first
time it paid for itself, by turning three assumptions into bugs before they
shipped.

## What this has already changed in eacp

The point of the exercise, so it is worth recording what it has found.

**Scalar broadcast for `+` and `-`** (stage 2). Every shader that sums an offset
into a coordinate — `uv + iTime`, `p - speed` — failed to compile once loops
unrolled, and not for any reason the transpiler could see: it emitted exactly
what the source said. eacp broadcast a scalar *handle* across a vector for `*`
and `/` but not for `+` or `-`, and had no `scalar / vector` at all, so
`uv * iTime` compiled and `uv + iTime` did not. Both shading languages the EDSL
emits into broadcast all four.

Closed in `ShaderValue.h`, with a codegen test that pins the operand order for
the two that do not commute. It was found by `Corpus/Fbm.glsl` failing to build
in `Tests/Runtime`, which is why the corpus ports are compiled there rather than
only transpiled: a header the transpiler reports no gaps in can still be one the
EDSL will not take, and the only thing that catches that is a compiler.

**`mod` is not `fmod`** (stage 3). The obvious way to add GLSL's `mod` is a call
node named `fmod`, which is what both backends offer. It is also wrong: `fmod`
truncates, `mod` floors, and they disagree on exactly the inputs a shader cares
about — `mod(-0.25, 1.0)` is `0.75` in GLSL and `-0.25` in MSL, so every tile
left of the origin in a tiling shader comes out mirrored. eacp records it as
`x - y * floor(x / y)` instead, built from nodes both languages already agree
on, which makes the two backends bit-identical rather than merely both plausible.

**A swizzle has to be one node** (stage 3). `.yx` and `.zw` had no accessor, and
the cheap fix is for the transpiler to rebuild them as constructors —
`float4(v.z(), v.y(), v.x(), v.w())` for `.zyxw`. That is correct and it is
also a trap: it records the subtree behind `v` four times, and eacp's emitter
dedups by node identity rather than by structure, so the *shader* evaluates it
four times too. `Corpus/Kaleido.glsl` made this visible as a 204-column line in
the generated port. eacp now has all 340 orderings of one to four components,
generated by macro and constrained to the widths that can spell them, so a
swizzle stays one `Swizzle` node however it is written.

**`mat2` and `mat3` cannot cross from the CPU** (stage 3). They were added as
shader-local values — the inline rotation, the tangent basis — and deliberately
refused as uniforms: MSL packs a `float2x2` as two `float2` columns, 16 bytes,
while an HLSL cbuffer gives every matrix row a register of its own and takes 32.
That is a disagreement *inside* the value, which the uniform block's pad scalars
cannot correct. `float4x4`, which both languages agree on, stays the matrix to
send. `ShaderBuilder::uniform<T>()` static_asserts this rather than leaving it
to a comment.

Stage 3 also found a bug on this side of the fence rather than in eacp: the
emitter's line-wrapping path rebuilt a call's head from the *GLSL* name, so a
wrapped `inversesqrt` came back as `inversesqrt` instead of `rsqrt`. It had
never mattered while every supported builtin was spelled the same in both
languages. `Glsl/wrappedCallsKeepEdslName` pins it.

## The gap ledger

What eacp's EDSL cannot express today, from reading the module — the standing
list the table above is gradually replacing with measured counts.

| Blocker | Where it lives in eacp |
| --- | --- |
| No comparisons, `select`, `if` or loops; no mutable `Var` | `ShaderGraph.h` — `ExprKind` holds expressions only |
| No `int`/`bool`/`ivec`, no arrays or structs | `ShaderTypes.h` |
| No `transpose`, `inverse` or `determinant` — a matrix can be built and multiplied, and that is where `Float2x2`/`Float3x3` stop | `ShaderValue.h` |
| `Float2x2`/`Float3x3` cannot be uniforms: MSL and HLSL pack them to different sizes, which no padding between fields can bridge. `Float4x4` is unaffected | `UniformLayout.h` |
| A vector built only from literals is rejected — `ComponentsFor` needs one handle to take a graph from, so `vec3(0.0)` has no direct spelling. A scalar has the same problem: `float d = 2.0` is a C++ float rather than a value, and ports anchor both with `constant()` | `ShaderValue.h` |
| No app-facing render-to-texture (`OffscreenTarget` is snapshot-only) | `Frame.h` |
| Texture formats are 8-bit only; no float/half, no mips | `Texture.h` |
| `sample()` is fragment-stage only, as are `dfdx`/`dfdy`/`fwidth` | `ShaderValue.h` |

Closed by stage 3: the intrinsic row (all twenty-one of them), the swizzle row
(`.zw` and `.yx` were the measured cases; all 340 orderings are there now), and
`mat2`/`mat3` as expression types.

## Validation

Three layers, because they catch different things.

**The report.** A shader either names what it needs or it does not — the counts
in the table above.

**The compiler.** `Tests/Runtime` transpiles corpus shaders at build time and
instantiates the ports, so a header that reports no gaps but that the EDSL will
not take is a failing build rather than a clean report. This is what found the
missing scalar broadcast above.

**Reference images.** *Ahead.* Render at a fixed `iTime` into an off-screen
target and diff against a golden PNG within a tolerance; eacp already has the
read-back path this rides on (`GPUSnapshotTests`). This is the layer that catches
a port that compiles but is subtly wrong — integer division, `pow` with a
negative base, `round` on an exact half, and whether a `mat2` really came out
column-major on both backends.

Two of the traps this layer was meant to catch are closed by construction
instead, which is the better place for them: `mod` is recorded as its floored
form rather than as a call either backend would truncate, and a matrix
construction is transposed on HLSL so both backends read the same columns. Both
are pinned by codegen tests in eacp rather than by an image.

## Building

```bash
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug -DSHADERTOY_UNITY_BUILD=OFF
cmake --build build
```

eacp is fetched with CPM from `eyalamirmusic/eacp@main`. To build against a local
checkout while co-developing both:

```bash
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug -DSHADERTOY_UNITY_BUILD=OFF \
      -DCPM_eacp_SOURCE=$HOME/Code/eacp
```

Use `$HOME`, not `~` — CMake does not expand a tilde, and it configures against a
non-existent path instead of failing.

Outputs:

- `build/Tools/Transpile/shadertoy-transpile` — the converter
- `build/Apps/Plasma/Plasma.app` — the hand port
- `build/Apps/PlasmaPort/PlasmaPort.app` — the same shader, transpiled
- `build/Tests/Glsl/GlslTests`, `build/Tests/Runtime/RuntimeTests`

## On licensing the corpus

Shadertoy's default licence is CC BY-NC-SA 3.0 unless an author states otherwise,
and the non-commercial clause makes redistribution a real question rather than a
formality. The corpus is therefore fetched on demand from a list of IDs rather
than vendored, and only ports of self-authored or explicitly permissive shaders
are committed here.
