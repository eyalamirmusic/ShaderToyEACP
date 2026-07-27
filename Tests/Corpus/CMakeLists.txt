# The bookkeeping around the corpus: paging the published dataset, keeping the
# first complete copy of each id, and never rewriting what is already there. The
# transport is a std::function, so none of it needs a socket.
nano_add_executable(CorpusTests
        SOURCES
            DatasetTests.cpp
        TARGETS shadertoy-corpus)
