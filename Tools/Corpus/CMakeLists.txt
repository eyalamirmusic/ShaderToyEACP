add_executable(shadertoy-fetch Main.cpp)

# eacp-network for the request and eacp-core's Miro for the reply. The corpus
# fetcher is the one thing here that talks to anything: the transpiler beside it
# reads text and writes text, and links neither.
target_link_libraries(shadertoy-fetch PRIVATE eacp-network)

set_default_target_setting(shadertoy-fetch)
