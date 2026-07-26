add_executable(shadertoy-fetch Main.cpp)

# The fetching lives in the library beside the transpiler's; this is the
# command line around it. shadertoy-corpus is the one thing here that talks to
# anything: the transpiler beside it reads text and writes text, and links
# neither.
target_link_libraries(shadertoy-fetch PRIVATE shadertoy-corpus)

set_default_target_setting(shadertoy-fetch)
