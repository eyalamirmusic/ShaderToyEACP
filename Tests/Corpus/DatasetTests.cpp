#include <shadertoy/Corpus/Dataset.h>

#include <NanoTest/NanoTest.h>

#include <fstream>
#include <sstream>

using namespace nano;
using namespace Shadertoy;

namespace
{
// The rows endpoint, in the shape the real one answers in, without a socket. A
// row is one function of one shader, so the fixture below hands the same shader
// back several times over - which is the thing the paging has to get right and
// the reason a distinct count is not a row count.
struct FakeRows
{
    struct Row
    {
        std::string id;
        std::string author;
        std::string licence;
        std::string code;
        bool truncated = false;
    };

    Corpus::Reply operator()(const std::string& url)
    {
        requested.add(url);

        auto from = numberIn(url, "offset=");
        auto length = numberIn(url, "length=");
        auto text = std::string {};

        for (auto index = from; index < from + length && index < rows.size();
             ++index)
            text += (text.empty() ? "" : ",") + printed(rows[index]);

        return {200,
                R"({"rows":[)" + text + R"(],"num_rows_total":)"
                    + std::to_string(rows.size()) + "}",
                {}};
    }

    static std::string printed(const Row& row)
    {
        return R"({"row_idx":0,"row":{"id":")" + row.id + R"(","author":")"
               + row.author + R"(","license":")" + row.licence
               + R"(","image_code":")" + row.code + R"("},"truncated_cells":[)"
               + (row.truncated ? R"("image_code")" : "") + "]}";
    }

    static int numberIn(const std::string& url, const std::string& key)
    {
        auto at = url.find(key);

        if (at == std::string::npos)
            return 0;

        return std::stoi(url.substr(at + key.size()));
    }

    Corpus::Dataset::Vector<std::string> requested;
    Corpus::Dataset::Vector<Row> rows;
};

std::filesystem::path freshDirectory(const std::string& name)
{
    auto directory =
        std::filesystem::temp_directory_path() / "shadertoy-dataset" / name;

    std::filesystem::remove_all(directory);
    std::filesystem::create_directories(directory);

    return directory;
}

std::string read(const std::filesystem::path& path)
{
    auto file = std::ifstream(path);
    auto text = std::ostringstream {};

    text << file.rdbuf();

    return text.str();
}

bool contains(const std::string& haystack, std::string_view needle)
{
    return haystack.find(needle) != std::string::npos;
}

Corpus::Dataset::Fetcher fetcherFor(FakeRows& rows)
{
    auto fetcher = Corpus::Dataset::Fetcher {};

    fetcher.transport = [&rows](const std::string& url) { return rows(url); };
    fetcher.note = [](const std::string&) {};
    fetcher.warn = [](const std::string&) {};

    return fetcher;
}

Corpus::Dataset::Options optionsFor(const std::filesystem::path& directory)
{
    auto options = Corpus::Dataset::Options {};

    options.out = directory / "External";
    options.server = "https://example.invalid";
    options.pageSize = 2;

    return options;
}
} // namespace

// The whole point of the thing: the corpus every number in the README is
// measured over, in a handful of unauthenticated requests, with the id, the
// author and the licence beside each shader.
auto tWrites = test("Dataset/writesAShaderPerDistinctId") = []
{
    auto rows = FakeRows {};
    rows.rows.add({"lsfXWH", "iq", "mit", "void mainImage(){}"});
    rows.rows.add({"XsXXDn", "someone", "cc0-1.0", "void mainImage(){}"});

    auto options = optionsFor(freshDirectory("writes"));
    auto summary = fetcherFor(rows).run(options);

    check(summary.ok());
    check(summary.shaders == 2);
    check(summary.written == 2);

    auto shader = read(options.out / "lsfXWH.glsl");

    check(contains(shader, "// lsfXWH - iq"));
    check(contains(shader, "https://www.shadertoy.com/view/lsfXWH"));
    check(contains(shader, "licensed it mit"));
    check(contains(shader, "void mainImage(){}"));
};

// A row is a function and a shader is several of them, so the same id comes
// back once per function it was cut into. What the tables count is shaders.
auto tDistinct = test("Dataset/oneShaderPerIdHoweverManyRows") = []
{
    auto rows = FakeRows {};
    rows.rows.add({"lsfXWH", "iq", "mit", "the whole shader"});
    rows.rows.add({"lsfXWH", "iq", "mit", "the whole shader"});
    rows.rows.add({"lsfXWH", "iq", "mit", "the whole shader"});

    auto options = optionsFor(freshDirectory("distinct"));
    auto summary = fetcherFor(rows).run(options);

    check(summary.rows == 3);
    check(summary.shaders == 1);
    check(summary.written == 1);
};

// The split is longer than a page, and how long it is is something only the
// first answer says - so the paging is driven by what came back rather than by
// a number anybody configured.
auto tPages = test("Dataset/pagesUntilTheSplitRunsOut") = []
{
    auto rows = FakeRows {};

    for (auto index = 0; index < 5; ++index)
        rows.rows.add({"id" + std::to_string(index), "someone", "mit", "code"});

    auto options = optionsFor(freshDirectory("pages"));
    auto summary = fetcherFor(rows).run(options);

    check(summary.ok());
    check(summary.shaders == 5);

    // Five rows, two at a time, is three requests and the last one short.
    check(summary.requests == 3);
    check(rows.requested.size() == 3);
};

// The endpoint shortens a cell rather than refusing the row. A shader cut off
// mid-function still parses far enough to report gaps, so taking one would put
// a blocker in the coverage table that belongs to the transport - which is the
// one way this could quietly corrupt a measurement, and so the one thing that
// makes a run not ok().
auto tTruncated = test("Dataset/aTruncatedShaderIsNotAShader") = []
{
    auto rows = FakeRows {};
    rows.rows.add({"cutoff", "someone", "mit", "half a shad", true});

    auto options = optionsFor(freshDirectory("truncated"));
    auto summary = fetcherFor(rows).run(options);

    check(!summary.ok());
    check(summary.incomplete == 1);
    check(summary.written == 0);
    check(!std::filesystem::exists(options.out / "cutoff.glsl"));
};

// One complete copy is enough, whichever row it arrived in.
auto tTruncatedTwice = test("Dataset/acompleteRowRescuesATruncatedOne") = []
{
    auto rows = FakeRows {};
    rows.rows.add({"lsfXWH", "iq", "mit", "half a shad", true});
    rows.rows.add({"lsfXWH", "iq", "mit", "the whole shader"});

    auto options = optionsFor(freshDirectory("rescued"));
    auto summary = fetcherFor(rows).run(options);

    check(summary.ok());
    check(summary.written == 1);
    check(contains(read(options.out / "lsfXWH.glsl"), "the whole shader"));
};

// The licence is what decides whether a shader may ever be committed here or
// only measured, so it is recorded for the directory rather than only in the
// file it came with - and a run that saw half the dataset does not forget what
// an earlier one knew about the other half.
auto tLicences = test("Dataset/theLicenceLedgerAccretes") = []
{
    auto directory = freshDirectory("licences");
    auto options = optionsFor(directory);

    auto first = FakeRows {};
    first.rows.add({"lsfXWH", "iq", "mit", "code"});

    fetcherFor(first).run(options);

    auto second = FakeRows {};
    second.rows.add({"XsXXDn", "blackle", "cc0-1.0", "code"});

    fetcherFor(second).run(options);

    auto ledger = read(options.out / ".licences");

    check(contains(ledger, "lsfXWH  mit  iq"));
    check(contains(ledger, "XsXXDn  cc0-1.0  blackle"));
};

// A second run over a directory that already has the shaders writes nothing,
// which is what makes rerunning the measurement free.
auto tDatasetResume = test("Dataset/resumeWritesNothingItHas") = []
{
    auto rows = FakeRows {};
    rows.rows.add({"lsfXWH", "iq", "mit", "code"});

    auto options = optionsFor(freshDirectory("resume"));

    check(fetcherFor(rows).run(options).written == 1);

    auto second = fetcherFor(rows).run(options);

    check(second.written == 0);
    check(second.alreadyHad == 1);
    check(second.ok());
};

// --rows takes the front of the split rather than an arbitrary slice, and asks
// for no more than it was told to.
auto tLimit = test("Dataset/aLimitedRunTakesTheFrontOfTheSplit") = []
{
    auto rows = FakeRows {};

    for (auto index = 0; index < 6; ++index)
        rows.rows.add({"id" + std::to_string(index), "someone", "mit", "code"});

    auto options = optionsFor(freshDirectory("limit"));
    options.limit = 3;

    auto summary = fetcherFor(rows).run(options);

    check(summary.rows == 3);
    check(summary.shaders == 3);
    check(std::filesystem::exists(options.out / "id0.glsl"));
    check(!std::filesystem::exists(options.out / "id5.glsl"));
};

// --dataset with no name means the corpus the tables here are measured over,
// which is the whole reason it takes one at all.
auto tDatasetOptions = test("Dataset/theDefaultIsTheMeasuredCorpus") = []
{
    auto bare = Corpus::Dataset::parseOptions({"--dataset"});

    check(bare.requested);
    check(bare.valid);
    check(bare.name == "Vipitis/Shadereval-inputs");

    auto named = Corpus::Dataset::parseOptions({"--dataset", "someone/else"});

    check(named.requested);
    check(named.name == "someone/else");

    // A command line without --dataset is not a dataset run whatever else is
    // on it, which is what keeps a typo from fetching the default corpus.
    auto other = Corpus::Dataset::parseOptions({"--list", "500"});

    check(!other.requested);
};
