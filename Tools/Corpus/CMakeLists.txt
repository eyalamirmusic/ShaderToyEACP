add_executable(shadertoy-fetch Main.cpp)

# The fetching lives in the library beside the transpiler's; this is the
# command line around it. shadertoy-corpus is the one thing here that talks to
# anything: the transpiler beside it reads text and writes text, and links
# neither.
target_link_libraries(shadertoy-fetch PRIVATE shadertoy-corpus)

set_default_target_setting(shadertoy-fetch)

# Growing the committed corpus, rather than acquiring it: the shaders are in the
# repository, so nothing in a normal build runs this. It re-reads the dataset
# and writes only what is not already there, which is why running it on a clone
# that is up to date costs five requests and changes nothing.
#
# Not a dependency of anything on purpose. A build that reaches the network is a
# build that fails when the network does, and the corpus it would have fetched
# is already on disk.
add_custom_target(corpus-fetch
        COMMAND shadertoy-fetch --dataset --out
                "${CMAKE_SOURCE_DIR}/Corpus/External"
        COMMENT "Fetching any shaders the committed corpus does not have"
        VERBATIM
        USES_TERMINAL)

add_dependencies(corpus-fetch shadertoy-fetch)
