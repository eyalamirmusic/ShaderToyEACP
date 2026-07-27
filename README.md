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

> **⚠️ Early days.** Stages 0 to 14 are done, and **142 of the 204 real
> Shadertoys convert *and* compile**. Stage 14 is the one the measurement had
> been pointing at since stage 10 and is the largest single move any stage has
> made: a `return` that is not the last thing a body does blocked 71 of the 204,
> more than twice the next four rows put together, and it turned out not to be a
> gap in the EDSL at all. A guard clause is the `else` it was always written as,
> a return out of a loop is a `break` and a flag, and a body rewritten into that
> shape before it is flattened is one the rest of the pipeline already handled.
> 96 shaders became 142, and four things fell out from underneath it: a
> `p.xy *= mat2(...)` lowered a component at a time, two anchoring bugs in the
> emitter, and the one intrinsic in eacp that would not take a literal first.
> A fifth is in neither count, which is what makes it the worst of them — two
> branches each writing the out parameter and only the last one counting, which
> is a wrong picture rather than a failed build.
>
> Stage 13 before it is the one the weakest layer of validation paid for:
> somebody walked the gallery with the arrow keys, it froze on the 43rd shader,
> and underneath were two walks in eacp's emitter that were superlinear in the
> size of the graph — one of them exponential. Neither is reachable by a shader
> small enough for anybody to have written by hand, and no report or compiler
> can see either.
>
> Stage 12 is the one that moved no number at all, and that is what it
> was for: it made the measurement reproducible. The corpus the counts are measured over
> was pulled by hand and could not be asked for; it is `shadertoy-fetch
> --dataset` now, 204 shaders in five unauthenticated requests, and the first
> run of it reproduced 99 converted and 95 compiled to the shader. What
> survived is registered where a build can read it, and `Apps/Gallery` shows
> 172 shaders rather than 30 — the 30 this repository guarantees, and the 142 it
> has only measured, marked as such on screen. Stage 11 is the one before it,
> and the first the measurement chose rather than an argument: it closed the
> eacp row that 27 of the 49 compile failures named, found five bugs of this
> project's own behind another 20, and built the scan step that scores both.
> The rest of the history:
>
> Stages 0 to 8: straight-line GLSL converts,
> loops become loops, helper functions inline, the intrinsic and
> swizzle gaps are closed, texture channels are sampled, the EDSL has real
> control flow — mutable locals, `if`/`else`, `while`, `break`, `continue` and
> `select` — it has a signed integer, the operators only integers have, and a
> constant array to subscript with one, and the vectors of both the integer and
> the boolean, with the componentwise comparison that is the only thing a
> boolean vector is ever made of. Stage 8 took the last row off the table — the
> struct, which turned out not to be a gap in the EDSL at all — and gave eacp
> render-to-texture and float texture formats, so a Shadertoy can have buffers
> that read what they left there last frame. Stage 9 is the corpus rather than
> the EDSL: the preprocessor and the lvalue swizzle a real Shadertoy is written
> with, and `transpose`/`determinant` in eacp for the one gap the reading turned
> up in its column. Stage 10 is the
> first time any of it was measured against shaders nobody here wrote: 204 real
> Shadertoys, half of which convert, half of *those* compile, and what stops the
> rest is a ranked list with eacp's own name at the top of it — which is what
> stage 11 then spent, and stage 12 made reproducible. See the plan and the
> coverage table below.

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

**A loop is a loop.** `for (int i = 0; i < 8; i++)` becomes the `loop()` the
EDSL has, with the counter an `Int` the port declares and steps. A moving bound
and a `break`-on-hit march get the same statement, because there is only one
kind of loop here: what a loop needs from the EDSL does not depend on whether
the transpiler could have worked out how long it runs for.

## What is here now

```
Lib/shadertoy/Glsl/       lexer, parser, AST, diagnostics  (no GPU dependency)
                          Returns (a body that leaves early, rewritten into one
                          that leaves at the end)
                          Lower (inlining, constant folding, statements,
                          scalarising structs, and which locals become
                          variables)
Lib/shadertoy/Emit/       the AST -> C++ EDSL emitter
Lib/shadertoy/Runtime/    Program (the Shadertoy uniform set + fullscreen pass)
                          Channel (a texture, or a buffer, and the size beside it)
                          Buffer (an off-screen pass and the pair it ping-pongs)
                          ShaderView (clock, pointer, resolution, pass order)
Tools/Transpile/          the shadertoy-transpile CLI
Lib/shadertoy/Coverage/   both tables over one corpus: what does not convert,
                          and what converts and then does not compile - plus
                          the registration of what survived both
Tools/Scan/               shadertoy-scan, which runs both over a directory
Lib/shadertoy/Corpus/     Transport (one request, and whatever came back) and
                          the published dataset that needs no key at all
                          (Json.h is what reads its replies)
Tools/Corpus/             shadertoy-fetch, which grows the corpus the counts are
                          measured over
Corpus/                   shaders the coverage report is measured against
Corpus/External/          204 real Shadertoys, committed, and the .licences that
                          say what each may be used for
Corpus/Imported/          the eight of those the build holds to compiling
Tests/Corpus/             the fetcher's bookkeeping, over a stubbed server
Tests/Coverage/           the scan's tabulation and its registration, over a
                          stubbed compiler
Apps/Plasma/              a hand port, for comparison
Apps/PlasmaPort/          the same shader, converted from GLSL at build time
Apps/TunnelPort/          a converted port that reads a texture channel
Apps/MarchPort/           a converted port that marches a loop with a break
Apps/TrailPort/           two converted ports, one reading what it wrote last frame
Apps/Gallery/             every converted port, switchable, on screen - the
                          ones committed here, and the measured corpus it
                          fetches and scans for itself beside them
Tests/Glsl/               lowering and diagnostics
Tests/Runtime/            vertex layout, uniform block layout, generated stages,
                          corpus ports compiled from their GLSL by the build, and
                          rendered read-back of a bound channel, of a loop, of an
                          array read at an index the pixel computed, of a grid
                          counted in integers behind a componentwise test, of a
                          struct carried out of a loop a field at a time, of a
                          buffer reading its own previous frame, of a colour
                          written one component at a time, of the two products a
                          matrix has, and of the three shapes a body leaves
                          early in
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

A port that carries more than one thing back from a hit declares nothing new for
it. GLSL needs a struct there; C++ already has one, and the EDSL is embedded in
C++ — so a hand port writes the aggregate and a generated one does not need to:

```cpp
struct Hit
{
    GPU::Float distance;
    GPU::Float3 albedo;
};

Hit scene(const GPU::Float3& p)
{
    return {length(p) - 1.0f, float3(constant(0.9f), 0.4f, 0.2f)};
}
```

The transpiler takes the other road, because it has already flattened every
scope into one by the time it gets there: `Hit hit` becomes `hit_distance` and
`hit_albedo`, and each is a local — or a `var`, if a loop writes it — exactly as
if the shader had spelled the two out. Either way nothing about the aggregate
reaches the graph, which is why it was never a gap in it.

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

**Stage 2 — inlining.** *Done.* A call to a helper becomes the helper's body,
arguments and all, including helpers that call helpers and helpers that write
back through an `inout` parameter. Flattening puts every local in one C++
scope, so a name declared inside a body is made unique.

It costs the generated code nothing, which is the whole reason it is the
transpiler's job rather than the EDSL's: a C++ function over handles records its
body inline wherever it is called, so a port holds no functions of its own
however many the shader was written with. That is the same argument stage 8
would later make about the struct, one level down.

`Lib/shadertoy/Glsl/Lower.cpp` is where the flattening happens, between the
parser and the emitter, and it is the only place that knows what a helper
*was*: what will not flatten is reported there and expanded once into a list the
emitter walks for diagnostics and then throws away. That is what stops one
construct the port cannot express from hiding every intrinsic underneath it.

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
shaders nothing decided on paper can reach: `break`-on-hit raymarchers, dynamic
bounds, `while`. This is the stage that turns the EDSL from an expression tree into a
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

On the transpiler side, a `for` becomes the loop the port runs — init above it,
step at the end of the body, which is where a `continue` has to take the step
with it. Which locals become variables is
decided after lowering: any name a loop or a branch writes and did not itself
declare, because a C++ handle rebound inside a lambda is a new handle that dies
at the closing brace. Everything else stays a plain binding, so the
straight-line half of a shader reads exactly as it did.

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

**Stage 8 — the aggregate, and multi-buffer Shadertoys.** *Done*, and the two
halves of it pulled in opposite directions, which is the interesting part.

The struct is the half eacp needed nothing for: a GLSL struct scalarises into
one local per field, which is the same argument that already made a GLSL helper
cost nothing, one level up. Declaration, constructor, whole assignment, field
read and field write, a struct through a parameter and back out of an `out` one,
a struct with a struct inside it, and a ternary choosing between two — all of it
is lowering, and none of it reaches the emitter. See below for why that is a
finding rather than a shortcut.

Multi-buffer is the half that needed real work in eacp, and it is the first
capability the corpus could not ask for on its own: the transpiler takes one
file, and a Shadertoy with buffers is several. eacp gained an app-facing
render-to-texture — `Frame::beginPass(texture)`, a pass on the same frame rather
than a frame of its own — and the float texture formats without which a pass
feeding back into itself loses a little of its state every frame. On this side,
a `Buffer` owns the pair of textures it ping-pongs and a `Channel` can follow
one, so the whole of a multi-buffer page is which channel reads which pass.

Every buffer runs, then every buffer swaps, then the image draws. One rule
rather than two, and it is what makes feedback mean what it says: the image sees
this frame's buffers, and a buffer reading any buffer — itself included — sees
the frame before.

**Stage 9 — what a real Shadertoy is written with.** *Done.* Stage 8 ended with
an empty coverage table and the observation that this was not good news: a
measurement that has stopped measuring is a corpus that has run out of things to
say. So this stage is the corpus, and the first thing measuring a real one
turned up is that almost nothing standing in the way was a gap in the EDSL at
all. It was *notation* — and notation is a wall like any other, because a front
end that stops at `#` fails a shader over spelling and reports nothing about
what the shader actually needed.

The preprocessor is the whole of it. A function-like `#define` — `#define S(a,b,t)
smoothstep(a,b,t)`, `#define R iResolution.xy` — with arguments expanded before
they are substituted and the result rescanned, so a macro can be handed its own
invocation. `#ifdef`, `#ifndef`, `#if` over an integer constant expression,
`#elif`, `#else`, `#endif` and `#undef`, which between them decide *which half*
of a shader the parser ever sees. And `##`, plus the hexadecimal literal that
every hash constant is written in and that lexed as a zero followed by a name
until this stage.

Beside it, the other thing every second shader does and this could not read: a
write to part of a value. `col.rg = uv`, `fragColor.rgb = col`, `p.xy += d`.
That is the second finding, and it runs the same way as stage 8's — GLSL has the
shorthand, and *neither shading language under the EDSL does*, so what the EDSL
would have to grow is not a way to write one component but a way to say the
thing both languages already say: build the whole value. `col.rg = uv` is
`col = vec3(uv.x, uv.y, col.b)`, which is exactly what a shader would have had
to write if GLSL had not offered the shorthand, and it is lowering rather than
anything in the graph.

eacp's own column got one row out of the reading, and it is a real one:
`transpose` and `determinant`, which is where the small matrices stopped being
write-only. A shader that carries an orientation around inverts an orthonormal
basis by transposing it, and until now a `mat3` could be built and multiplied
and nothing else. `inverse` stays a gap and is the more interesting half of the
entry — see below.

And the corpus itself, which this stage went looking for and did not find: what
Shadertoy's own API will serve wants credentials this project could not get, so
the corpus stayed empty until stage 10 found one already published.

**Stage 10 — shaders nobody here wrote, and looking at them.** *Done.* Stage 9
went looking for a corpus and could not reach one. What broke the deadlock was a
corpus someone had already collected and republished — `Vipitis/Shadereval-inputs`,
the input set of the ShaderEval benchmark, 204 distinct Shadertoys with the
author and the licence beside each one, paged out as JSON by a public endpoint
that wants no key at all. Every one of them carries an explicit permissive
licence, which is what lets all 204 be committed here rather than only measured.

Running the report over all 204 is the first real reading the coverage table has
had, and it produced a second one nobody had asked for. Half the shaders convert
— and **half of those do not compile**. A shader that converts is one the
transpiler had nothing to report about; whether the C++ it emitted is C++ a
compiler accepts is a different question, and the report is structurally unable
to ask it. `Apps/Gallery` is what asks it: one app with every port compiled in,
arrow keys to walk them, so a shader that converts and does not build stops the
build, and one that builds and does not look right is visible at last. Both
tables are below.

**Stage 11 — what the measurement asks for.** *Done*, and for the first time
the order was measured rather than argued. Three pieces, and the third came
first because it is what scores the other two:

**The scan step.** `Tools/Scan/shadertoy-scan` converts every shader in a
directory, feeds what converted to a real compiler, and prints both tables. The
tabulation is `Lib/shadertoy/Coverage`, where the compile step is a
`std::function` — the same shape the fetcher's transport has, and for the same
reason: everything around it is bookkeeping, and a test can drive it over a
compiler that never ran. Its first run reproduced stage 10's hand count exactly
(100 converted, 51 compiled, 49 not) in six seconds, which is what made the rest
of the stage a series of measurements rather than of opinions.

It was half of what this stage's plan said, and the missing half became stage
12's: "convert everything in a directory, compile-test each, **register the
survivors** and tabulate the rest". The tabulating landed here and the
registering did not, so what converted and compiled was a number in a table and
nothing a target could consume — which is why `Apps/Gallery` showed the 28
shaders this repository holds rather than the 95 that pass, until stage 12.

**eacp: a literal in any argument position.** The largest single row the table
has ever had, and it closed as one mechanism rather than as thirty overloads —
see the ledger. 27 shaders were blocked first by it and it took the count from
51 compiling to 77 on its own.

**The transpiler's own bugs.** Five of them, and between them and eacp's second
batch the count went 77 to 97 — the table below has it step by step. None of
them was visible to the report:

- A local declared without an initialiser was left undeclared, on the
  assumption that the assignment which follows becomes the declaration. Two
  things read a name before that: a write to part of a value rebuilds the whole
  of it out of the components it is *not* writing, and an inliner binding an
  `out` argument. Both produced C++ naming a value in its own initialiser.
- A matrix built only from literals was anchored once, and the EDSL takes it
  column by column — so every column after the first had no handle to take a
  graph from. Per column is the rule, which also catches a matrix whose names
  all land in one of them.
- A scalar written into more than one component was read a component at a time.
  GLSL broadcasts it: `p.xy += 0.05 * iTime` adds the one value to both.
- GLSL's `==` on two vectors compares the whole value and answers one bool; it
  is `equal()` that is componentwise. The port emitted the operator, which in
  both languages under the EDSL is a mask.
- A local may be called `cos`. GLSL's builtins are not names in a scope and a
  shader takes them freely; here the name shadows the very thing the next line
  calls.

And a sixth that is a correction rather than a fix: a helper is now resolved by
how many arguments the call passes, and a name that still resolves to several is
not inlined at all. GLSL overloads on parameter *types* as well, nothing here
infers the type of an argument, and taking the first candidate inlined a body
shaped for arguments the call did not pass — which converts, compiles, and draws
something else. It costs four shaders off the converted count, two of which had
been compiling. That direction is the point: the number went down because it had
been wrong.

**Stage 12 — the survivors, on screen.** *Done*, and it is the only stage so far
that moved no number. That is what it was for: the counts are the same 99 and 95
they were, and the difference is that they can now be got back by anybody who
runs two commands. A measurement nobody else can reproduce is not much better
than one nobody took.

**A fetcher for the corpus the counts are measured over.** Every number in this
README comes from `Vipitis/Shadereval-inputs`, and nothing here could ask for
it: the 204 had been pulled by hand. That made the input to the whole
measurement the one thing the repository could not reproduce, which is a worse
position than not having measured.

It cost one more `Transport` behind bookkeeping of the same shape, and the
factoring is the honest part: `Reply`, `Transport` and the rest now live in
`Corpus/Transport.h`, so the second fetcher is a peer of the first rather than
something bolted to its side. `shadertoy-fetch --dataset` is the whole of it —
204 shaders in five unauthenticated requests — and the id, the author and the
licence come back beside each one, so `Corpus/External` gains the `.licences`
ledger that decides what may ever be committed rather than only measured. All
204 turn out to be permissively licensed: 144 MIT, 51 CC0, and nine between
five other licences.

Two things about that endpoint had to be got right rather than assumed. A row
is one *function* of one shader, so the 204 arrive as 467 rows and the count
that matters is the distinct one. And it **shortens a cell rather than refusing
it** — a shader cut off mid-function still parses far enough to report gaps, so
taking one would have put a blocker in the coverage table that belonged to the
transport rather than to the shader. A truncated copy is not a shader here, and
a run that only ever saw one says so.

The first run of it reproduced stage 11's hand-checked figures exactly: 99
converted, 95 compiled, 4 did not. That is the stage's real result, and it is
worth more than a new number would have been.

**`shadertoy-scan --register <file>`.** What survived, written where a build can
read it. Two files, because two different things consume them: a CMake list with
the names, the headers and the include path, and beside the generated headers an
X-macro over the whole set — the include list and the entry table an app would
otherwise hold by hand. The scan already knew all of it, so this is the step
from a table to something consumable and not new information.

It found one thing on the way, and it is this project's own. The scan names a
generated header after the struct it declares, and *two shaders can want one
name*: Shadertoy ids are case-sensitive and these names are not, and everything
C++ rejects in a name becomes an underscore, so `a-b` and `a_b` are one struct
as surely as `clGyWm` and `ClGyWm` are. The second would have overwritten the
first and then been compiled against it — a compile result attributed to the
wrong shader, which is the one failure a coverage table cannot survive. Nothing
in these 204 collides; the fix is that nothing ever can.

**A Gallery with all of them in it.** Beside the committed list rather than
instead of it, because the two mean different things and only one of them can
keep the rule that makes it worth having. The 29 ports built here — 28 entries,
since a two-pass shader is one of them — fail the build if any of them converts
and will not compile, which is the whole reason each is in that target. The
fetched corpus cannot keep that rule: at that point 105 of the 204 did not
convert and 3 more did not compile, so a build that insisted would never run.

So the gallery has a guaranteed half and a measured half — 124 entries then, 172
now that stage 14 has been through it — and what tells them apart is the title
bar rather than the build, since which half a
doubtful frame belongs to is the first thing anybody looking at one wants to
know. Getting the second half is no switch and no manual step: building the
target fetches the corpus, scans it, registers what survived and compiles that
in. It was two switches for about an hour, and the hour was enough to build the
gallery in the wrong directory and get 28 shaders and no explanation. A count
that depends on how a build directory was configured is not a count.

Building it is the second check on the same claim, and not the same check: the
scan compiles each header alone, and this compiles the whole measured half into
one translation unit beside the committed one. It also settled what an external
port does with a channel it was never handed. Only one of them declares one —
but every declared texture
is a binding the draw has to satisfy, and what the page bound it to is in
neither the GLSL nor the corpus, so an unwired port gets the generated image the
textured ports here already use. The frame is then the shader's arithmetic over
*something* rather than a draw missing a binding.

**And then looking at them,** which is the piece with no tool and the reason for
the other three. 96 shaders nobody here wrote, converted by a transpiler that
has never once been checked against a picture of what they should look like, is
a great many frames to be quietly wrong about — and every validation layer above
stops short of exactly that. What the three pieces above buy is that comparison
being *possible*: it is now one build away, and `DdlyRr` by lush3dash1 was the
first frame from that half anybody looked at. They do not buy the comparison being *done* — the imported eight are
still the only ports checked against the page they came from — and the ledger
should not pretend otherwise.

**Stage 13 — what looking at them found.** *Done*, and it is the first thing
this project has found that is not about what eacp can express but about what it
can express *in finite time*.

Stage 12 ended by conceding that the shaders nobody here wrote had been compiled
and never looked at, and that the gallery was the tool for that and nobody's
afternoon yet. The afternoon happened, and it lasted until the 43rd shader: the
app froze on iq's `Dt3SDH` and never came back. Pressing the right arrow is not
a sophisticated instrument, and it went straight past every layer above it.

Underneath were two walks in eacp's emitter, both superlinear in the size of the
graph and one of them exponential — see the ledger for what they were and why a
DAG walked as a tree is the shape of the bug. What matters here is what makes
them a *stage* rather than a bug report:

- **No report can see this.** The coverage table says a shader converted. It
  cannot say the conversion takes forever, because it does not run the EDSL.
- **No compiler can see it either.** The scan had already passed all 96, because
  `-fsyntax-only` over a generated header type-checks the C++ and never builds
  the graph the C++ would build.
- **No test here could have caught it**, because every shader small enough to
  write by hand is small enough for an exponential walk to finish. It took a
  corpus of other people's shaders, and then a person looking at them.

That is three of the four validation layers stepping over the same fault, and
the fourth one being a human with an arrow key. The ledger below has the fix,
and the correction beside it: the first attempt at it broke 18 of eacp's own
tests, which is the argument for running the dependency's suite and not only
one's own.

**Stage 14 — the body that leaves early.** *Done*, and it is the row that had
been at the top since stage 10: an early `return` blocked 71 of the 204, more
than twice the next four rows put together.

It turned out to need nothing from eacp. A `return` in the middle of a function
is how a shader says "not this pixel", and the EDSL already has everything that
says it — the branch, the loop, the `break` and the mutable variable. What was
missing was a *pass*: `Glsl/Returns.cpp`, which rewrites a body into the shape
the rest of the pipeline already handled, before the flattening rather than
during it. What the body leaves with becomes a local, what it does after leaving
becomes nothing, and the one `return` left is the last statement — which is
exactly the shape `canInline` was already looking for, so the inliner needed no
change at all.

Two things make the generated port worth reading rather than merely correct. A
guard clause — `if (h < 0.0) return -1.0;` and then the rest — is an `else`, and
the rest of the body moves into it, so the commonest shape of all needs no flag.
And where a flag *is* needed, because what follows a loop is not a branch away
from what left it, it is declared only where something reads it.

96 shaders became 142. The rewrite is 38 of the 46; the other 8 were waiting on
things the gap had been hiding rather than on the gap. A `p.xy *= mat2(...)` was
lowered one component at a time, where GLSL applies a compound operator to the
whole swizzle — a pair times a matrix, not each half times a column. An integer
literal took `constant()` where its target was an `int`, and a vector component
took a second anchor on top of the one it had already given itself. And `clamp`
was the one intrinsic in eacp without the literal-in-any-position overloads the
rest of them have.

The fifth thing found underneath it is in neither count, and is the reason this
stage is worth reading twice. Two branches each writing `fragColor` produced a
second local nobody read, so whichever branch ran last was the only one whose
colour survived. That converts, compiles, satisfies every pixel a test thought
to check, and draws the wrong thing — and it had been doing so since long before
this stage. Moving the tail of a body into an `else` is what made a shader take
that path often enough to notice.

**What is next**: `type: indexing` is the top row now at 17, and behind it the
two shapes a `user-function` row can still be — a helper the shader wrote
several of, which needs argument types this does not infer, and a builtin the
intrinsic table does not name, which is a line each. Then the parse errors,
which are a different kind of work, and the two shaders that still convert
without compiling, each a type inferred wrongly in a different way.

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

A Shadertoy with buffers is several `.glsl` files rather than one, so it is
several of the same build step and a little wiring. `Apps/TrailPort` is the
worked example — that is the whole of it:

```cpp
Shadertoy::Ports::TrailBuffer bufferShader;
Shadertoy::Ports::TrailImage imageShader;

Shadertoy::Buffer buffer {bufferShader};
Shadertoy::ShaderView view {imageShader};

bufferShader.iChannel0 = buffer;   // Buffer A reads itself: the feedback
imageShader.iChannel0 = buffer;    // and the image shows what it accumulated

view.addBuffer(buffer);
```

A channel pointed at a buffer follows it rather than copying the texture it
happened to be showing, since what a buffer publishes is exactly what its swap
changes every frame.

Measure a corpus. These are the exact two commands both tables below come from,
and they are the ones to rerun after changing anything in either column:

```bash
build/Tools/Corpus/shadertoy-fetch --dataset          # 204 shaders, no key
build/Tools/Scan/shadertoy-scan Corpus/External --out scan \
    --register scan/Survivors.cmake
```

The fetch takes five requests and wants nothing from anybody: it pulls
`Vipitis/Shadereval-inputs`, which is the corpus every count here is measured
over, and writes the id, the author and the licence beside each shader. A run
never writes a shader it already has, and `.licences` beside them is what says
which ones could ever be committed rather than only measured.

The scan then converts every shader in the directory, compiles what converted,
and prints what blocked the rest — `--verbose` names each shader that converted
and did not compile, with what the compiler said first, which is what a table
cannot be acted on without. The generated headers are left in `--out`, because a
failure should be something to go and look at.

`--register` is what turns the survivors from a number into something a build
can consume: a CMake list of the names and headers at the path given, and an
`ExternalCorpus.h` beside the headers holding the includes and an entry table.
That is what the gallery below takes.

For the first table only, and without needing a toolchain:

```bash
build/Tools/Transpile/shadertoy-transpile --report Corpus/*.glsl \
    Apps/PlasmaPort/Plasma.glsl
```

Or look at it, which is a different question and one no report answers:

```bash
build/Apps/Gallery/Gallery.app/Contents/MacOS/Gallery   # arrows, space
```

Every shader in `Corpus/` is compiled into that one app — including the eight
real Shadertoys in `Corpus/Imported/`, which are there because their authors
licensed them permissively — and the arrow keys walk through them. The report
says a shader converted, and `RuntimeTests` says the C++ it converted to
compiles and satisfies a handful of pixels; neither says the frame looks like
the shader, and a march that stops one step early reports nothing, compiles, and
renders something plausible. The gallery is also the only target that compiles
every port, so a shader the transpiler is happy with and a C++ compiler is not
fails this build rather than going unnoticed.

Those 30 entries are every shader this repository holds, and the other 142 are
shaders whose licence keeps them off it — so the build goes and gets them.
Building `Gallery` fetches the corpus, scans it, registers what survived and
compiles that in, which is why the app says this on the way up:

```
172 shaders: 30 this repository holds and this build guarantees,
142 a scan measured.
```

There is no switch for it. A gallery that shows some of the shaders depending on
how a build directory was configured is a gallery nobody can trust the count of,
and the two halves are kept apart where it matters instead — on screen, since a
measured entry says so in the title bar. They are different claims: the 30 fail
this build if one of them stops compiling, and the 142 are shaders a scan says a
compiler accepted and nobody has looked at.

No fetch is involved: the shaders are committed, so every build directory scans
the same 204 and a machine with no network measures what every other machine
does. The scan is per build directory, because what converts and then compiles
is a fact about that compiler and those flags — and it re-runs whenever the
shaders or the transpiler it is measuring change, which is the only way the
number on the title bar is ever the current one.

Going past the 204 is the fetcher, and only ever by hand:

```bash
cmake --build build --target corpus-fetch
build/Tools/Transpile/shadertoy-transpile --report Corpus/External/*.glsl
```

It re-reads the published dataset and writes what is missing, which on an
up-to-date clone is nothing — five requests and no key. A different corpus is
`--dataset <name>`, and `--rows <n>` takes a taste of one rather than the whole
split.

## The coverage table

Two of them, because there are two ways to fail and only one of them was ever
being counted.

### What does not convert

Over the 204 real Shadertoys in `Vipitis/Shadereval-inputs`, which is the first
corpus here that nobody wrote for this project, and which since stage 12 is two
commands rather than an afternoon — the ones under "Measure a corpus" above.
`Shaders` is the number blocked by that gap, which is what the roadmap is sorted
by. The ten rows at the top of it, out of 139 that run down to a great many
blocking one shader each:

| Blocker | Shaders | Occurrences |
| --- | ---: | ---: |
| type: indexing | 17 | 41 |
| parse-error: unexpected `}` | 8 | 31 |
| user-function: saturate | 7 | 116 |
| user-function: radians | 7 | 9 |
| parse-error: unexpected `return` | 6 | 9 |
| component-assignment: indexed target | 5 | 18 |
| type: int | 5 | 8 |
| parse-error: expected `)`, found `[` | 5 | 7 |
| parse-error: unexpected `[` | 5 | 7 |
| user-function: rayMarch | 5 | 5 |

144 of 204 converted with no gaps; 60 reported at least one. The 129 rows below
these ten block 189 shaders between them, counting a shader once per row it
appears in.

The row that was at the top of this table for four stages is not in it at all
any more: `control-flow: early return` blocked 71 shaders and stage 14 took it
off. Most of the `user-function` rows underneath it went with it — `iBox`,
`render`, `rayMarch` and the rest were helpers that would not inline *because*
they left early, so the report was naming the same gap twice at two different
altitudes. What is left in that column is the two things a name can still be:
a helper the shader wrote several of, and a builtin the intrinsic table does
not name.

`type: int` is an integer construct the EDSL has no form for, met where a port
declares the counter of a loop. All 5 of those shaders report something else as
well, so nothing is blocked on this row alone — it is the kind of row worth
having anyway, because a gap that names what a shader needs is worth more than a
silence, which is the argument stage 7 made about the struct.

`radians` arriving as a *user function* is the cheapest row here: it is a GLSL
builtin the intrinsic table simply does not name. `saturate` is a different
thing entirely — it is a *helper the shader wrote three of*, one per argument
type, and since stage 11 an overload set is not something this inlines at all.
The expensive one is now `type: indexing`, at the top by a margin of two: a
subscript of anything that is not the one array a Shadertoy reads without
declaring.

Over the corpus in this repository — 21 in `Corpus/`, 8 in `Corpus/Imported/`
and `Apps/PlasmaPort/Plasma.glsl` — the same report is empty, 30 of 30, which is
what it has been since stage 8 and no longer means anything by itself. The
shaders here were written to convert or picked because they did.

### What converts and then does not compile

The second table is the one stage 10 discovered, and it exists because the first
one cannot see it. Of the 144 shaders that convert, the emitted C++ is fed to a
compiler; **142 of them build and 2 do not**. Grouped by the first error, with
`Unblocks` the number that would compile if this row alone went away:

| Blocker | Shaders | Unblocks | Whose is it |
| --- | ---: | ---: | --- |
| Invalid operands — a type inferred wrongly, carried into an operator | 1 | 1 | transpiler |
| `no viable overloaded '='` — the same wrong type, one statement later | 1 | 1 | transpiler |

Nothing in eacp's column is left in it, which has not been true before. What
stage 11 was worth, one piece at a time, and what stage 12 was worth after it —
the history of those two stages rather than a running total, since the current
figures are the two tables above:

| After | Converted | Compiled |
| --- | ---: | ---: |
| Stage 10, as measured by hand | 100 | 51 |
| The scan step, reproducing it | 100 | 51 |
| eacp: a literal in any argument position | 100 | 77 |
| A declaration with no initialiser | 100 | 86 |
| Matrix columns, the scalar broadcast, vector `==` | 103 | 95 |
| eacp: `vector * matrix`, `scalar * matrix`, `bool == bool`, a matrix `var`, `int(bool)` | 103 | 97 |
| An overloaded helper is not inlined | 99 | 95 |
| Stage 12, over a corpus it fetched itself | 99 | 95 |
| Stage 14: a body that leaves early, and the out parameter its branches write | 144 | 134 |
| An integer literal takes the integer anchor; a compound component write applies to the whole swizzle | 144 | 139 |
| A component that is already a vector needs no second anchor; eacp: `clamp` takes a literal in any argument position | 144 | 142 |

Two rows of that table are worth reading twice, and they are the two that do not
go up. "An overloaded helper is not inlined" is the only one that moves a number
*downwards*: two of the shaders it took off the converted list had been
*compiling*, with a helper body inlined that was written for other argument
types. A measurement that only ever improves is not measuring.

"Stage 12, over a corpus it fetched itself" moves nothing, and is the first time
these figures were produced by a machine that also went and got the shaders.
Stage 11's 99 and 95 were measured over a directory somebody had filled by hand;
stage 12's are over one `shadertoy-fetch --dataset` wrote, and they agree to the
shader. A number that comes out the same when the whole path to it is rebuilt is
a different kind of number from one that has only ever been produced once.

The three rows after them are stage 14, and what is worth reading in those is
that only the first is a capability. The other two are bugs, and every one of
them had been reachable the whole time behind a shader that stopped converting
before it got there — which is the argument for closing the biggest row first
even when the rows underneath look cheaper: what a gap hides is not in any
table.

This is still the table to take seriously, because every row in it is a shader
the coverage report had already called converted. It is also the reason
`Apps/Gallery` compiles every port rather than a chosen few: the report cannot
fail a build, and a compiler can — and since stage 12 that goes for the measured
half as well as the 30, which is 142 headers that compiled one at a time being
made to compile together.

The last row that came off it was `Surface.glsl`'s, in stage 8, and it came off
without eacp changing at all — see below, because that is the interesting part,
and because stage 9 then found two more of the same shape.

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

`Surface.glsl` and `Facets.glsl` are stage 8's. The first is the shader the
table had a row for: a raymarcher whose scene function hands back how far away
the surface was *and* what it was made of, written together inside the loop and
read after it. The second is the rest of the aggregate — a struct with a struct
inside it, passed to a helper and handed back from one, and a ternary choosing
between two whole values of it.

`TrailBuffer.glsl` and `TrailImage.glsl` are the other half of stage 8, and they
are the first entry that is two files rather than one: a buffer that reads
itself, and the image pass that shows what it accumulated. Neither is a gap in
the transpiler — both convert straight through — which is exactly the point, since
what they measure is the runtime around them. `Apps/TrailPort` runs them.

`Macros.glsl`, `Compose.glsl` and `Basis.glsl` are stage 9's, and the first two
are the only shaders here whose subject is notation rather than capability.
`Macros.glsl` is written the way a real Shadertoy is — the resolution behind a
`#define`, a shaping function that is a function-like macro, half the body
behind an `#ifdef`, a hexadecimal constant — and *none of it reaches the EDSL*.
`Compose.glsl` builds its colour one component at a time, which is the same kind
of finding: what it needs is lowering, not a node. `Basis.glsl` is the one that
did land in eacp's column — a `mat3` orientation gone back through with
`transpose`.

`Literals.glsl` and `Blanks.glsl` are stage 11's, one per column. The first
mixes a literal and a value in every intrinsic that takes both — one edge of a
`smoothstep` computed and the other written down, the literal first in a `min`
and second in a `step`, two constants mixed by something the pixel worked out —
and turns a coordinate through a matrix from both sides, which is the pair that
compiles either way round and means two different things. So the frame is what
says which: red carries what the row-wise product left and green what the
column-wise one did, and the two swap places across the middle of the frame.

`Blanks.glsl` is the other column and is named for what it is about: a local
declared before it holds anything. Nothing else here reads a name that has not
been written yet, and two things in a real shader do — a write to part of a
value, which rebuilds the whole of it, and an inliner binding an `out`
argument. Beside it, a scalar written into two components at once, whose two
halves are carried in a channel each so that the frame says the broadcast
reached both; an equality between two whole vectors; and a local called `cos`.

`Leaving.glsl` is stage 14's, and it is the first one here whose subject is a
*pass* rather than a construct: a guard clause, a return out of a loop with the
fallback under it, and mainImage's own return, one per channel. None of the
three is a thing the EDSL has to grow, which is exactly why it needs a frame —
what a rewrite gets wrong is which half of a body ran, and every wrong half
converts, compiles and draws.

That sentence used to end by conceding that the corpus was far too small for any
of these counts to rank anything, which was true for nine stages and is not any
more. Stage 10 put 204 shaders nobody here wrote through the same report and
then through a compiler, and both tables above are the result. What the nine
stages before it established is that the measurement works end to end — and it
had already paid for itself seven times over, turning three assumptions into
bugs in stage 3, three more in stage 4, two in stage 5, two in stage 6 and three
in stage 7 before any of them shipped, in stage 8 correcting the ledger about
where a gap even was, and in stage 9 finding that most of what stood in the way
was not in either column: it was notation the front end could not read.

Stage 10's finding is of the same kind and was the largest so far: half of what
the report passes, a compiler rejects — and the single biggest reason is one
missing shape in eacp's intrinsics rather than anything the ledger had listed.

Stage 11 is the first one that only spent what stage 10 measured, and its own
finding is about the measuring rather than about either column. Two of the seven
things it changed made a number *worse* — the honest count of what converts fell
by four — and both were cases where the transpiler had been quietly guessing:
which of a shader's three `saturate`s a call meant, and what a component read
off a scalar was. A table that can only go up is a table nobody is checking, and
the way to keep it checkable is to make the tool that prints it cheap enough to
rerun after every change. That is what the scan step is for.

## What this has already changed in eacp

The point of the exercise, so it is worth recording what it has found.

**Scalar broadcast for `+` and `-`** (stage 2). Every shader that sums an offset
into a coordinate — `uv + iTime`, `p - speed` — failed to compile, and not for
any reason the transpiler could see: it emitted exactly what the source said. eacp broadcast a scalar *handle* across a vector for `*`
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
what keeps a long body linear — and applied to a `while` header it is a loop
that never ends, because the name is bound once above the loop and the
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

**Render-to-texture is a pass, not a frame** (stage 8). eacp could already
render off-screen — `View::renderToImage` does — but only as a snapshot: an
`OffscreenTarget` of raw native handles, on a frame of its own, whose destructor
blocks until the GPU has finished so the pixels can be read back. Handing that
to an app as the way to draw into a texture would put a full pipeline stall
between every pass of a multi-pass shader, four times a frame.

What a multi-pass shader wants is the opposite: `Frame::beginPass(texture)`, a
pass on the frame it was already given. Passes on one command buffer are ordered
by the queue, so a texture written by an earlier one is legal to sample in a
later one and neither backend needs a fence to say so. Metal gets one more
render command encoder; D3D12 gets a render-target view, and the barriers to and
from `PIXEL_SHADER_RESOURCE` — recorded where the texture is *used* rather than
at the end of the pass, so a target written and then read costs the two it needs
and one written and never read costs one.

The pipeline had to learn the same thing. A `PixelFormat` that only had
`BGRA8Unorm` is fine while every draw ends up in a drawable; a draw that ends up
in a texture has to agree with that texture's format, and neither backend takes
one that does not.

**A feedback buffer needs a float format, and that is not an optimisation**
(stage 8). Eight bits per channel cannot hold a value above 1 and quantise
everything below it, so a pass that accumulates — a trail, a fluid, a running
average — loses a little of its state every frame and settles into a flat colour
it can no longer leave. `RGBA16Float` and `RGBA32Float` are what `Buffer` is
made of by default, and `Tests/Runtime/BufferTests` renders the same shader
through both: after eight frames the float one still has the gradient the pass
wrote and the 8-bit one has saturated flat.

The half that had to be decided rather than copied is which of the two to
default to. `RGBA32Float` is the obvious "no loss" answer and the wrong one:
neither backend guarantees a device can *filter* one, so a shader sampling its
own buffer anywhere but at a texel centre would come back nearest-neighbour on
some machines and bilinear on others. `RGBA16Float` filters everywhere eacp
runs, holds far more range than a colour needs, and costs half as much.

**The aggregate was never a gap in the EDSL** (stage 8). The ledger below had
carried a `No structs` row against `ShaderTypes.h` since the beginning, and the
obvious way to close it is a `ValueType::Struct`: a field list in the graph, an
offset per field, a struct declaration emitted into both shading languages, and
a `Var` that assigns through one. All of that is buildable and none of it is
needed. eacp's EDSL is embedded in C++, and C++ already has an aggregate — a
port that wants one writes `struct Hit { GPU::Float distance; GPU::Float3
albedo; };` and it works today, because a struct of handles is a struct of
handles. That is the same argument that already made a GLSL *helper* cost
nothing, one level up: a C++ function over handles is the function, and a C++
struct over handles is the struct.

What the transpiler then owes is the renaming, which it was already doing. A
struct-typed local becomes one local per field — `hit.albedo` is a name with a
dot in it, and `hit_albedo` is the same name spelled the way C++ takes one — and
a nested struct flattens through the path that reaches it. Nothing crosses a
boundary that would need a type: the fields are `Float`s and `Float3`s, which
the EDSL has had all along. So the diagnostic that used to say `type: struct`
now says nothing at all, and the one gap that survives is the honest remainder —
an array of structs, which really would need an array per leaf and a subscript
that agreed across all of them.

The measurement is what settled this rather than an opinion about it, and the
correction runs the other way from every entry above: the ledger was not
understating what eacp was missing, it was naming a capability in the wrong
column. A row that says the EDSL cannot do something it can is worse than a
missing row, because it is the one the roadmap would have been sorted by.

**The small matrices stop being write-only** (stage 9). A `mat2` or `mat3` could
be built and multiplied, and that is a matrix a shader can *make* and not one it
can use: the operation that turns an orientation into something you can go back
through is the transpose, since an orthonormal basis is inverted by transposing
it. `transpose` and `determinant` are in eacp now, and both are right on both
backends without a per-backend form — which is not luck. HLSL already holds
transposed what MSL holds, so transposing each leaves each holding the transpose
of the same logical matrix; and a determinant is equal for a matrix and its
transpose, so that one needs no argument at all. The check that matters is on
HLSL, where the construction already emitted a `transpose` of its own and the
two have to *nest* rather than cancel — `GPU/codegenMatrixTranspose` pins it and
`GPU/codegenMatrixTransposeCompiles` puts it through the real shader compiler,
which is the only thing that answers whether a language has the builtin the
emitter named.

`inverse` is not beside them, and that is the finding rather than the omission.
GLSL has it; **neither MSL nor HLSL does**. So it is not a node the graph is
missing — it is a cofactor expansion per order, which is a function a caller
writes out of the nodes that are there. The ledger row that used to name all
three as one gap was naming a property of GLSL as a property of eacp.

**Most of what stands in the way is not in either column** (stage 9). The ledger
below is a list of things the EDSL cannot express, and the coverage table is a
list of things the corpus asks for, and the assumption underneath both is that a
shader fails because of one or the other. Reading real Shadertoy source says
otherwise: the three most common walls were a function-like `#define`, an
`#ifdef`, and a write to part of a value — and *not one of them is a capability
at all*. Two are notation the front end could not read, and the third is a
shorthand GLSL has that neither shading language under the EDSL has, so what it
needs is the whole value rebuilt rather than anything new to build it with.

That matters more than any single row, because of what it does to the counts. A
shader whose first line is `#define R iResolution.xy` reported `preprocessor:
#define (function-like macro)` and then reported the *rest of the shader wrong* —
every use of `R` became an unknown identifier, and everything downstream of that
became a parse error. The gap that blocks a shader has to be the gap the shader
actually has, or the roadmap is sorted by noise. Stage 7 found the same shape one
level down, in a struct whose name was thrown away; this is that lesson at the
scale of a whole file.

**A literal goes where a shader writes one, not where an overload was written**
(stage 11). Every intrinsic came in two shapes — one where every argument is a
handle, and one where the scalar arguments are all `float` and get anchored with
`constantOn` against the argument that is not. There was nothing in between, and
GLSL mixes them freely: `smoothstep(0.0, zo * zi, -d)` has one edge of each,
`min(0.0, g)` puts the literal first, `step(d, 0.0)` puts it second, and
`mix(0.5, 1.0, h)` interpolates between two constants by something computed.

The fix is one mechanism rather than thirty overloads, which is what makes it
worth recording. `detail::intrinsic()` takes a pack of arguments that may be
handles or literals in any mix, finds the first that is a handle, and records
every literal as a constant on the graph that one brought — so an intrinsic
declares which argument its *shape* comes from and nothing else. A concept,
`ShapedBeside`, says what may be written beside a value of that shape: the same
shape, a scalar broadcast across it, or a literal. `min`, `max`, `pow`, `step`,
`clamp`, `mix`, `smoothstep` and `atan2` are each two declarations now and
accept every combination GLSL does.

It was worth **27 shaders blocked first and 26 compiling the day it landed**,
which is more than any other single entry here has been worth — and it is the
first one the corpus *ranked* rather than merely produced. Pinned by
`GPU/codegenLiteralArguments`, which checks the literal is in the position it
was written in — every one of these means something else if it moves — and by
`GPU/codegenLiteralArgumentsCompile`, which puts it through the real shader
compiler.

**A vector belongs on the left of a matrix too** (stage 11). `matrix * vector`
was there and `vector * matrix` was not, and the second is not the first with
the arguments swapped: it reads the matrix's rows rather than its columns, which
is the transposed product and how half the Shadertoys that rotate a coordinate
spell it. Neither backend needs a form of its own for it — MSL's operator and
HLSL's `mul()` both read whichever operand is on the left as a row vector — so
the whole of it is that the `Mul` node carries its operands in the order they
were written. Which meant renaming them: the node's arguments were `matrix` and
`vector`, and they are `left` and `right`.

Beside it, the product that is not a product at all: a matrix scaled by a
scalar, which multiplies every element. That one is a plain `Binary` rather than
a `Mul`, and it needs nothing per backend for a better reason — a transpose
leaves a scaling alone, so HLSL holding the matrix the other way up cannot tell.
`GPU/codegenVectorTimesMatrix` pins the order on both backends, because the
other order compiles just as happily and is a different picture.

**A matrix can be a mutable local, and a `Var` was constrained on the wrong
thing** (stage 11). `ShaderProgram::var()` took the float vocabulary, so the
cell a shader walks a grid with could not be a variable even though the builder
underneath it accepted one; that was a hole rather than a decision, and it is
the handle families now, as the builder always had it. The matrix needed an
overload of its own on top, for the reason a matrix needs one everywhere here:
it is outside all three families, having none of their operators.

**Three crossings that were missing rather than decided** (stage 11).
`int(a > b)` is 1 or 0 in GLSL and both languages under this cast a bool the
same way, so `toInt` and `toFloat` take one. `a == b` on two conditions is not
the connectives — it is true when both are false — and both languages have it.
And `min`/`max` on integers took the literal on the right only, for no reason
other than that nobody had written the other one; a shader writes `max(0, -i)`
as readily as `max(i, 0)`.

**The one intrinsic the literal row missed** (stage 14). `min`, `max`, `pow`,
`mix`, `step` and `smoothstep` all take a literal in any argument position;
`clamp` took one anywhere but first. Nothing about that is interesting except
how it was found — `3dlSDn` writes `clamp(0.02, 2.0, jt)`, which is an odd thing
to write and compiles as GLSL, and no amount of reading the module would have
turned it up. A corpus is a list of the things nobody would think to try.

**The emitter walked a graph as though it were a tree** (stage 13). The first
gap the corpus found that is not about what eacp can express but about what it
can express *in finite time*, and it was found by a person pressing the right
arrow: the gallery froze on entry 43 of 123, iq's `Dt3SDH`, and never came back.

Two bugs, one shape. `referencesUniform` — which decides whether a stage has to
declare the uniform block — recursed over the expression graph with no visited
set at all. The emitter's entire reason for existing is that a subtree used
twice is stored once, so what it walks is a DAG, and a DAG walked as a tree is
**exponential in the sharing** rather than linear in the nodes. Worse, it was
called once per statement root, each call starting over. Beside it, `dropStale`
— the rule that gives up a name when a statement writes a variable that name
read — allocated and zeroed a buffer the size of the whole graph *per open name
per statement*, so the bookkeeping cost the entire graph however small the
subtree it then looked at.

The fixes are a visited set that is shared across a stage's roots, and a marker
that is a stamp rather than a flag, so starting a walk over is a counter
increment rather than clearing the graph. `Dt3SDH` went from not finishing to
finishing, and the slowest entry was 120 milliseconds — the 124 the gallery held
then were ready in a second and a half together.

Neither bug could show on a small shader, which is why ten stages of them did
not: this is what a corpus is for.

The generation counter starting level with the buffer it stamps into was worth
18 failing tests in eacp's own suite the first time round — a fresh set in which
every node already counts as visited is not a walk that gives the wrong answer
slowly, it is one that gives it immediately. `GPUTests` caught it, which is the
argument for running the dependency's tests and not only one's own.

**A swizzle binds tighter than any operator** (stage 9). Emitting `.x()` after
an object that emitted as an operator produced `a + b.x()` where the source said
`(a + b).x`, which is a different value and a perfectly plausible one. It had
never come up while every swizzle in the corpus sat on a name — and the
component rebuild above puts one on an arbitrary expression every time it fires.
Pinned by `Glsl/swizzleOfASumIsGrouped`.

**A regrouped constructor has no arguments to re-walk** (stage 9). The same
shape as stage 8's broadcast bug, one constructor over: the line-wrapping path
re-walks a call's argument *nodes*, and a matrix constructor takes columns while
GLSL spells components, so `mat3(1.0, 0.0, ...)` had no wrappable form and came
out 116 columns wide. Nine nodes in, three columns out. The fix is to let the
layout take a call whose arguments are already text, which is what a regrouped
constructor has and what the wrapping path had no shape for.

Stage 3 also found a bug on this side of the fence rather than in eacp: the
emitter's line-wrapping path rebuilt a call's head from the *GLSL* name, so a
wrapped `inversesqrt` came back as `inversesqrt` instead of `rsqrt`. It had
never mattered while every supported builtin was spelled the same in both
languages. `Glsl/wrappedCallsKeepEdslName` pins it.

Stage 11's are five, and they are the first found by a tool rather than by
reading — every one of them came off the scan's second table, and every one was
invisible to the first:

- **A declaration with no initialiser was a promise rather than a
  declaration.** It was deferred on the assumption that the assignment which
  follows becomes the declaration, and two things read the name before that: a
  write to part of a value rebuilds the whole of it out of the components it is
  *not* writing, and the inliner binds an `out` argument by name. Both emitted
  C++ naming a value in its own initialiser. It is declared with a zero now,
  which is a value GLSL leaves it free to have.
- **A matrix built from literals needs an anchor per column, not one.** The
  EDSL takes a matrix column by column, so each column is a vector constructor
  of its own and each needs a handle to take a graph from. Anchoring the first
  component of the whole thing left every later column with none — and so does
  a matrix whose names all happen to land in one of them, which is why the rule
  is per column and asked of each column's own components.
- **A scalar written into more than one component is broadcast.** The rebuild
  reads a component per slot it fills, and `p.xy += 0.05 * iTime` has no
  components to read: GLSL puts the one value in both. A component of a scalar
  is now the scalar, which is a thing nothing parses and only the rebuild
  produces.
- **`==` on two vectors is one bool in GLSL.** It is `equal()` and `notEqual()`
  that are componentwise; the operator compares the whole value. Both languages
  under the EDSL do the opposite and yield a mask, so what says what the shader
  said is that mask collapsed — `all()` for the equality and `any()` for its
  negation. The type the emitter had been giving it was already the right one,
  which is how it went unnoticed: the C++ was a `Bool3` and everything
  downstream had been told it was a `Bool`.
- **A local may be called `cos`.** GLSL's builtins are not names in a scope and
  a shader takes them freely; here the name shadows the very thing the next line
  calls. The list of what a local may not be called already existed — it held
  the uniform set — and now holds the EDSL vocabulary and the C++ keywords too.

And the correction beside them, which is the one worth keeping: **a helper is
resolved by how many arguments the call passes**, and a name that still resolves
to several is not inlined at all. GLSL overloads on parameter types as well,
nothing here infers the type of an argument, and taking the first candidate
inlined a body written for other arguments — which converts, compiles, and draws
something else. Two of the four shaders this took off the converted list were in
exactly that state. It is reported as the helper it could not inline, which is
what it is, rather than as a row of its own saying the same thing about the same
name.

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

Stage 8's is smaller and is the kind only a new shader finds. The emitter's
line-wrapping re-walks a call's *argument nodes* rather than the text it emitted,
which is what lets a wrapped line lay its arguments out properly — and a
constructor whose emitted arguments are not the ones it was parsed with had no
such form, so it stayed on one line however long it got. That covers the
broadcast `vec3(x)`, which emits as `float3(x, x, x)`: one node, three times.
`Corpus/TrailBuffer.glsl` writes `vec3(0.25 + uv.x * 0.5)` and came out
ninety-seven columns wide. Saying that the arguments are the same node repeated
is the whole fix, and it is the last shape that could still run past the limit.

Stage 12's is the first one found by building a *consumer* of the measurement
rather than by taking the measurement, and it is about names. The scan calls a
generated header after the struct it declares, and a struct name is a file stem
with everything C++ rejects turned into an underscore and the first letter
raised — so two shaders can want one name. `a-b` and `a_b` are one struct, and
so are `clGyWm` and `ClGyWm`, which matters because Shadertoy ids are
case-sensitive and six characters long. The second shader would have overwritten
the first's header and then been compiled against it: a clean report, a passing
compile, and a result belonging to a shader that was never measured. Names are
disambiguated where they are handed out now, which is once per scan and before
any of them is written. Nothing in the 204 collides — the point is that a corpus
ten times the size would, silently, and the coverage table is the one thing here
that cannot afford to be quietly wrong.

That is also the whole of what stage 12 added to this list, and nothing at all
to the one below it: a stage spent making a measurement reproducible turned up
no gap in eacp, which is what it should do. The gaps are found by *measuring*,
and this stage did not move the measurement.

## The gap ledger

What eacp's EDSL cannot express today, from reading the module — the standing
list the table above is gradually replacing with measured counts.

The first row here to arrive as a count rather than as a reading was closed by
stage 11, which is what the counts were built to do; what is left is still a
reading, and the tables above are what will replace it. In the order the rows
were found rather than ranked:

| Blocker | Where it lives in eacp |
| --- | --- |
| No array of aggregates — a struct of handles is a C++ struct and needs nothing from the EDSL, but an array of one would need an array per field and a subscript that agreed across all of them, which no single `ArrayConstant` node says | `ShaderGraph.h` — `ArrayConstant` |
| A struct cannot be a uniform, for the same reason `mat2` and `bool` cannot: what the two languages disagree about is the packing *inside* the value, which the block's pad scalars cannot correct. Send the fields | `UniformLayout.h` |
| An array is constant: its elements are evaluated once at the top of the shader body, so one can read a uniform or a varying but not a mutable local, and nothing writes to an element afterwards | `ShaderGraph.h` — `ArrayConstant` |
| Control flow is fragment-stage (or kernel) only: the statement list is emitted into the fragment function, so a `Var` must not feed the position or a varying — as with `dfdx` and sampling, which are fragment-bound in the language too | `ShaderEmitter.cpp` |
| No `do`/`while`-at-the-bottom and no `switch`; no early `return` from a shader body, which is one expression returned at the end | `ShaderGraph.h` — `StatementKind` |
| A `Bool` cannot be a uniform: MSL packs one into a byte and an HLSL cbuffer into four. Send a `Float` and compare it | `UniformLayout.h` |
| No `inverse` — and unlike the rest of this list that is a property of the languages rather than of eacp: GLSL has one, MSL and HLSL do not, so it would be a cofactor expansion per order and is a function a caller writes | `ShaderValue.h` |
| `Float2x2`/`Float3x3` cannot be uniforms: MSL and HLSL pack them to different sizes, which no padding between fields can bridge. `Float4x4` is unaffected | `UniformLayout.h` |
| A vector built only from literals is rejected — `ComponentsFor` needs one handle to take a graph from, so `vec3(0.0)` has no direct spelling. A scalar has the same problem: `float d = 2.0` is a C++ float rather than a value, and ports anchor both with `constant()` | `ShaderValue.h` |
| No mips — a texture has one level, so `sample(t, uv, level)` reads it whatever level it asks for | `Texture.h` |
| A render target is single-sampled and has no depth attachment: what `Frame::beginPass(texture)` is for is a full-screen pass over a whole texture, and neither has a meaning there | `Frame.h` |
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
is not, for the reason the scalar `Bool` is not.

Closed by stage 9: two thirds of the matrix row. `transpose` and `determinant`
on all three square matrices, spelled once and right on both backends for the
same reason the construction already was. What is left of it is above, and it is
the third that neither shading language has either.

Closed by stage 11: the literal row, which had been the first row here and was
the largest the corpus has ever ranked — every intrinsic takes a literal in
every position GLSL puts one in, through one mechanism rather than through an
overload per combination. With it, the rest of the matrix vocabulary a shader
actually writes: `vector * matrix`, a matrix scaled by a scalar on either side,
and a matrix as a mutable local. And three crossings that were absent rather
than decided against — `int(bool)` and `float(bool)`, `bool == bool`, and the
integer `min`/`max` with the literal on the left.

Answered by stage 14 without eacp changing: **no early `return`**, which had
been the top of the first table since stage 10 and the top of this list with it.
The row above is still true — the EDSL has no early exit from a shader body, and
stage 14 did not give it one. What it did was establish that a shader does not
need one: a `return` in the middle of a body is a branch, a `break` and a
variable, and eacp has had all three since stage 5. That is the second row this
list has lost to something other than eacp growing, after the aggregate in stage
8, and both were found the same way — by trying to write the thing rather than
by reading the module.

The one addendum stage 14 did make to eacp is to the literal row stage 11
closed: `clamp` was the single intrinsic without the literal-in-any-position
overloads, which is the kind of gap only a corpus finds.

Struck out by stage 8: the aggregate row, which was never eacp's to close. A
struct of handles is a C++ struct, and the transpiler scalarises a GLSL one into
the fields the EDSL always had. What replaced it above is what is actually true
— no array of aggregates, and no aggregate uniform.

Closed by stage 8 for real: the render-to-texture row and the 8-bit-only row.
`Frame::beginPass(texture)` draws into a texture created with
`TextureDescriptor::renderTarget`, on the frame it was already given rather than
one of its own, and `RGBA16Float`/`RGBA32Float` are what a pass that reads what
it wrote has to be made of. What is left of textures is above: no mips, and no
vertex-stage sample.

## Validation

Four layers, because they catch different things, and the gap between the first
two is where half of stage 10's findings came from.

**The report.** A shader either names what it needs or it does not — the counts
in the first table above.

**The compiler.** `Tests/Runtime` transpiles corpus shaders at build time and
instantiates the ports, so a header that reports no gaps but that the EDSL will
not take is a failing build rather than a clean report. This is what found the
missing scalar broadcast above, and — once it was pointed at 100 shaders written
by other people rather than the 19 written here — the 49 in the second table.

Since stage 11 the same layer runs over a whole corpus without a build:
`shadertoy-scan` compiles what converted and groups the failures, so the second
table is a command rather than an afternoon. Six seconds over 204 shaders is
what makes it something to run *after every change* rather than once a stage —
which is the point, because the numbers it prints are the only reason to prefer
one piece of work to another. Its own tabulation, and the registration it
writes, are checked by `Tests/Coverage`, over a compiler that never ran.

Since stage 12 the corpus underneath it is a command too, which is what makes
the six seconds worth anything to anybody else: `shadertoy-fetch --dataset`
takes five requests and no key, and the run that first replaced a hand-filled
directory printed the same 99 and 95 the hand-filled one had. A layer whose
input cannot be reproduced is measuring the directory rather than the
transpiler.

**Rendered pixels.** *Started in stage 4, and load-bearing since stage 5.*
`Tests/Runtime/ChannelTests`, `ControlFlowTests`, `ArrayTests`, `VectorTests`,
`StructTests`, `BufferTests` and `ComponentTests` render a port off-screen
through `View::renderToImage` and read the frame back. They exist because all
seven stages are invisible to the other two layers: a
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
coordinate truncated into them, and one lit quarter rather than three.

Stage 8's is the only one where the check is an *ordering* rather than a value,
which is what makes it independent of whatever transfer function the frame comes
back through: the albedo a march carries out of its loop has components
0.9 > 0.4 > 0.2, and nothing but the albedo leaf landing in the albedo slot puts
the three channels in that order — a frame shaded by the distance leaf instead
comes out grey. Beside it, two candidates that differ in every field at once say
whether a choice between two whole structs was made per field or once.

Stage 8's other one is the first that needs more than one frame to say anything,
and the first written as a *comparison between two runs* rather than against a
number: the same two shaders through a float buffer and through an 8-bit one,
eight frames each. After eight the float one still has the gradient the buffer
pass wrote and the 8-bit one has saturated flat, and neither run has to be right
about an absolute value for the pair to be conclusive.

That shape came out of getting it wrong first. A read-back frame is what Core
Animation composites, which is premultiplied — so a fragment left at alpha 0.25
comes back with its colour divided by four, and two values that differed before
that division can arrive equal after it. The first version of eacp's own
render-target test read exactly that and looked like a float format that was not
working. Every check here is now either between two renders or on an *ordering*
of channels, both of which survive whatever the frame is composited through.

Each check is written as a fraction of the frame rather than as a pixel count,
because a view renders at the display's backing scale and the image read back is
in points — a shader dividing `fragCoord` by a literal has more cells on a
retina display than on a plain one, and it is the same picture either way.

What is still ahead is the golden-image half of it: render at a fixed `iTime`
and diff against a stored PNG within a tolerance, which is the layer that
catches a port that compiles but is subtly wrong — `pow` with a negative base,
`round` on an exact half, and whether a `mat2` really came out column-major on
both backends. The read-back path it rides on is the one above.

Stage 9's is the second one where the check is an ordering rather than a value,
and it adds a shape the others do not have: a staircase. `Compose.glsl` writes
each component of its colour separately and then accumulates into one of them
once per band the pixel's own column is past, so green rises in four steps
across the frame while red and blue stay flat. A component written into the
wrong slot changes the ordering; a variable read once outside the loop flattens
the staircase; a variable read after its own assignment gets the step heights
wrong. All three compile, all three report nothing, and all three are a picture.

Stage 11's two are both cases where the wrong answer is not merely a picture but
*the same picture reflected*. A vector times a matrix and a matrix times a
vector are one node differing in which operand is on the left, so emitting
either for both compiles, reports nothing and turns the shader the other way;
`Literals.glsl` carries the two products in a channel each, and they swap places
across the middle of the frame. And a scalar written into two components at once
is a broadcast, so `Blanks.glsl` carries the two halves in a channel each and
the check is that they are *equal* — a rebuild that reached only the first leaves
the second holding whatever the declaration put there, which is a colour.

Stage 14's is the one where the wrong answer is *code that ran when it should
not have*, which no other shape here covers. `Leaving.glsl` writes the three
ways a body leaves early into a channel each, so one frame answers for all
three: blue where mainImage returns and nothing after it may write the colour,
red for a guard clause on both sides of the branch it leaves from, and green for
a return out of a loop — checked in two columns, one where the loop leaves and
one where it runs out and falls through to what is under it. A rewrite that
always took one of those two would still draw something.

Two of the traps this layer was meant to catch are closed by construction
instead, which is the better place for them: `mod` is recorded as its floored
form rather than as a call either backend would truncate, and a matrix
construction is transposed on HLSL so both backends read the same columns. Both
are pinned by codegen tests in eacp rather than by an image.

**A human looking at it.** *Stage 10.* `Apps/Gallery` compiles every port into
one app and walks through them with the arrow keys. It is the weakest layer and
the least automatable, and it is the only one that can catch a shader which
converts, compiles, satisfies every pixel a test thought to check, and still
does not look like the shader it came from. What it caught first was in the
runtime rather than in a port: rewinding `iTime` restarted nothing for a shader
that feeds back into itself, because what such a shader accumulates lives in its
buffer rather than in its clock. `Buffer::clear()` is that fix, and
`BufferTests` now pins it — a layer above turning into a layer below, which is
where a finding from this one is supposed to end up.

It used to be the layer with the widest gap between what it could catch and what
it had been pointed at: stage 11 took the shaders that convert *and* compile
from 51 to 95, and this layer could only ever see the 28 that live here, because
the gallery's port list was written by hand and the rest are files a licence
keeps out of this repository. Stage 12 closed that half of it: building the
gallery goes and gets them, all of them are in the one app, and the measured
ones say so in the title bar.

What it did not close, and what is worth saying plainly, is that a count of 142
is still a claim about compilers rather than about pictures. This layer is a
person, and a person has looked at one of them. Stage 14 made that gap wider
rather than narrower — 46 shaders arrived at once, none of them looked at — and
being the layer that scales worst with a good stage is the honest description of
what it is.

It paid for itself before that afternoon happened, though, which is the
argument for it. The first thing anybody did with the measured half was press
the right arrow, and the app froze on the 43rd and never came back — two walks
in eacp's emitter that were superlinear in the size of the graph, one of them
exponential, neither reachable by a shader small enough for anybody to have
written by hand. No report says a shader takes forever to emit. No compiler says
it either: the scan had already passed every one of them, because
`-fsyntax-only` on the generated header type-checks the C++ and never builds the
graph it would build.
It took the weakest and least automatable layer, doing the one thing it is
for.

For the imported shaders there is a fifth check available and no way to automate
it: the shader's own page. `Corpus/Imported/3l23RK.glsl` is iq's *Pie - distance
2D*, and the port draws the same orange distance bands, the same blue interior
and the same white outline as shadertoy.com does — differing only in where the
animation had got to. That comparison is worth doing once per imported shader
and is not worth building anything for.

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

No option beyond those two, and in particular none for the measured corpus:
building `Apps/Gallery` fetches it, scans it and adds what survived, the first
time and not again while the shaders are there. It is the one target that
reaches the network, and the only one that does anything a plain `--target
Gallery` does not.

Outputs:

- `build/Tools/Transpile/shadertoy-transpile` — the converter
- `build/Tools/Scan/shadertoy-scan` — the converter and a compiler over a corpus,
  and the registration of what survived both
- `build/Apps/Plasma/Plasma.app` — the hand port
- `build/Apps/PlasmaPort/PlasmaPort.app` — the same shader, transpiled
- `build/Apps/TunnelPort/TunnelPort.app` — a transpiled port reading a channel
- `build/Apps/MarchPort/MarchPort.app` — a transpiled port marching a loop
- `build/Apps/TrailPort/TrailPort.app` — two transpiled ports, one a feedback buffer
- `build/Apps/Gallery/Gallery.app` — the whole corpus, one shader at a time,
  and a scanned one beside it when the build was pointed at one
- `build/Tools/Corpus/shadertoy-fetch` — the corpus fetcher, for growing it
- `build/Tests/Glsl/GlslTests`, `build/Tests/Runtime/RuntimeTests`,
  `build/Tests/Corpus/CorpusTests`, `build/Tests/Coverage/CoverageTests`

## On licensing the corpus

Shadertoy's default licence is CC BY-NC-SA 3.0 unless an author states otherwise,
and the non-commercial clause makes redistribution a real question rather than a
formality. So nothing arrives here under that default: every shader committed to
`Corpus/External` carries an explicit permissive licence instead, recorded by
the collector who published the corpus and written into the file's own header.

That is why the corpus comes from a published dataset rather than from the site.
Shadertoy serves shaders their authors marked **Public + API**, which their terms
describe as the content "accessible to third party applications or services" — a
permission to read, and not a licence to redistribute. Nothing taken that way
could have been committed here, so nothing here is taken that way.

Every one of the 204 in `Vipitis/Shadereval-inputs` carries an explicit licence — 144 MIT,
51 CC0, and nine between `cc-by-4.0`, `cc-by-3.0`, `isc`, `apache-2.0` and
`libpng` — because that is what its collector recorded beside each shader, and
that licence comes back with the shader rather than being looked up afterwards.
It is written into the file's own header and into `.licences` beside them, which
is the record that decides what may be committed here rather than only measured.
All 204 pass that test, so all 204 are committed.

They were gitignored for a while on the grounds that a permissive licence makes
committing a shader *possible* rather than obligatory, and that only the eight
in `Corpus/Imported/` had been decided on. What that cost was the thing the
licence was never in the way of: a clone had 29 shaders, the other 204 arrived
only if a build reached HuggingFace and got an answer, and a machine that did
not was quietly measuring a corpus an order of magnitude smaller than the one
the tables here report. A number nobody else can reproduce is the failure this
whole section exists to avoid, so the shaders are in the repository, and
`shadertoy-fetch` grows the corpus rather than supplying it.

The same applies to the images a channel reads: Shadertoy's own textures are
not ours to ship either, so `Apps/TunnelPort` generates the brick pattern it
samples rather than bundling one — and a scanned port that declares a channel
nobody wired up gets that same generated image, for the same reason.
