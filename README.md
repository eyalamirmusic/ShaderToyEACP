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

> **⚠️ Early days.** Stages 0 to 8 are done: straight-line GLSL converts,
> constant-trip-count loops unroll, helper functions inline, the intrinsic and
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
> with, a fetcher that pulls shaders by id, and `transpose`/`determinant` in
> eacp for the one gap the reading turned up in its column. See the plan and the
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
                          statements, scalarising structs, and which locals
                          become variables)
Lib/shadertoy/Emit/       the AST -> C++ EDSL emitter
Lib/shadertoy/Runtime/    Program (the Shadertoy uniform set + fullscreen pass)
                          Channel (a texture, or a buffer, and the size beside it)
                          Buffer (an off-screen pass and the pair it ping-pongs)
                          ShaderView (clock, pointer, resolution, pass order)
Tools/Transpile/          the shadertoy-transpile CLI
Lib/shadertoy/Corpus/     the API, and the books a 1500-request month needs
Tools/Corpus/             shadertoy-fetch, which pulls Shadertoys by id
Corpus/                   shaders the coverage report is measured against
                          (ids.txt names the ones that are not committed)
Apps/Plasma/              a hand port, for comparison
Apps/PlasmaPort/          the same shader, converted from GLSL at build time
Apps/TunnelPort/          a converted port that reads a texture channel
Apps/MarchPort/           a converted port that marches a loop with a break
Apps/TrailPort/           two converted ports, one reading what it wrote last frame
Apps/Gallery/             every converted port, switchable, on screen
Tests/Glsl/               lowering and diagnostics
Tests/Runtime/            vertex layout, uniform block layout, generated stages,
                          corpus ports compiled from their GLSL by the build, and
                          rendered read-back of a bound channel, of a loop, of an
                          array read at an index the pixel computed, of a grid
                          counted in integers behind a componentwise test, of a
                          struct carried out of a loop a field at a time, of a
                          buffer reading its own previous frame, and of a colour
                          written one component at a time
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

And the corpus itself: `Corpus/ids.txt` and `shadertoy-fetch`, which turn a list
of Shadertoy ids into files under a gitignored `Corpus/External`. The ids are
committed and the shaders are not, which is what the licence note at the bottom
has been about since stage 1. A shader with buffers comes back as several files,
exactly as `TrailBuffer.glsl` and `TrailImage.glsl` are, and a `common` pass
comes back as the prelude it is rather than as a file of its own.

It is a C++ tool for the same reason everything else here is one: eacp already
has an HTTP client and a JSON parser, so the fetcher costs one file and no
dependency the project did not already have. The fetching itself is
`Lib/shadertoy/Corpus`, so that `Tests/Corpus` can drive it without a key and
without a socket; `Tools/Corpus` is the command line around it, and
`shadertoy-corpus` is the one library here that talks to anything.

The list ships empty, and what stands between it and the thousands the counts
were meant to rank is worth stating precisely, because two of the three things
in the way are not what they look like:

- **The bot check is not one of them.** shadertoy.com sits behind a Cloudflare
  challenge that `curl` cannot pass — it answers 403 to `robots.txt` — but
  `/api/v1/` is exempt from it, and eacp's HTTP client reaches the API on the
  first try. An unkeyed request comes back `{"Error":"Invalid key"}`, which is
  the API refusing a request rather than the edge refusing a client.
- **A key needs Silver or Gold status.** Creating an app at
  [/myapps](https://www.shadertoy.com/myapps) is refused below that, and status
  is earned by contributing to the community over time — shaders published,
  likes, followers, how long the account has been around. A new account cannot
  get a key by wanting one.
- **A key is worth 1500 requests a month.** That is the number the fetcher is
  built around, and the reason it is bookkeeping rather than a download loop.
  The index costs one request however many ids come back, so a month buys
  roughly 1499 shaders — and a corpus of thousands is a few months of runs that
  never ask twice for what they already have.

Only shaders whose author marked them **Public + API** come back at all, which
is Shadertoy's own line: their terms say Public+API content "can also be
accessible to third party applications", and plain Public content is not
offered to third-party tools. So the corpus is what the API serves, and
scraping the site for the rest is not on the table.

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

Measure the corpus — this is the exact command the table below comes from:

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
licensed them permissively — and the arrow keys walk through them. The report says a shader converted, and `RuntimeTests` says the
C++ it converted to compiles and satisfies a handful of pixels; neither says the
frame looks like the shader, and a march that stops one step early reports
nothing, compiles, and renders something plausible. The gallery is also the only
target that compiles every port, so a shader the transpiler is happy with and a
C++ compiler is not fails this build rather than going unnoticed.

Or measure real Shadertoys, which is what the counts were built to rank. The
ids are committed and the shaders are not:

```bash
export SHADERTOY_API_KEY=...            # https://www.shadertoy.com/myapps
build/Tools/Corpus/shadertoy-fetch      # everything in Corpus/ids.txt
build/Tools/Transpile/shadertoy-transpile --report Corpus/External/*.glsl
```

Filling the list is the same tool: `--list <n>` asks the API's index for ids
and adds the new ones to `Corpus/ids.txt`, `--query <term>` searches instead of
taking the whole index, and `--sort` and `--filter` pass the API's own
vocabulary through — `--filter multipass` is how to go looking for the buffer
shaders rather than the popular ones.

```bash
build/Tools/Corpus/shadertoy-fetch --list 500 --sort newest
build/Tools/Corpus/shadertoy-fetch --list 500 --ids-only   # one request, no shaders
```

A run never asks for a shader it already has, and never asks twice for one the
API refused — `.quota` and `.refused` beside the shaders are what hold that
line between runs, and `--budget` is what a month is allowed to spend. When the
budget runs out the rest stay on the list, which is how a corpus larger than
one month's requests gets built at all.

## The coverage table

Over the eighteen shaders in `Corpus/` plus `Apps/PlasmaPort/Plasma.glsl`, as of
the end of stage 9. `Shaders` is the number blocked by that gap, which is what
the roadmap is sorted by:

| Blocker | Shaders | Occurrences |
| --- | ---: | ---: |

19 of 19 shaders converted with no gaps.

The table is empty, and it has been since stage 8 — which is not the good news
it looks like, and stage 9 is what that observation turned into. A measurement
that has stopped measuring anything is a corpus that has run out of things to
say, not an EDSL that has run out of gaps, and eighteen shaders written for this
project is nothing like the thousands the counts were meant to rank.

So the honest reading of an empty table is still: **the corpus is too small, and
these counts rank nothing yet.** `Corpus/ids.txt` and `shadertoy-fetch` are the
way out of that, and they are what stage 9 built. What stage 9 also did
was read enough real Shadertoy source to find three walls that a corpus of
fifteen hand-written shaders had never touched — the preprocessor, the lvalue
swizzle and the matrix transpose — which is a preview of what the fetcher will
produce at scale rather than a substitute for it.

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

The corpus is still far too small for these counts to rank anything. What it
establishes is that the measurement works end to end — and it has now paid for
itself seven times over, turning three assumptions into bugs in stage 3, three
more in stage 4, two in stage 5, two in stage 6 and three in stage 7 before any
of them shipped, in stage 8 correcting the ledger about where a gap even was,
and in stage 9 finding that most of what stood in the way was not in either
column: it was notation the front end could not read.

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

Stage 8's is smaller and is the kind only a new shader finds. The emitter's
line-wrapping re-walks a call's *argument nodes* rather than the text it emitted,
which is what lets a wrapped line lay its arguments out properly — and a
constructor whose emitted arguments are not the ones it was parsed with had no
such form, so it stayed on one line however long it got. That covers the
broadcast `vec3(x)`, which emits as `float3(x, x, x)`: one node, three times.
`Corpus/TrailBuffer.glsl` writes `vec3(0.25 + uv.x * 0.5)` and came out
ninety-seven columns wide. Saying that the arguments are the same node repeated
is the whole fix, and it is the last shape that could still run past the limit.

## The gap ledger

What eacp's EDSL cannot express today, from reading the module — the standing
list the table above is gradually replacing with measured counts.

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

Three layers, because they catch different things.

**The report.** A shader either names what it needs or it does not — the counts
in the table above.

**The compiler.** `Tests/Runtime` transpiles corpus shaders at build time and
instantiates the ports, so a header that reports no gaps but that the EDSL will
not take is a failing build rather than a clean report. This is what found the
missing scalar broadcast above.

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
- `build/Apps/TrailPort/TrailPort.app` — two transpiled ports, one a feedback buffer
- `build/Apps/Gallery/Gallery.app` — the whole corpus, one shader at a time
- `build/Tools/Corpus/shadertoy-fetch` — the corpus fetcher
- `build/Tests/Glsl/GlslTests`, `build/Tests/Runtime/RuntimeTests`,
  `build/Tests/Corpus/CorpusTests`

## On licensing the corpus

Shadertoy's default licence is CC BY-NC-SA 3.0 unless an author states otherwise,
and the non-commercial clause makes redistribution a real question rather than a
formality. The corpus is therefore fetched on demand from a list of IDs rather
than vendored, and only ports of self-authored or explicitly permissive shaders
are committed here.

Since stage 9 that is machinery rather than a policy: `Corpus/ids.txt` is the
list, `shadertoy-fetch` turns it into files under `Corpus/External`, and
`.gitignore` keeps that directory out. The fetcher needs a key of your own in
`SHADERTOY_API_KEY`, from [Shadertoy's apps
page](https://www.shadertoy.com/myapps) — which refuses to create one unless
the account has Silver or Gold status, earned by contributing to the community
rather than by asking.

The author's own setting is the other half of it, and the fetcher inherits it
for free: the API serves only what its author marked **Public + API**, and
Shadertoy's terms are explicit that this is the content "accessible to third
party applications or services". A shader marked plain Public is deliberately
not on offer to a tool like this one, and comes back as a refusal that
`.refused` records and later runs skip. That is a line worth keeping on the
right side of — the site is reachable in a browser, and taking what the API
declines to serve would be helping oneself to exactly what those authors opted
out of.

The same applies to the images a channel reads: Shadertoy's own textures are
not ours to ship either, so `Apps/TunnelPort` generates the brick pattern it
samples rather than bundling one.
