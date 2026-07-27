add_executable(shadertoy-scan Main.cpp)

# The tabulation lives in the library beside the transpiler's; this is the
# command line around it, and the one part that needs a toolchain.
target_link_libraries(shadertoy-scan PRIVATE shadertoy-coverage eacp-core)

set_default_target_setting(shadertoy-scan)

# The whole command line a generated port is compiled with, written by the build
# rather than guessed at by the tool. The include path a port sees is the one
# the runtime publishes, transitively, and how to spell "check this and compile
# nothing" is a fact about the driver: both are the build's to know.
#
# The driver is the half that used to be guessed, and it is the expensive one to
# get wrong. clang-cl answers to a CXX_COMPILER_ID of Clang and parses cl's
# command line, so a GCC-style flag handed to it is dropped with a warning
# rather than refused - and a dropped -std=c++20 is a compiler running at its
# default standard, which rejects every port in the corpus and reports it as a
# corpus that does not compile. Coverage::checkCompiler catches that now; this
# is what stops it happening.
#
# One flag per line, so a path with a space in it stays one flag, and a file
# rather than a compile definition because these are generator expressions -
# known when the build tree is generated, not when this file is configured.

# A port is a header declaring one struct whose member functions are all defined
# inline, so type-checking the header is the whole compile: there is nothing to
# instantiate and nothing to link. Syntax-only is what makes scanning a corpus
# take minutes rather than an hour.
#
# /TP because a port is a .h and cl decides the language from the extension, and
# /EHsc because CMake puts it in the flags every target here is compiled with -
# without it a `catch` in a header a port reaches is an error and not a shader.
if (MSVC)
    set(scan_probe /std:c++${CMAKE_CXX_STANDARD} /TP /EHsc /Zs)
else ()
    set(scan_probe -std=c++${CMAKE_CXX_STANDARD} -x c++ -fsyntax-only)
endif ()

# The diagnostics the tables are built from: no caret art and no colour, so a
# message stays one line, and every error rather than the first twenty, so a
# shader is ranked by everything blocking it. Clang's spellings tunnel through
# /clang: when the driver is cl's, which is exactly where they would be dropped.
if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(scan_diagnostics
            -fno-caret-diagnostics
            -fno-color-diagnostics
            -fshow-overloads=best
            -ferror-limit=0)

    if (MSVC)
        list(TRANSFORM scan_diagnostics PREPEND "/clang:")
    endif ()
elseif (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(scan_diagnostics
            -fno-diagnostics-show-caret
            -fno-diagnostics-color
            -fmax-errors=0)
else ()
    set(scan_diagnostics "")
endif ()

list(APPEND scan_probe ${scan_diagnostics})
list(JOIN scan_probe "\n" scan_probe_lines)

# What the runtime is compiled with, beside where it is compiled from. A port
# is the same C++ the target that consumes it compiles, so a definition the
# runtime carries and this does not is a scan measuring something the build
# never builds.
set(runtime_definitions "$<TARGET_PROPERTY:shadertoy-runtime,COMPILE_DEFINITIONS>")

set(scan_flags "${CMAKE_CURRENT_BINARY_DIR}/ScanFlags.txt")

file(GENERATE
        OUTPUT "${scan_flags}"
        CONTENT
        "${scan_probe_lines}\n\
-I$<JOIN:$<TARGET_PROPERTY:shadertoy-runtime,INCLUDE_DIRECTORIES>,\n-I>\n\
$<$<BOOL:${runtime_definitions}>:-D$<JOIN:${runtime_definitions},\n-D>\n>\
$<$<BOOL:${CMAKE_OSX_SYSROOT}>:-isysroot\n${CMAKE_OSX_SYSROOT}\n>")

target_compile_definitions(shadertoy-scan PRIVATE
        SHADERTOY_SCAN_COMPILER="${CMAKE_CXX_COMPILER}"
        SHADERTOY_SCAN_FLAGS="${scan_flags}")
