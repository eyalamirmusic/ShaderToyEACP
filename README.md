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

> **⚠️ Early days.** Only the runtime substrate exists so far — the fullscreen
> pass, the Shadertoy uniform set, and one hand-written port that proves the
> path. The transpiler itself is stage 1 of the plan below.

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
Lib/shadertoy/Runtime/    Program (the Shadertoy uniform set + fullscreen pass)
                          ShaderView (clock, pointer, resolution, redraw)
Apps/Plasma/              a hand port, in the shape the transpiler will emit
Tests/Runtime/            vertex layout, uniform block layout, generated stages
```

A port looks like this, and this is the target output format for generated code:

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

**Stage 1 — straight-line transpiler.** A hand-written recursive-descent parser
over the narrow GLSL ES subset Shadertoy uses, lowering to a readable
`mainImage` body. No loops, no branches. Emits a structured diagnostic for every
construct it cannot express, and aggregates those into the first coverage table.

Deliberately *not* routed through glslang or SPIRV-Cross: SPIR-V is already
lowered to a control-flow graph with phi nodes, which is the wrong shape to
re-emit as structured C++ — that would be decompiling. It also keeps the
dependency footprint at zero, matching eacp.

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

## The gap ledger

What eacp's EDSL cannot express today, from reading the module. Stage 1's
diagnostics will replace this hand-written list with a measured one, ranked by
how many corpus shaders each blocks.

| Blocker | Where it lives in eacp |
| --- | --- |
| No comparisons, `select`, `if` or loops; no mutable `Var` | `ShaderGraph.h` — `ExprKind` holds expressions only |
| No `int`/`bool`/`ivec`, no `mat2`/`mat3`, no arrays or structs | `ShaderTypes.h` |
| Missing intrinsics: `atan`, `exp`, `log`, `tan`, `asin`, `mod`, `sign`, `reflect`, `refract`, `fwidth` | `ShaderValue.h` |
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

- `build/Apps/Plasma/Plasma.app`
- `build/Tests/Runtime/RuntimeTests`

## On licensing the corpus

Shadertoy's default licence is CC BY-NC-SA 3.0 unless an author states otherwise,
and the non-commercial clause makes redistribution a real question rather than a
formality. The corpus is therefore fetched on demand from a list of IDs rather
than vendored, and only ports of self-authored or explicitly permissive shaders
are committed here.
