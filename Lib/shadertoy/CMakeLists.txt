# The GLSL front end and the C++ emitter. Portable C++ that reads text and
# produces text: no GPU, no window, no eacp graphics module, so the transpiler
# runs as a build step on a machine with no device at all.
add_library(shadertoy-glsl STATIC)
target_include_directories(shadertoy-glsl PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../)

target_link_libraries(shadertoy-glsl PUBLIC eacp-core)

target_sources(shadertoy-glsl PRIVATE
        Glsl/Lexer.cpp
        Glsl/Parser.cpp
        Emit/CppEmitter.cpp
        Transpile.cpp)

set_default_target_setting(shadertoy-glsl)
shadertoy_enable_unity_build(shadertoy-glsl)

# What a ported shader runs inside.
add_library(shadertoy-runtime STATIC)
target_include_directories(shadertoy-runtime PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../)

target_link_libraries(shadertoy-runtime PUBLIC eacp-gpu)

target_sources(shadertoy-runtime PRIVATE
        Runtime/ShaderView.cpp)

set_default_target_setting(shadertoy-runtime)
shadertoy_enable_unity_build(shadertoy-runtime)
add_ide_sources(shadertoy-runtime)
