nano_add_executable(RuntimeTests
        NO_MAIN
        SOURCES
            ChannelTests.cpp
            ProgramTests.cpp
            PortTests.cpp
            TestMain.cpp
        TARGETS shadertoy-runtime)

# The corpus shaders that convert cleanly, transpiled by the build and compiled
# here. A header the transpiler is happy with but the EDSL will not take is a
# real failure mode, and the only thing that catches it is a compiler.
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Fbm.glsl NAME Fbm)
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Voronoi.glsl NAME Voronoi)

# Stage 3's vocabulary: mod and a reordered swizzle in Checker, and mat2, atan2,
# exp, rsqrt, sign and four-component swizzles in Kaleido.
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Checker.glsl NAME Checker)
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Kaleido.glsl NAME Kaleido)

# Stage 4: one channel sampled the ordinary way in Tunnel, and all three reads
# plus iChannelResolution across two channels in Channels.
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Tunnel.glsl NAME Tunnel)
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Channels.glsl NAME Channels)
