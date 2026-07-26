add_library(shadertoy-runtime STATIC)
target_include_directories(shadertoy-runtime PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../)

target_link_libraries(shadertoy-runtime PUBLIC eacp-gpu)

target_sources(shadertoy-runtime PRIVATE
        Runtime/ShaderView.cpp)

set_default_target_setting(shadertoy-runtime)
shadertoy_enable_unity_build(shadertoy-runtime)
add_ide_sources(shadertoy-runtime)
