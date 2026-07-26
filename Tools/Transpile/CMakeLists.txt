add_executable(shadertoy-transpile Main.cpp)
target_link_libraries(shadertoy-transpile PRIVATE shadertoy-glsl)

set_default_target_setting(shadertoy-transpile)
