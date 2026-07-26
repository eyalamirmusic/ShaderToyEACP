# Pure logic: text in, text out. No device, no window, so these run anywhere.
nano_add_executable(GlslTests
        SOURCES
            TranspileTests.cpp
        TARGETS shadertoy-glsl)
