nano_add_executable(RuntimeTests
        NO_MAIN
        SOURCES
            ProgramTests.cpp
            PortTests.cpp
            TestMain.cpp
        TARGETS shadertoy-runtime)

# The corpus shaders stage 2 was built for, converted by the build and compiled
# here. A header the transpiler is happy with but the EDSL will not take is a
# real failure mode, and the only thing that catches it is a compiler.
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Fbm.glsl NAME Fbm)
shadertoy_add_port(RuntimeTests GLSL ${CMAKE_CURRENT_LIST_DIR}/../../Corpus/Voronoi.glsl NAME Voronoi)
