# The bookkeeping around the API: what a run asks for, what it refuses to ask
# for twice, and what it does with a budget of 1500 requests a month. The
# transport is a std::function, so none of it needs a key or a socket.
nano_add_executable(CorpusTests
        SOURCES
            FetchTests.cpp
        TARGETS shadertoy-corpus)
