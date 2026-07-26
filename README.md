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

> **⚠️ Early days.** Stages 0 and 1 are done: straight-line GLSL converts, and
> the generated C++ compiles and runs. Loops, branches, helper functions and
> texture channels are still ahead — see the plan and the coverage table below.

## Why this works better than it looks like it should

Three things about Shadertoy line up with eacp's EDSL:

**The shape already matches.** `mainImage(out vec4 fragColor, in vec2 fragCoord)`
is one fragment expression over a fullscreen quad, which is precisely what
`ShaderProgram::setFragment` takes. `Shadertoy::Program` supplies the covering
triangle, the clip-space position and the uniform set, so a port is the body of
`mainImage` and nothing else.

**GLSL locals need no new IR.** eacp's value handles are `{ShaderGraph*, int}`
pairs, so `col = col + x` in GLSL is the identical line of C++ — it just rebinds
the handle to a new graph node. Straight-line shader code translates one for one
today. GLSL helper functions map onto C++ functions over handles, inlined at
record time for free.

**Constant-trip-count loops can be unrolled by the transpiler**, so a large slice
of the corpus is reachable before the EDSL grows control flow at all.
`for (int i = 0; i < 8; i++)` becomes eight recorded copies of the body. This
does not blow up the emitted source: eacp's emitter already promotes any node
used more than once to a named local, so an unrolled 64-step march emits linear
MSL/HLSL rather than a nested expression. fbm, value noise, fixed-iteration
Mandelbrot and fixed-step raymarchers all land inside this.

## What is here now

```
Lib/shadertoy/Glsl/       lexer, parser, AST, diagnostics  (no GPU dependency)
Lib/shadertoy/Emit/       the AST -> C++ EDSL emitter
Lib/shadertoy/Runtime/    Program (the Shadertoy uniform set + fullscreen pass)
                          ShaderView (clock, pointer, resolution, redraw)
Tools/Transpile/          the shadertoy-transpile CLI
Corpus/                   shaders the coverage report is measured against
Apps/Plasma/              a hand port, for comparison
Apps/PlasmaPort/          the same shader, converted from GLSL at build time
Tests/Glsl/               lowering and diagnostics
Tests/Runtime/            vertex layout, uniform block layout, generated stages
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

**Stage 2 — unrolling and inlining.** Constant-trip-count `for` loops unroll;
user-defined functions inline. Large coverage jump for no change to eacp.

**Stage 3 — close the intrinsic gaps**, in the order the coverage table ranks
them. Mechanical work in eacp's `ShaderValue.h`: `atan`/`atan2`, `exp`, `log`,
`tan`, `asin`/`acos`, `mod`, `sign`, `reflect`, `refract`, `inversesqrt`,
`fwidth`, plus `mat2`/`mat3`.

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

Measure the corpus:

```bash
build/Tools/Transpile/shadertoy-transpile --report Corpus/*.glsl
```

## The first coverage table

Over the five shaders in `Corpus/` plus `Apps/PlasmaPort/Plasma.glsl`, as of the
end of stage 1. `Shaders` is the number blocked by that gap, which is what the
roadmap is sorted by:

| Blocker | Shaders | Occurrences |
| --- | ---: | ---: |
| user-function: march | 1 | 2 |
| control-flow: break | 1 | 1 |
| control-flow: for | 1 | 1 |
| control-flow: if | 1 | 1 |
| intrinsic: atan | 1 | 1 |
| intrinsic: exp | 1 | 1 |
| intrinsic: mod | 1 | 1 |
| swizzle: .yx | 1 | 1 |
| texture: texture | 1 | 1 |
| user-function: sdSphere | 1 | 1 |

2 of 5 shaders converted with no gaps.

The corpus is far too small for those counts to rank anything yet — that is what
scaling it up is for. What it does establish is that the measurement works end to
end, including the part that is easy to get wrong: a helper function's body is
skipped, but the loops *inside* it are still counted, so the table does not
promise that inlining alone would turn `Raymarch.glsl` green when it also needs
real control flow.

## The gap ledger

What eacp's EDSL cannot express today, from reading the module — the standing
list the table above is gradually replacing with measured counts.

| Blocker | Where it lives in eacp |
| --- | --- |
| No comparisons, `select`, `if` or loops; no mutable `Var` | `ShaderGraph.h` — `ExprKind` holds expressions only |
| No `int`/`bool`/`ivec`, no `mat2`/`mat3`, no arrays or structs | `ShaderTypes.h` |
| Missing intrinsics: `atan`, `exp`, `log`, `tan`, `asin`, `mod`, `sign`, `reflect`, `refract`, `fwidth` | `ShaderValue.h` |
| A vector built only from literals is rejected — `ComponentsFor` needs one handle to take a graph from, so `vec3(0.0)` has no direct spelling | `ShaderValue.h` |
| Swizzles stop at `x/y/z/w`, `xy` and `xyz`; `.zw` and `.yx` have no accessor, though `ValueHandle::swizzle` underneath is fully general | `ShaderValue.h` |
| No app-facing render-to-texture (`OffscreenTarget` is snapshot-only) | `Frame.h` |
| Texture formats are 8-bit only; no float/half, no mips | `Texture.h` |
| `sample()` is fragment-stage only | `ShaderValue.h` |

## Validation

Ported shaders are checked against reference images rather than eyeballed: render
at a fixed `iTime` into an off-screen target and diff against a golden PNG within
a tolerance. eacp already has the read-back path this rides on (`GPUSnapshotTests`).

This is what catches a port that compiles but is subtly wrong — GLSL `mod` versus
MSL `fmod` on negative operands, integer division, `pow` with a negative base,
and column-major versus row-major matrix construction across the two backends.

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
