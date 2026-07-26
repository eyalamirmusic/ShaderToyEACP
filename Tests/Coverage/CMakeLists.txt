# Both coverage tables over a corpus of two or three shaders: what converted,
# what a compiler then said about it, and which row two shaders that failed the
# same way agree on. The compiler is a std::function, so none of it needs a
# toolchain.
nano_add_executable(CoverageTests
        SOURCES
            CoverageTests.cpp
        TARGETS shadertoy-coverage)
