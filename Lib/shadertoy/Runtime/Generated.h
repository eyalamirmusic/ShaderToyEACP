#pragma once

// What a generated port is wrapped in.
//
// A transpiled body keeps every local the GLSL declared, including the ones the
// shader never reads again: a value computed for a branch that folded away, an
// out parameter an inlined helper wrote and its caller ignored, a term left
// behind while somebody was editing on the page. They are what the shader says,
// so the port says them too - and a compiler pointing at each one would be
// pointing at the corpus, not at anything a reader of the generated file can do
// something about. The corpus is measured by what converts and then compiles;
// unread locals are neither.
//
// Scoped to the generated header rather than set on the targets that include
// one, so an app's own unused local is still the mistake it was.
#if defined(_MSC_VER) && !defined(__clang__)
#define SHADERTOY_BEGIN_GENERATED                                                   \
    __pragma(warning(push)) __pragma(warning(disable : 4189 4101))
#define SHADERTOY_END_GENERATED __pragma(warning(pop))
#else
#define SHADERTOY_BEGIN_GENERATED                                                   \
    _Pragma("GCC diagnostic push")                                                  \
        _Pragma("GCC diagnostic ignored \"-Wunused-variable\"")
#define SHADERTOY_END_GENERATED _Pragma("GCC diagnostic pop")
#endif
