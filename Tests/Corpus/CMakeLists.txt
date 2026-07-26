# The bookkeeping around both corpora: what a run asks the API for, what it
# refuses to ask for twice, and what it does with a budget of 1500 requests a
# month; and the paging over the published dataset that wants no key at all.
# Both transports are a std::function, so none of it needs a key or a socket.
nano_add_executable(CorpusTests
        SOURCES
            FetchTests.cpp
            DatasetTests.cpp
        TARGETS shadertoy-corpus)
