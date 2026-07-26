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

> **⚠️ Early days.** Stages 0 to 7 are done: straight-line GLSL converts,
> constant-trip-count loops unroll, helper functions inline, the intrinsic and
> swizzle gaps are closed, texture channels are sampled, the EDSL has real
> control flow — mutable locals, `if`/`else`, `while`, `break`, `continue` and
> `select` — it has a signed integer, the operators only integers have, and a
> constant array to subscript with one, and now the vectors of both the integer
> and the boolean, with the componentwise comparison that is the only thing a
> boolean vector is ever made of. Multi-buffer Shadertoys are still ahead — see
> the plan and the coverage table below.

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

**Constant-trip-count loops are unrolled by the transpiler**, which reached a
large slice of the corpus before the EDSL had control flow at all and is still
what a countable loop gets: `for (int i = 0; i < 8; i++)` becomes eight recorded
copies of the body, with the counter substituted as a literal and folded through
whatever it touches. This does not blow up the emitted source — eacp's emitter
promotes any node used more than once to a named local, so an unrolled 64-step
march emits linear MSL/HLSL rather than a nested expression.

A loop whose length the transpiler cannot work out — a moving bound, or a body
that breaks on what it finds — is the one that needs statements, and gets them.
Which of the two a loop takes is decided by reading its header and its body, not
by asking the author.

## What is here now

```
Lib/shadertoy/Glsl/       lexer, parser, AST, diagnostics  (no GPU dependency)
                          Lower (unrolling, inlining, constant folding,
                          statements, and which locals become variables)
Lib/shadertoy/Emit/       the AST -> C++ EDSL emitter
Lib/shadertoy/Runtime/    Program (the Shadertoy uniform set + fullscreen pass)
                          Channel (a texture and the size published beside it)
                          ShaderView (clock, pointer, resolution, redraw)
Tools/Transpile/          the shadertoy-transpile CLI
Corpus/                   shaders the coverage report is measured against
Apps/Plasma/              a hand port, for comparison
Apps/PlasmaPort/          the same shader, converted from GLSL at build time
Apps/TunnelPort/          a converted port that reads a texture channel
Apps/MarchPort/           a converted port that marches a loop with a break
Tests/Glsl/               lowering and diagnostics
Tests/Runtime/            vertex layout, uniform block layout, generated stages,
                          corpus ports compiled from their GLSL by the build, and
                          rendered read-back of a bound channel, of a loop, of an
                          array read at an index the pixel computed, and of a
                          grid counted in integers behind a componentwise test
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
Shadertoy hands it over, and the uniforms keep the page's types as well as its
names — `iFrame` included, which is an `int` on both sides since stage 6. One
deviation is left: `iDate` is absent, which is a clock this runtime does not
have rather than a type the EDSL is missing.

A port that reads a texture channel declares the ones it reads and no others,
since every declared texture is a binding the draw has to satisfy:

```cpp
struct TunnelShader final : Shadertoy::Program
{
    Channel iChannel0;

    SHADERTOY_UNIFORMS(iChannel0)

    TunnelShader() { compile(); }

    GPU::Float4 mainImage(const GPU::Float2& fragCoord) override
    {
        return sample(iChannel0, fragCoord / iResolution.xy());
    }
};
```

`shader.iChannel0 = texture` points the channel at an image and publishes its
size as `iChannelResolution` in the same move, so a shader fetching texels
cannot be reading one image while scaling by the dimensions of another.

A port that loops declares what the loop writes as a variable — the one handle
in the EDSL that names a place rather than a value, so the body can leave
something behind for the code after it:

```cpp
auto travelled = var(0.0f);
auto steps = var(0.0f);

loop(steps() < 64.0f, [&]
{
    auto distance = length(origin + direction * travelled()) - 1.0f;

    ifThen(distance < 0.001f, [&] { breakLoop(); });

    travelled = travelled() + distance;
    steps = steps() + 1.0f;
});
```

`travelled()` is the read, spelled out rather than left to the implicit
conversion, so the difference between a bound handle and a place stays visible
in the source — which is also how the transpiler emits it.

A port that picks out of a table declares the array and subscripts it, and the
integer that indexes it is a value like any other — with the two crossings into
and out of float arithmetic written out, exactly as the GLSL had to write them:

```cpp
auto palette = array(float3(constant(0.1f), 0.1f, 0.2f),
                     float3(constant(0.9f), 0.4f, 0.2f),
                     float3(constant(0.2f), 0.8f, 0.6f),
                     float3(constant(1.0f), 0.9f, 0.7f));

auto index = toInt(uv.x() * 4.0f) & 3;
auto col = palette[index] * (0.5f + 0.5f * sin(iTime));
```

The array's size is its type, so a literal subscript is checked where it is
written; a computed one is the shader's own business, as it is in GLSL, which is
what the `& 3` is for.

A port that works on a grid counts its cell as a pair of integers, and one that
tests a point against a box compares two vectors a component at a time — which
is the operator itself here, since that is what both shading languages give a
pair of vectors:

```cpp
auto cell = toInt(fragCoord / 16.0f);
auto checker = fract(toFloat(cell.x() + cell.y()) * 0.5f);

auto inside = fragCoord < iResolution.xy() * 0.75f;
auto lit = select(all(inside), 1.0f, 0.25f);
```

`inside` is a `Bool2`, and nothing branches on one: `all()` and `any()` are what
turn a mask back into the single condition a `select` or an `ifThen` takes.
GLSL spells the comparison `lessThan(a, b)` because it reserves the operator for
scalars — the transpiler rewrites it into the operator, since that is what the
languages underneath actually have.

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
substituted as a literal — which is what keeps the ordinary loop counter off the
gap list, since after unrolling there is no integer left to express. (One that
survives, in a loop stage 5 keeps, becomes a float instead — the same reasoning
`iFrame` is one.) A call to a helper
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

**Stage 4 — texture channels.** *Done.* `iChannel0..3` and the three ways a
Shadertoy reads one: `texture`, `textureLod` and `texelFetch`, plus
`iChannelResolution`, which is the only array a Shadertoy indexes and needs no
array type because it is only ever indexed by a literal.

A channel is a `Channel` member the port declares — the texture and the size the
page publishes beside it, as one value, because assigning the texture fills
both. It carries Shadertoy's sampling rather than eacp's default (bilinear and
wrapping, not nearest and clamped), which is what a shader scrolling a
coordinate past 1 expects.

This is the first stage whose result nothing on the CPU can observe: a channel
that never reaches the draw renders black and reports nothing. So it is also the
stage that started the rendered read-back layer — `Tests/Runtime/ChannelTests`
draws a two-texel texture through a port and checks which half of the frame each
texel landed in.

**Stage 5 — real control flow.** *Done.* `Var`, `Bool`, `select`, `ifThen`,
`loop`, `breakLoop` and `continueLoop` in eacp's shader IR, driven by the
shaders unrolling cannot reach: `break`-on-hit raymarchers, dynamic bounds,
`while`. This is the stage that turns the EDSL from an expression tree into a
language, and it is the largest single payoff to eacp.

`ShaderGraph` now holds a statement list beside its expression store —
`Declare`, `Assign`, `If`, `Loop`, `Break`, `Continue`, in blocks — because the
one thing an expression tree cannot say is that something happens *before*
something else. A `Var` is the only handle whose value is not fixed when it is
built: reading one records a node at the point of the read, so what it evaluates
to is whatever the statements before it left there.

That is also what the emitter had to learn. It already named any subtree
evaluated more than once, and with control flow that sharing needs two bounds:
a name is given up the moment a statement writes a variable the value behind it
read, and a loop condition takes no name at all — it is printed into the `while`
header, so binding it beforehand would test a value that never changes again.
Both are pinned by codegen tests; the second one is the difference between a
raymarcher and a hang.

On the transpiler side, a `for` the trip count cannot be worked out becomes the
loop the port runs — init above it, step at the end of the body, which is where
a `continue` has to take the step with it. Which locals become variables is
decided after lowering: any name a loop or a branch writes and did not itself
declare, because a C++ handle rebound inside a lambda is a new handle that dies
at the closing brace. Everything else stays a plain binding, so an unrolled
shader reads exactly as it did.

**Stage 6 — the integer and the array.** *Done.* `Int`, the operators only
integers have (`%`, `&`, `|`, `^`, `<<`, `>>`, `~`), the comparisons, `min`/
`max`/`abs`, the two explicit crossings `toInt`/`toFloat`, and a constant
`Array<T, N>` with a subscript — driven by the one shader the table still had a
row for, which wanted all four at once.

The integer is signed, which is the part that had to be decided rather than
copied: eacp already had a `UInt` for the compute thread id, and indexing an
array with it is the obvious move and the wrong one. See below.

This is also the stage that took the last type deviation out of the uniform set:
`iFrame` was a float because there was nothing else for it to be, and is an
`int` on both sides now.

**Stage 7 — the vectors of both.** *Done.* `Int2`/`Int3`/`Int4` with the whole
integer operator set componentwise, `Bool2`/`Bool3`/`Bool4`, the componentwise
comparison that is the only thing a boolean vector is ever made of, and the
`any()`/`all()` that collapse one back into a condition — plus the constructors,
the swizzles and the crossings to and from float arithmetic a whole vector at a
time.

The comparison is spelled as the operator rather than as GLSL's `lessThan()`,
which is a decision rather than a shortcut — see below. So is which of the two
families crosses from the CPU.

It also gave a texel read the type it had been asking for since stage 4:
`fetch()` takes an `Int2`, which is what a texel index is.

**Stage 8 — multi-buffer Shadertoys.** *Next.* Buffer A–D with feedback, which
needs render-to-texture and float texture formats in eacp. What the corpus is
asking for beside it is the last of the type row: the struct, which is how a
shader that marches a scene carries back more than one thing from a hit.

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

A port that reads a channel needs one thing more from the app: the image. That
is what `Apps/TunnelPort` is — the same build step over `Corpus/Tunnel.glsl`,
plus a texture generated at startup and assigned to the channel the generated
struct declared. `Apps/MarchPort` needs nothing extra at all, and is the same
build step over `Corpus/Raymarch.glsl` — the shader there was no port of before
the EDSL had statements.

Measure the corpus — this is the exact command the table below comes from:

```bash
build/Tools/Transpile/shadertoy-transpile --report Corpus/*.glsl \
    Apps/PlasmaPort/Plasma.glsl
```

## The coverage table

Over the twelve shaders in `Corpus/` plus `Apps/PlasmaPort/Plasma.glsl`, as of
the end of stage 7. `Shaders` is the number blocked by that gap, which is what
the roadmap is sorted by:

| Blocker | Shaders | Occurrences |
| --- | ---: | ---: |
| type: struct | 1 | 1 |

12 of 13 shaders converted with no gaps.

Every vector row is gone. `Lattice.glsl` had five of them — an `ivec2` cell, the
componentwise `lessThan`, the `bvec2` it yields and the `all()` that collapses
one, which is what one gap looks like when it is genuinely three things — and
now converts, compiles and renders with nothing left over.

The remaining row is `Surface.glsl`, added with this stage so the table is still
measuring something: a raymarcher whose scene function hands back how far away
the surface was *and* what it was made of, which in GLSL is a struct and in the
EDSL is nothing at all — every value it names is one node, so a pair of them has
nowhere to live.

That it is one row rather than six is itself this stage's doing — see below.

`Kaleido.glsl` was added with stage 3 and is the shader that measures it: a
`mat2` rotation built inline, polar coordinates through the two-argument `atan`,
`mod` tiling, `exp` falloff, `inversesqrt` and `sign` in the shaping, and
swizzles of every width up to `.wzyx`.

`Channels.glsl` is stage 4's, and does the same for the three channel reads at
once: `texture` through the sampler, `textureLod` at a level it names itself,
and `texelFetch` at coordinates scaled by `iChannelResolution`.

`Raymarch.glsl` and `Mandelbrot.glsl` are stage 5's. The march is the loop whose
length is what it hits; the escape-time loop is everything else statements buy —
a `while` with a moving count, a `bool` the loop sets and the shading reads, a
colour written by both sides of an `if`/`else` and read after it, and a ternary
over two comparisons joined by a connective. All of them convert with nothing
left over, which is a claim only worth making because `Tests/Runtime` then
compiles them — and renders three.

`Palette.glsl` is stage 6's, and is the one that had been sitting in the table
since stage 1: a constant array of four colours, an index truncated out of a
coordinate, and the mask that holds it in range.

`Lattice.glsl` is stage 7's: a cell counted out of the coordinate in `ivec2`, a
checker taken from the parity of its two components, and a box test that
compares the coordinate against the resolution one component at a time and
collapses what that yields with `all()`.

The corpus is still far too small for these counts to rank anything. What it
establishes is that the measurement works end to end — and it has now paid for
itself five times over, turning three assumptions into bugs in stage 3, three
more in stage 4, two in stage 5, two in stage 6 and three in stage 7 before any
of them shipped.

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

**Two of the three channel reads had no node at all** (stage 4). `sample()`
existed; the level-selecting form and the texel read did not, and both are
exactly where the two backends stop agreeing on syntax. Metal passes the level
to the same `sample()` call, HLSL has a separate `SampleLevel` for it; Metal's
texel read is `read()` and D3D's is `Load()`. One `Sample` node with an optional
second argument and one `Fetch` node put both behind one spelling each, so a
shader says it once. Both are pinned by codegen tests that check the emitted
text on both backends and by one that compiles it.

**A texel read has no integer vector to arrive in, and the two backends
disagree on its sign** (stage 4). MSL's `read` takes a `uint2`, HLSL's `Load`
takes an `int3`. The EDSL has no integer vector, so the coordinate crosses as a
`Float2` — which is no loss, since GLSL's `ivec2` conversion truncates towards
zero and so does every conversion on the way down. The sign is the part worth
recording: converting the float straight to `uint2` on Metal makes a negative
coordinate undefined there while HLSL reads a defined zero, so eacp emits
`uint2(int2(c))` and both backends read zero for the same inputs.

**A literal mip level needed a `ShaderBuilder` in scope** (stage 4).
`textureLod(ch, uv, 0.0)` is most of the uses of the level there are, and `0.0f`
is a C++ float rather than a value in the graph — the same wall `float d = 2.0`
hits. Every other case anchors it with `constant()`, which only a program has.
Here the *texture* already carries the graph, so eacp takes the literal directly
and the port spells it the way the GLSL did.

**A stage's uniform block was decided by walking the wrong roots** (stage 5).
Both emitters declare the uniform block on a stage only when that stage reads
one, worked out by walking out from the fragment colour. Statements are a second
set of roots that walk never reached, so a shader whose loop body was the only
thing reading a uniform emitted `uniforms.u0` inside a function that had no
`uniforms` parameter — valid-looking source the platform compiler rejects. The
walk now covers every expression the statements evaluate, nested bodies
included. Found by `GPU/codegenControlFlowCompiles`, which is there precisely
because emitted text that reads correctly is not the same as text a shading
language will take.

**A loop condition cannot be one of the emitter's shared locals** (stage 5). The
emitter names any subtree it would otherwise evaluate more than once, which is
what keeps an unrolled march linear — and applied to a `while` header it is a
loop that never ends, because the name is bound once above the loop and the
condition is exactly the thing the body changes. Conditions now print into the
header, and every name open in the enclosing block is given up at a loop.

The general form of that is the second rule: a name is given up the moment a
statement writes a variable the value behind it read. Both rules together are
what let a name still span statements, which is where it matters most — the
distance a march tests is the distance it steps by, computed once. All three are
pinned by codegen tests.

**A `Bool` cannot cross from the CPU either** (stage 5). The same disagreement
as `mat2`/`mat3`, one size down: MSL packs a `bool` into a byte and an HLSL
cbuffer gives it four. `ShaderBuilder::uniform<T>()` static_asserts it rather
than leaving it to a comment; a flag from the CPU crosses as a `Float` and gets
compared.

**The integer a shader indexes with has to be signed** (stage 6). eacp already
had a `UInt` — the compute thread id and the buffer index computed from it — so
the cheap way to close the array row is to subscript with that one. It is also
wrong, and wrong in a way nothing but a rendered frame reports: `int(uv.x * 4.0)`
is negative to the left of the origin, and a shader that holds an index in range
with `min(max(i, 0), 3)` gets the *first* element there if the index is signed
and the *last* one if it wrapped to a huge number on the way in. Both compile,
both report nothing, and they differ only in which end of the palette half the
frame comes out. `Int` is therefore its own type, signed, sitting outside the
float vocabulary exactly as `UInt` does — and unlike `Bool` and the small
matrices it *can* be a uniform, since both languages give a signed integer four
bytes and pack it where they pack a float. `Tests/Runtime/ArrayTests` renders
the difference; `GPU/codegenIntegerUniform` pins the packing.

**An operator that does not fit in a `char`** (stage 6). `Expr` carried a binary
operator as one, which every arithmetic and bitwise operator fits in and the two
shifts do not. `Compare` had already been split out for that reason plus its
result type; a shift shares the first half of that and none of the second, since
it is shaped like the value being shifted. So `Binary` now carries its operator
in the node's text where a char cannot hold it, and the printer prefers the text
when there is one.

**An array is a declaration, not a value** (stage 6). It is the one thing a
shader names that no single node stands for, so it lives beside the expression
store rather than in it, and it is emitted as a `const` array at the top of the
stage that subscripts it — in the fragment function only, when only the fragment
expression reads it. That placement is also what bounds an element: it may read
a uniform or a varying, both of which are in scope there, and not a mutable
local, because no local has been declared yet at that point. A subscript is an
ordinary node under the emitter's sharing rule, so a table read twice at one
index is read once and named.

**The componentwise comparison is the operator, not a named call** (stage 7).
GLSL spells it `lessThan(a, b)`, `greaterThanEqual(a, b)` and so on, and copying
those names across is the obvious move. It is also the wrong one: GLSL only has
them because it reserves `<` for scalars, and both languages the EDSL emits into
give the operator itself to a pair of vectors and yield a boolean of the same
width. The EDSL follows the languages it emits into rather than the one it is
ported from — as it already does with `rsqrt`, `atan2` and `mix` — so `a < b` on
two `Float2` is the mask, and the transpiler rewrites the call into the operator.

That is also the one place this cost the transpiler something. `lessThan(a, b)`
arrives as a call and leaves as a binary operator, so the parenthesising and the
line-wrapping paths could no longer key on the node kind: both now ask what
operator a node *emits* as, and a comparison written as a call is grouped by
exactly the rules the `<` in a scalar one is.

**One set of swizzle accessors, three families** (stage 7). The 340 orderings
stage 3 added returned `Float`, `Float2`, `Float3` and `Float4` by name, so an
integer vector would have needed its own copy of all of them — and the cheap way
out is to give `Int2` only `.x()` and `.y()` and call it enough. Parameterising
the accessors on the family instead was measured rather than guessed at: nine
instantiations of the template compile in the same 0.26s that three did, because
a member function of a class template is not instantiated until it is used. So
an integer vector has the whole vocabulary and a boolean one does too, and
`cell.yx()` is one `Swizzle` node exactly as `uv.yx()` is.

**The integer vectors cross from the CPU and the boolean ones do not** (stage
7). The same split as `Int` against `Bool`, one size up, and for the same reason
each way: MSL and HLSL both pack an `int2` exactly where they pack a `float2`,
so nothing in the uniform block has to reconcile them; neither agrees on what a
`bool` occupies, and a vector of them inherits that. `ShaderBuilder::uniform<T>()`
static_asserts the second, and `Uniform<Int2>` reads back as the packed
`std::array<std::int32_t, 2>` it is.

**A texel read finally has the type it was asking for** (stage 7). Stage 4
recorded that `fetch()` took a `Float2` "because the EDSL has no integer
vector", which was true and is not any more. It takes an `Int2` now — which is
what a texel index is, and what GLSL's `texelFetch` takes — and the emitter
drops the `int2(...)` cast it used to wrap every coordinate in when the
coordinate already is one. The `Float2` form stays, because a shader usually has
the coordinate in hand as one and truncating it is exactly what the `ivec2`
conversion would have done.

Stage 3 also found a bug on this side of the fence rather than in eacp: the
emitter's line-wrapping path rebuilt a call's head from the *GLSL* name, so a
wrapped `inversesqrt` came back as `inversesqrt` instead of `rsqrt`. It had
never mattered while every supported builtin was spelled the same in both
languages. `Glsl/wrappedCallsKeepEdslName` pins it.

Stage 5 found one of its own, and a worse-shaped one: the check for whether a
loop can be unrolled was asked of the loop about *itself*, but treated its own
body as a nested one — where a jump belongs to the inner loop and can be
ignored. So a `for` with a `break` unrolled sixty-four times and dropped the
break on every copy. It converted, it compiled, and it was wrong. That is the
failure mode `Tests/Runtime/ControlFlowTests` exists for.

Stage 6 found two more here. The first is that a literal has no type of its own:
`index & 3` needs a `3` and the `int(uv.x * 4.0)` it was built from still needs
its `4.0f`, and the same AST node kind carries both — so which one a number is
spelled as is decided by where it sits, walked once per statement before that
statement is emitted. The second is a hang rather than a wrong answer: recovery
from a construct the parser cannot keep skips to a semicolon and stops at a
closing brace *without consuming it*, so the brace a `struct` body leaves behind
was reported, skipped to, and reported again forever. A `struct` is now named as
the capability it is and skipped whole, and top-level recovery asserts that it
moved. Found while measuring what the corpus asks for next, which is the other
thing the measurement is for.

Stage 7 found the one that decides what the table above is worth at all. A
struct the parser could not keep was skipped whole and its *name* thrown away
with it — so every later use of one arrived as something else: the
declaration `Hit hit = scene(p)` as a parse error, the constructor `Hit(d, c)`
as a call to a helper the port could not find, and each `hit.albedo` as an
unsupported *swizzle*. One missing capability, six rows, three of them wrong
about what was missing. Keeping the name is the whole fix: a value of a struct
type is then a value of a type the EDSL does not have, which is the thing that
was actually true. `Corpus/Surface.glsl` reports one row now instead of six,
and the discipline it restores — a diagnostic names one capability, and two
shaders blocked by the same thing agree on it — is what the counts are for.

## The gap ledger

What eacp's EDSL cannot express today, from reading the module — the standing
list the table above is gradually replacing with measured counts.

| Blocker | Where it lives in eacp |
| --- | --- |
| No structs — the scalars, their vectors and the constant array are all there, the aggregate is not: every value the EDSL names is one node, so a pair of them has nowhere to live | `ShaderTypes.h` |
| An array is constant: its elements are evaluated once at the top of the shader body, so one can read a uniform or a varying but not a mutable local, and nothing writes to an element afterwards | `ShaderGraph.h` — `ArrayConstant` |
| Control flow is fragment-stage (or kernel) only: the statement list is emitted into the fragment function, so a `Var` must not feed the position or a varying — as with `dfdx` and sampling, which are fragment-bound in the language too | `ShaderEmitter.cpp` |
| No `do`/`while`-at-the-bottom and no `switch`; no early `return` from a shader body, which is one expression returned at the end | `ShaderGraph.h` — `StatementKind` |
| A `Bool` cannot be a uniform: MSL packs one into a byte and an HLSL cbuffer into four. Send a `Float` and compare it | `UniformLayout.h` |
| No `transpose`, `inverse` or `determinant` — a matrix can be built and multiplied, and that is where `Float2x2`/`Float3x3` stop | `ShaderValue.h` |
| `Float2x2`/`Float3x3` cannot be uniforms: MSL and HLSL pack them to different sizes, which no padding between fields can bridge. `Float4x4` is unaffected | `UniformLayout.h` |
| A vector built only from literals is rejected — `ComponentsFor` needs one handle to take a graph from, so `vec3(0.0)` has no direct spelling. A scalar has the same problem: `float d = 2.0` is a C++ float rather than a value, and ports anchor both with `constant()` | `ShaderValue.h` |
| No app-facing render-to-texture (`OffscreenTarget` is snapshot-only) | `Frame.h` |
| Texture formats are 8-bit only; no float/half, and no mips — so a texture has one level and `sample(t, uv, level)` reads it whatever level it asks for | `Texture.h` |
| A texture is declared into the fragment signature only, so nothing sampled reaches the vertex stage — as with `dfdx`/`dfdy`/`fwidth`, which are fragment-bound in the language too | `ShaderEmitter.cpp` |
| No `textureSize`: HLSL spells it `GetDimensions`, which writes through out parameters rather than returning, and the emitter is an expression printer. A Shadertoy reads `iChannelResolution` instead, which the runtime fills from the bound texture | `ShaderValue.h` |
| No sampling bias and no explicit-gradient sample (`textureGrad`) | `ShaderValue.h` |

Closed by stage 3: the intrinsic row (all twenty-one of them), the swizzle row
(`.zw` and `.yx` were the measured cases; all 340 orderings are there now), and
`mat2`/`mat3` as expression types.

Closed by stage 4: the sampling row — `sample()` at a chosen level and `fetch()`
at texel coordinates, both spelled per backend from one node each. What is left
of textures is above: no mips, no float formats, and no vertex-stage sample.

Closed by stage 5: the control-flow row. Comparisons, the connectives, `select`,
mutable `Var`s, `if`/`else`, `while`, `break` and `continue` — and `bool` as an
expression type, which is what a condition is. What is left of it is above: the
loop forms neither shading language shares a shape for, the stage restriction,
and the vector comparison with no type to land in.

Closed by stage 6: the scalar half of the type row. `Int` — signed, a uniform as
well as an expression — with `%`, `&`, `|`, `^`, `<<`, `>>`, `~`, the six
comparisons, `min`/`max`/`abs` and the two explicit crossings to and from
`Float`; and `Array<T, N>` with a subscript at a literal or a computed index.

Closed by stage 7: the rest of it bar the aggregate, and the componentwise
comparison row. `Int2`/`Int3`/`Int4` with the whole integer operator set
componentwise and against a broadcast scalar, `Bool2`/`Bool3`/`Bool4`, the six
comparisons on two vectors of either family, `any()`/`all()` and the vector
`!`, constructors and swizzles for both, and `toInt`/`toFloat` over a whole
vector. An integer vector is a uniform as well as an expression; a boolean one
is not, for the reason the scalar `Bool` is not. What is left of the type row is
above: the struct.

## Validation

Three layers, because they catch different things.

**The report.** A shader either names what it needs or it does not — the counts
in the table above.

**The compiler.** `Tests/Runtime` transpiles corpus shaders at build time and
instantiates the ports, so a header that reports no gaps but that the EDSL will
not take is a failing build rather than a clean report. This is what found the
missing scalar broadcast above.

**Rendered pixels.** *Started in stage 4, and load-bearing since stage 5.*
`Tests/Runtime/ChannelTests`, `ControlFlowTests`, `ArrayTests` and `VectorTests`
render a port off-screen through `View::renderToImage` and read the frame back.
They exist because all four stages are invisible to the other two layers: a
channel that never reaches the draw compiles cleanly, reports nothing and
renders black; a loop that never runs, one that ignores its break and one that
runs to completion all compile, all report nothing, and differ only in their
pixels; an array read at an index that never varies is a perfectly plausible
flat colour; and a grid counted without the truncation is a ramp rather than a
lattice, while a box test collapsed with `any()` instead of `all()` lights three
quarters of the frame instead of one.

So each shader is built so its picture says which happened. Two texels — red
then green — through a sampled channel, a fetched one and a transpiled port say
which texel each half of the frame got. A march that steps until it passes the
pixel's own coordinate comes out a ramp; flat at either end would be a loop
stuck there. And the generated `Raymarch` port has to be brighter in the middle
than at the corner, which only a march that stops when it arrives can be.

Stage 6's is the sharpest of them, because it is the only one where both
outcomes are a picture rather than a picture and a blank: a four-colour palette
subscripted by the pixel's own quarter comes out in four bands, and the same
palette clamped over an index that really does go negative comes out the *first*
colour on the left if the index is signed and the last one if it is not. Nothing
short of the frame distinguishes those two.

Stage 7's are the same shape: a checkerboard, whose cells exist only because the
coordinate truncated into them, and one lit quarter rather than three. Each
check is written as a fraction of the frame rather than as a pixel count,
because a view renders at the display's backing scale and the image read back is
in points — a shader dividing `fragCoord` by a literal has more cells on a
retina display than on a plain one, and it is the same picture either way.

What is still ahead is the golden-image half of it: render at a fixed `iTime`
and diff against a stored PNG within a tolerance, which is the layer that
catches a port that compiles but is subtly wrong — `pow` with a negative base,
`round` on an exact half, and whether a `mat2` really came out column-major on
both backends. The read-back path it rides on is the one above.

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
- `build/Apps/TunnelPort/TunnelPort.app` — a transpiled port reading a channel
- `build/Apps/MarchPort/MarchPort.app` — a transpiled port marching a loop
- `build/Tests/Glsl/GlslTests`, `build/Tests/Runtime/RuntimeTests`

## On licensing the corpus

Shadertoy's default licence is CC BY-NC-SA 3.0 unless an author states otherwise,
and the non-commercial clause makes redistribution a real question rather than a
formality. The corpus is therefore fetched on demand from a list of IDs rather
than vendored, and only ports of self-authored or explicitly permissive shaders
are committed here.

The same applies to the images a channel reads: Shadertoy's own textures are
not ours to ship either, so `Apps/TunnelPort` generates the brick pattern it
samples rather than bundling one.
