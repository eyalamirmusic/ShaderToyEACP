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

`Fbm.glsl` and `Voronoi.glsl` are also compiled as ports by `Tests/Runtime`, so
what the transpiler emits for them has to satisfy a C++ compiler and not only
the coverage report. Anything added here that converts cleanly is worth adding
there too.
