# The GLSL front end and the C++ emitter. Portable C++ that reads text and
# produces text: no GPU, no window, no eacp graphics module, so the transpiler
# runs as a build step on a machine with no device at all.
add_library(shadertoy-glsl STATIC)
target_include_directories(shadertoy-glsl PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../)

target_link_libraries(shadertoy-glsl PUBLIC eacp-core)

target_sources(shadertoy-glsl PRIVATE
        Glsl/Lexer.cpp
        Glsl/Parser.cpp
        Glsl/Lower.cpp
        Emit/CppEmitter.cpp
        Transpile.cpp)

set_default_target_setting(shadertoy-glsl)
shadertoy_enable_unity_build(shadertoy-glsl)

# Pulling Shadertoys off the API and keeping the books that a 1500-request
# month makes necessary. It is the one library here that talks to anything, and
# the transport is a std::function so that a test can drive the bookkeeping
# without a key and without a socket.
add_library(shadertoy-corpus STATIC)
target_include_directories(shadertoy-corpus PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../)

# eacp-core is in the header, for the Vector the options are held in; the HTTP
# client is not, which is what lets a test link this and never open a socket.
target_link_libraries(shadertoy-corpus PUBLIC eacp-core PRIVATE eacp-network)

target_sources(shadertoy-corpus PRIVATE
        Corpus/Transport.cpp
        Corpus/Fetch.cpp
        Corpus/Dataset.cpp)

set_default_target_setting(shadertoy-corpus)
shadertoy_enable_unity_build(shadertoy-corpus)

# Both coverage tables over one corpus: what does not convert, and what
# converts and then does not compile. The compile step is a std::function, so
# this library needs no toolchain and a test can drive the tabulation over
# whatever a compiler is pretended to have said.
add_library(shadertoy-coverage STATIC)
target_include_directories(shadertoy-coverage PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../)

target_link_libraries(shadertoy-coverage PUBLIC shadertoy-glsl)

target_sources(shadertoy-coverage PRIVATE
        Coverage/Coverage.cpp)

set_default_target_setting(shadertoy-coverage)
shadertoy_enable_unity_build(shadertoy-coverage)

# What a ported shader runs inside.
add_library(shadertoy-runtime STATIC)
target_include_directories(shadertoy-runtime PUBLIC ${CMAKE_CURRENT_LIST_DIR}/../)

target_link_libraries(shadertoy-runtime PUBLIC eacp-gpu)

target_sources(shadertoy-runtime PRIVATE
        Runtime/ShaderView.cpp)

set_default_target_setting(shadertoy-runtime)
shadertoy_enable_unity_build(shadertoy-runtime)
add_ide_sources(shadertoy-runtime)
