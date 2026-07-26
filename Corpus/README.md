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

`Palette.glsl` is the one that still walks into a wall, which is what keeps the
coverage table from being an empty measurement: an array, the integer index into
it, and the mask that keeps the index in range.
