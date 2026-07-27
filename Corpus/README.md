# Corpus

Shaders the transpiler is measured against. Run the coverage report over all of
them with:

```bash
build/Tools/Transpile/shadertoy-transpile --report Corpus/*.glsl \
    Apps/PlasmaPort/Plasma.glsl
```

`Imported/` is the exception to all of the above: eight real Shadertoys by other
people, permissively licensed, which is why they could be committed. See the
README there — including the count that came out of the 204 they were picked
from, which is the first thing this corpus has measured that it did not write.

Every shader here is also compiled into `Apps/Gallery`, which draws them one at
a time — arrow keys to move, space to restart. That is where a shader that
converts, compiles and still does not look right gets caught, and it is the
reason anything added here should be added to the gallery's list too.

Everything here is written for this project, so it can be committed and shared
without qualification. The wider Shadertoy corpus is a different matter — its
default licence is CC BY-NC-SA 3.0 — so those shaders are fetched on demand from
a list of IDs and never vendored. See the licensing note in the root README.

The set is chosen to span the gap ledger rather than to look impressive: a few
shaders that convert cleanly, and several that each walk into a different wall.

Every shader here that converts cleanly is also compiled as a port by
`Tests/Runtime`, so what the transpiler emits for it has to satisfy a C++
compiler and not only the coverage report. Anything added here that converts
cleanly is worth adding there too.

`Kaleido.glsl` is the stage 3 shader: it exists to put a `mat2`, the
two-argument `atan`, `mod`, `exp`, `inversesqrt`, `sign` and swizzles of every
width through the EDSL at once, so that "the intrinsics are done" is a thing the
report and a compiler both agree on.

`Channels.glsl` is stage 4's, and does the same for the channel reads: `texture`
through the sampler, `textureLod` at a level it names itself, and `texelFetch`
at coordinates scaled by `iChannelResolution`. `Tunnel.glsl` is the ordinary
case beside it — one channel, sampled once — and is what `Apps/TunnelPort` runs.

`Raymarch.glsl` and `Mandelbrot.glsl` are stage 5's, and between them cover the
whole of what statements buy. The march is a loop whose length is what it hits,
inside a helper the port has to inline around it; the escape-time loop adds a
`while` with a moving count, a `bool` the loop sets and the shading reads, a
colour written by both sides of an `if`/`else` and read after it, and a ternary
over two comparisons joined by a connective. `Apps/MarchPort` runs the first.

`Palette.glsl` is stage 6's: a constant array, the integer index into it, and
the mask that keeps the index in range. It was the one shader that still walked
into a wall until that stage closed it, and it is rendered back by
`Tests/Runtime/ArrayTests` — an array read at a computed index compiles and
reports nothing whether or not the index actually varies, so a frame is what
says which element each pixel got.

`Lattice.glsl` is stage 7's, and is the vector half of the row stage 6 closed
the scalar half of: an `ivec2` cell counted out of the coordinate, a checker
taken from the parity of its two components, and a box test that compares two
vectors componentwise and collapses the `bvec2` it yields with `all()`.
`Tests/Runtime/VectorTests` renders it back, because a grid counted without the
truncation is a ramp rather than a lattice and a box test collapsed with `any()`
lights three quarters of the frame instead of one — and both of those compile
and report nothing.

`Surface.glsl` and `Facets.glsl` are stage 8's, and they measure the aggregate —
which turned out to be a capability of the transpiler rather than one the EDSL
was missing, since a struct of handles is a C++ struct and lowering already
renames every local into one flat scope. The first is a march whose scene
function hands back how far away the surface was *and* what it was made of,
carried out of the loop a field at a time. The second is the rest of it: a
struct with a struct inside it, passed to a helper and handed back from one, and
a ternary choosing between two whole values of it.

`Tests/Runtime/StructTests` renders both back, because every way of getting the
scalarisation wrong still compiles and still reports nothing — a leaf read out
of the wrong slot is a plausible colour, and a field that never escaped the loop
is the colour it started as.

`TrailBuffer.glsl` and `TrailImage.glsl` are the other half of stage 8, and the
first entry here that is two files rather than one: a Shadertoy with a buffer.
The buffer reads itself, which is what a buffer is for, and the image pass shows
what it accumulated. Neither is a gap in the transpiler - both convert straight
through - and that is the point, since what they measure is the runtime around
them: the render-to-texture, the float format, the ping-pong and the order the
passes run in. `Tests/Runtime/BufferTests` renders them through a float buffer
and an 8-bit one side by side, because after eight frames those two disagree and
nothing short of the frames says so. `Apps/TrailPort` runs them.

`Macros.glsl`, `Compose.glsl` and `Basis.glsl` are stage 9's, and the first two
are the only entries here whose subject is *notation* rather than capability.
`Macros.glsl` is written the way a real Shadertoy is - the resolution behind a
`#define`, half the body behind an `#ifdef`, a shaping function that is a
function-like macro rather than a function - and none of it reaches the EDSL at
all. `Compose.glsl` builds its colour a component at a time, which GLSL allows
and neither shading language under the EDSL does: each write is the whole value
rebuilt, and `Tests/Runtime/ComponentTests` renders it back because a component
landing in the wrong slot is a colour and not an error.

`Basis.glsl` is the eacp half of the same stage: an orientation carried in a
`mat3` and inverted with `transpose`, which is the operation that turns a matrix
from something a shader can build into something it can use. `inverse` stands
beside it and is still a gap - GLSL has one, MSL and HLSL do not.

Nothing in the corpus walks into a wall today, which is a corpus that has run
out of things to say rather than an EDSL that has run out of gaps. Eighteen
shaders written for this project is not the thousands the counts were meant to
rank - what closes that is real Shadertoys, and `Corpus/External` is 204 of
them, committed. Every one carries an explicit permissive licence and a header
naming its author, its page and that licence, which is what makes shipping them
here possible; the dataset they came from recorded all three. So a clone is
measured without asking anything of the network:

```bash
build/Tools/Scan/shadertoy-scan Corpus/External
```

Growing it past those 204 is the fetchers, and only that. `--dataset` re-reads
the published corpus and writes what is missing, which on an up-to-date clone is
nothing:

```bash
cmake --build build --target corpus-fetch
```

Pulling by id from Shadertoy's own API is the other half, and the one whose
results stay out of the repository: those arrive under the site's default CC
BY-NC-SA 3.0 unless an author says otherwise, which is a licence that makes
redistribution a real question rather than a formality.

```bash
export SHADERTOY_API_KEY=...            # https://www.shadertoy.com/myapps
build/Tools/Corpus/shadertoy-fetch --list 500 --sort newest
build/Tools/Transpile/shadertoy-transpile --report Corpus/External/*.glsl
```

`--list` is how the list gets filled without picking ids by hand: one request
buys as many ids as it asks for, and the new ones are appended to `ids.txt`
under a line saying where and when they came from. Draining that list is the
expensive half - a key is worth 1500 requests a month - so a run skips what is
already in `Corpus/External`, skips what the API has already refused, and stops
when the month's budget is gone rather than spending it twice on the same
shader. The books it keeps are `.quota` and `.refused` in the output directory.

Most of a real list will refuse: the API serves only what its author marked
Public+API. That is a measurement rather than a fault, and it is why the exit
code distinguishes a refusal from a failure.
