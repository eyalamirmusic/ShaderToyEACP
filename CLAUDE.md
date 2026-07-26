# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Git Rules

Claude must never commit or push without explicit permission from the user in
the current conversation.

## Project Overview

ShaderToyEACP converts Shadertoy GLSL into eacp GPU programs — shaders authored
as C++ structs through eacp's string-free shader EDSL, compiled to Metal and
HLSL from one source. The corpus doubles as a conformance suite for that EDSL:
every shader that fails to convert names a gap in eacp worth closing. See
README.md for the staged plan and the current gap ledger.

The project depends on eacp and nothing else; eacp is fetched via CPM.

## Build Commands

```bash
# Configure
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug -DSHADERTOY_UNITY_BUILD=OFF

# Build all targets
cmake --build build

# Build a specific target
cmake --build build --target Plasma
cmake --build build --target RuntimeTests
```

Outputs:
- `build/Tools/Transpile/shadertoy-transpile` (the converter)
- `build/Apps/Plasma/Plasma.app`, `build/Apps/PlasmaPort/PlasmaPort.app`
- `build/Tests/Glsl/GlslTests`, `build/Tests/Runtime/RuntimeTests`

### Build Options

- `SHADERTOY_UNITY_BUILD` (default `OFF`): unity-builds the libraries here.
  Claude must configure with `-DSHADERTOY_UNITY_BUILD=OFF` so per-file compile
  commands land in `compile_commands.json` and LSP tooling stays accurate.

### Local eacp source

eacp is fetched from `eyalamirmusic/eacp@main` by default. To work against a
local checkout — the usual case, since this project exists to find and fix gaps
in eacp — pass `-DCPM_eacp_SOURCE=$HOME/Code/eacp`. CPM honours
`CPM_<Name>_SOURCE` automatically.

```bash
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug -DSHADERTOY_UNITY_BUILD=OFF \
      -DCPM_eacp_SOURCE=$HOME/Code/eacp
```

Use `$HOME` (not `~`). CMake does not expand `~`, and shell tilde expansion is
suppressed inside quotes, so the build silently configures against a
non-existent path and fails later.

## Architecture

New source files are added directly to the module's CMakeLists.txt under the
appropriate `target_sources(...)` call.

The CMake helpers every target is configured with (`set_default_target_setting`,
`eacp_set_gui_subsystem`, `add_ide_sources`) come from eacp's own `CMake/`
directory, which the root CMakeLists puts on the module path after fetching it.
`eacp_default_setup()` reads the bundle plist template out of *this* project's
`CMake/`, which is why `macOSBundleInfo.plist.in` is vendored here.

### Front end (`Lib/shadertoy/Glsl`, `Lib/shadertoy/Emit`)

Target `shadertoy-glsl`. Portable C++ that reads text and produces text - it
links only `eacp-core`, never the GPU module, so the transpiler builds and runs
on a machine with no device.

- `Glsl/Lexer`: tokens, comments, object-like `#define` expansion.
- `Glsl/Parser`: a recursive-descent parser producing `Glsl::Shader` - an
  arena of `Expr` nodes referenced by index, mirroring eacp's `ShaderGraph`.
  It accepts a **wider** grammar than the emitter can lower, and recovers from
  what it cannot handle, so one shader reports every gap rather than the first.
- `Emit/CppEmitter`: `Glsl::Shader` -> a C++ header declaring one
  `Shadertoy::Ports::<Name> : Program`. Minimal parentheses, wrapped to 85
  columns.
- `Transpile.h`: the one entry point - source in, code plus diagnostics out.

A diagnostic names one missing capability (`intrinsic: atan`), never a place in
the file: they are counted across the corpus, and the counts rank the roadmap.

### Runtime (`Lib/shadertoy/Runtime`)

- `Program`: base for a ported shader. Owns everything the Shadertoy page
  supplies implicitly — the fullscreen triangle, the uniform set
  (`iResolution`, `iTime`, `iTimeDelta`, `iFrame`, `iMouse`), the clip-space
  position — so a port is the body of `mainImage` and nothing else. `compile()`
  must run from the most-derived constructor.
- `ShaderView`: a `GPUView` that runs one `Program` — drives the clock, follows
  the pointer, keeps `iResolution` in step with the view size, redraws every
  refresh. Disables MSAA, which a fullscreen shader cannot benefit from.
- `SHADERTOY_UNIFORMS(...)`: lists a port's extra uniform members, the way
  `EACP_SHADER` lists a plain `ShaderProgram`'s.

### Build integration

`shadertoy_add_port(<target> GLSL <file> NAME <Struct>)` converts a `.glsl` at
build time into the target's binary dir and puts it on the include path. It
fails the build when the shader needs something the EDSL cannot express; pass
`FORCE` to generate anyway. `Apps/PlasmaPort` is the worked example.

## Code Style

Matches eacp exactly — `.clang-format` and `.clang-tidy` are copies.

Always use the most modern C++ and RAII practices.
Use auto for variables and whenever possible.
Don't use auto for functions and member functions

Don't use comments unless absolutely needed. Use named functions to make code
self documenting.

Give std::function members a non-null default — a no-op lambda, or one
returning an empty value — so call sites invoke them directly without null
checks.

Enforced via `.clang-format`:
- Allman brace style
- 85 column limit
- 4-space indentation (no tabs)
- Pointer alignment: left (`int* ptr`)
- Break constructor initializers before comma

Always run clang-format for edited code files
