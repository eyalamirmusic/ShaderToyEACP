add_executable(shadertoy-scan Main.cpp)

# The tabulation lives in the library beside the transpiler's; this is the
# command line around it, and the one part that needs a toolchain.
target_link_libraries(shadertoy-scan PRIVATE shadertoy-coverage eacp-core)

set_default_target_setting(shadertoy-scan)

# What a generated port is compiled against, written by the build rather than
# guessed at by the tool: the include path a port sees is the one the runtime
# publishes, transitively, and only the build knows what that came to.
#
# One flag per line, so a path with a space in it stays one flag, and a file
# rather than a compile definition because these are generator expressions -
# known when the build tree is generated, not when this file is configured.
set(scan_flags "${CMAKE_CURRENT_BINARY_DIR}/ScanFlags.txt")

file(GENERATE
        OUTPUT "${scan_flags}"
        CONTENT
        "-std=c++${CMAKE_CXX_STANDARD}\n\
-I$<JOIN:$<TARGET_PROPERTY:shadertoy-runtime,INCLUDE_DIRECTORIES>,\n-I>\n\
$<$<BOOL:${CMAKE_OSX_SYSROOT}>:-isysroot\n${CMAKE_OSX_SYSROOT}\n>")

target_compile_definitions(shadertoy-scan PRIVATE
        SHADERTOY_SCAN_COMPILER="${CMAKE_CXX_COMPILER}"
        SHADERTOY_SCAN_FLAGS="${scan_flags}")
