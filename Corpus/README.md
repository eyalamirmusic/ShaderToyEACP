# Corpus

Shaders the transpiler is measured against. Run the coverage report over all of
them with:

```bash
build/Tools/Transpile/shadertoy-transpile --report Corpus/*.glsl \
    Apps/PlasmaPort/Plasma.glsl
```

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

`Surface.glsl` is the one that walks into a wall now, which is what keeps the
coverage table from being an empty measurement. Its scene function hands back
how far away the surface was *and* what it was made of, which in GLSL is a
struct: the last of the type row, and the one thing left that no single value in
the EDSL stands for.
