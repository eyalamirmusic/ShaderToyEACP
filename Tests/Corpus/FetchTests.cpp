#include <shadertoy/Corpus/Fetch.h>

#include <NanoTest/NanoTest.h>

#include <fstream>
#include <map>
#include <sstream>

using namespace nano;
using namespace Shadertoy;

namespace
{
// The API, in the shape the real one answers in, without a key or a socket. A
// run's whole job is deciding what to ask for, so what a test asserts on is
// mostly this: which urls arrived, and how few of them there were.
struct FakeApi
{
    Corpus::Reply operator()(const std::string& url)
    {
        requested.add(url);

        if (url.find("num=") != std::string::npos)
            return {200, index, {}};

        auto found = shaders.find(idOf(url));

        return found != shaders.end()
                   ? Corpus::Reply {200, found->second, {}}
                   : Corpus::Reply {200, R"({"Error":"Shader not found"})", {}};
    }

    static std::string idOf(const std::string& url)
    {
        auto stem = url.substr(0, url.find('?'));

        return stem.substr(stem.find_last_of('/') + 1);
    }

    int askedFor(const std::string& id) const
    {
        auto count = 0;

        for (const auto& url: requested)
            if (idOf(url) == id)
                ++count;

        return count;
    }

    Corpus::Vector<std::string> requested;
    std::map<std::string, std::string> shaders;
    std::string index;
};

std::string singlePass(const std::string& id)
{
    return R"({"Shader":{"ver":"0.1","info":{"id":")" + id
           + R"(","name":"A Toy","username":"someone"},)"
             R"("renderpass":[{"type":"image","name":"Image","inputs":[],)"
             R"("code":"void mainImage(out vec4 f, in vec2 c){ f = vec4(1.0); }"}]}})";
}

// The shape the runtime half of the corpus cares about: a prelude every pass
// shares, a buffer pass beside the image one, and a channel the port has to be
// told about.
std::string multiPass(const std::string& id)
{
    return R"({"Shader":{"ver":"0.1","info":{"id":")" + id
           + R"(","name":"A Trail","username":"someone"},"renderpass":[)"
             R"({"type":"common","name":"Common","inputs":[],)"
             R"("code":"#define TAU 6.28\n"},)"
             R"({"type":"image","name":"Image","inputs":[)"
             R"({"channel":0,"ctype":"buffer","src":"/media/previz/buffer00.png"}],)"
             R"("code":"void mainImage(out vec4 f, in vec2 c){ f = vec4(2.0); }"},)"
             R"({"type":"buffer","name":"Buf A","inputs":[],)"
             R"("code":"void mainImage(out vec4 f, in vec2 c){ f = vec4(3.0); }"}]}})";
}

std::string indexOf(const Corpus::Vector<std::string>& ids)
{
    auto text = R"({"Shaders":)" + std::to_string(ids.size()) + R"(,"Results":[)";

    for (auto index = 0; index < ids.size(); ++index)
        text += (index > 0 ? "," : "") + ("\"" + ids[index] + "\"");

    return text + "]}";
}

std::filesystem::path freshDirectory(const std::string& name)
{
    auto path = std::filesystem::temp_directory_path() / ("shadertoy-" + name);

    std::filesystem::remove_all(path);
    std::filesystem::create_directories(path);

    return path;
}

void write(const std::filesystem::path& path, const std::string& text)
{
    auto file = std::ofstream(path);
    file << text;
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

// A fetcher wired to the fake, with the clock pinned and the logs silenced, so
// that what a test reads is the summary and the files rather than the console.
Corpus::Fetcher fetcherFor(FakeApi& api, const std::string& date = "2026-07-26")
{
    auto fetcher = Corpus::Fetcher {};

    fetcher.transport = [&api](const std::string& url) { return api(url); };
    fetcher.date = [date] { return date; };
    fetcher.note = [](const std::string&) {};
    fetcher.warn = [](const std::string&) {};

    return fetcher;
}

Corpus::Options optionsFor(const std::filesystem::path& directory)
{
    auto options = Corpus::Options {};

    options.out = directory / "External";
    options.idsFile = directory / "ids.txt";
    options.api = "https://example.invalid/api/v1/shaders";
    options.key = "test-key";
    options.delayMs = 0;

    return options;
}
} // namespace

// Every pass is a file, the common pass is a prelude in each of them rather
// than a file of its own, and the licence note and the channel list are what
// the header says - which is the whole of what a port needs and the source
// does not carry.
auto tPasses = test("Corpus/writesEveryPass") = []
{
    auto directory = freshDirectory("passes");
    auto api = FakeApi {};
    api.shaders["XsXXDn"] = multiPass("XsXXDn");

    auto options = optionsFor(directory);
    options.ids.add("XsXXDn");

    auto summary = fetcherFor(api).run(options);

    check(summary.ok());
    check(summary.fetched == 1);

    auto image = read(options.out / "XsXXDn.glsl");
    auto buffer = read(options.out / "XsXXDn-BufA.glsl");

    check(contains(image, "#define TAU"));
    check(contains(buffer, "#define TAU"));
    check(contains(image, "f = vec4(2.0)"));
    check(contains(buffer, "f = vec4(3.0)"));

    check(contains(image, "// A Trail - someone"));
    check(contains(image, "https://www.shadertoy.com/view/XsXXDn"));
    check(contains(image, "CC BY-NC-SA 3.0"));
    check(contains(image, "iChannel0: buffer"));

    // The common pass is the prelude and never a file.
    check(!std::filesystem::exists(options.out / "XsXXDn-Common.glsl"));
};

// The API answers a shader it will not serve with a 200 and an Error in the
// body, which is how the wrapper around the shader is told apart from the
// refusal that replaces it.
auto tEnvelope = test("Corpus/unwrapsTheShaderEnvelope") = []
{
    auto directory = freshDirectory("envelope");
    auto api = FakeApi {};
    api.shaders["Ms2SD1"] = singlePass("Ms2SD1");

    auto options = optionsFor(directory);
    options.ids.add("Ms2SD1");

    check(fetcherFor(api).run(options).fetched == 1);
    check(contains(read(options.out / "Ms2SD1.glsl"), "f = vec4(1.0)"));
};

// The point of the whole exercise: what a run already has costs nothing to run
// again. 1500 requests a month is the budget, and refetching is the one way to
// spend it on nothing.
auto tResume = test("Corpus/resumeAsksForNothingItHas") = []
{
    auto directory = freshDirectory("resume");
    auto api = FakeApi {};
    api.shaders["XsXXDn"] = singlePass("XsXXDn");

    auto options = optionsFor(directory);
    options.ids.add("XsXXDn");

    auto first = fetcherFor(api).run(options);
    auto second = fetcherFor(api).run(options);

    check(first.fetched == 1);
    check(second.fetched == 0);
    check(second.alreadyHad == 1);
    check(second.ok());

    check(api.askedFor("XsXXDn") == 1);
    check(second.spent == 1);
};

// A shader that is not Public+API stays that way, so the refusal is worth
// remembering: at corpus scale most of a list will refuse, and asking again
// next month would spend the budget on the same answer.
auto tRefusals = test("Corpus/refusalIsRememberedNotRepeated") = []
{
    auto directory = freshDirectory("refusals");
    auto api = FakeApi {};

    auto options = optionsFor(directory);
    options.ids.add("Private");

    auto first = fetcherFor(api).run(options);

    check(first.refused == 1);
    check(first.fetched == 0);
    check(contains(read(options.out / ".refused"), "Private"));
    check(contains(read(options.out / ".refused"), "Shader not found"));

    auto second = fetcherFor(api).run(options);

    check(second.skippedRefused == 1);
    check(api.askedFor("Private") == 1);
    check(second.spent == 1);

    // Until asked to try again - and a shader whose author has since opened it
    // up drops off the list rather than staying on it.
    api.shaders["Private"] = singlePass("Private");

    auto retried = options;
    retried.retryRefused = true;

    check(fetcherFor(api).run(retried).fetched == 1);
    check(!contains(read(options.out / ".refused"), "Private"));
};

// The budget is a hard stop, it is remembered between runs, and what it did
// not reach stays on the list - which is what makes a corpus that is bigger
// than one month's requests possible at all.
auto tBudget = test("Corpus/budgetStopsTheRunAndSurvivesIt") = []
{
    auto directory = freshDirectory("budget");
    auto api = FakeApi {};
    auto ids = Corpus::Vector<std::string> {};

    for (const auto* id: {"AaaAaa", "BbbBbb", "CccCcc", "DddDdd", "EeeEee"})
    {
        api.shaders[id] = singlePass(id);
        ids.add(id);
    }

    auto options = optionsFor(directory);
    options.ids = ids;
    options.budget = 2;

    auto first = fetcherFor(api).run(options);

    check(first.fetched == 2);
    check(first.leftToDo == 3);
    check(!first.ok());
    check(first.remaining == 0);

    // The same budget, a second run, and nothing left to spend: the ledger is
    // a file and not a counter that resets when the process does.
    auto second = fetcherFor(api).run(options);

    check(second.fetched == 0);
    check(second.spent == 2);
    check(api.requested.size() == 2);

    // A new month is a new budget: the same two-request allowance spends
    // again, on the ids the first month never reached.
    auto later = fetcherFor(api, "2026-08-02").run(options);

    check(later.fetched == 2);
    check(later.spent == 2);
    check(later.leftToDo == 1);

    // And the ledger keeps the month it left behind rather than forgetting it.
    auto ledger = read(options.out / ".quota");

    check(contains(ledger, "2026-07 2"));
    check(contains(ledger, "2026-08 2"));
};

// Discovery is one request however many ids come back, and it adds to the list
// rather than replacing it: the hand-picked entries at the top of ids.txt are
// somebody's choice, and the file is the committed record of what was
// measured.
auto tDiscovery = test("Corpus/discoveryMergesIntoTheList") = []
{
    auto directory = freshDirectory("discovery");
    auto api = FakeApi {};
    api.index = indexOf({"Kept", "AaaAaa", "BbbBbb"});

    auto options = optionsFor(directory);
    options.discover = 3;
    options.idsOnly = true;

    write(options.idsFile,
          "# a list somebody wrote\nKept   # the one already here\n");

    auto summary = fetcherFor(api).run(options);

    check(summary.discovered == 2);
    check(summary.spent == 1);
    check(api.requested.size() == 1);

    auto list = read(options.idsFile);

    check(contains(list, "# a list somebody wrote"));
    // The line says what it added, not what came back.
    check(contains(list, "2 ids from the index, 2026-07-26"));
    check(contains(list, "AaaAaa"));
    check(contains(list, "BbbBbb"));

    // Added once, however often the index names it.
    check(list.find("Kept") == list.rfind("Kept"));

    // --ids-only stops before spending the budget on shaders.
    check(!std::filesystem::exists(options.out / "AaaAaa.glsl"));
};

auto tSearchUrl = test("Corpus/searchIsAskedInTheApisOwnVocabulary") = []
{
    auto directory = freshDirectory("search");
    auto api = FakeApi {};
    api.index = indexOf({});

    auto options = optionsFor(directory);
    options.query = "raymarching plasma";
    options.sort = "newest";
    options.filter = "multipass";
    options.discover = 25;
    options.idsOnly = true;

    fetcherFor(api).run(options);

    check(api.requested.size() == 1);

    const auto& url = api.requested[0];

    check(contains(url, "/query/raymarching%20plasma?"));
    check(contains(url, "num=25"));
    check(contains(url, "sort=newest"));
    check(contains(url, "filter=multipass"));
};

// A request the API never answered cost nothing, so counting it would throw
// away requests the key still has - and a network that is down does not come
// back up halfway through a list.
auto tFailures = test("Corpus/networkFailuresSpendNothingAndStop") = []
{
    auto directory = freshDirectory("failures");
    auto api = FakeApi {};

    auto fetcher = fetcherFor(api);
    fetcher.transport = [&api](const std::string& url)
    {
        api.requested.add(url);
        return Corpus::Reply {403, {}, {}};
    };

    auto options = optionsFor(directory);
    options.ids.add("AaaAaa");
    options.ids.add("BbbBbb");
    options.ids.add("CccCcc");
    options.ids.add("DddDdd");

    auto summary = fetcher.run(options);

    check(!summary.ok());
    check(summary.failed == 3);
    check(summary.spent == 0);
    check(summary.leftToDo == 1);
    check(api.requested.size() == 3);

    // Nothing permanent was learned about them, so nothing was written down.
    check(!std::filesystem::exists(options.out / ".refused"));
};

// A key the API will not take is answered where a private shader is, and the
// ledger is written to disk: mistaking one for the other would strike every id
// on the list off permanently over one bad environment variable.
auto tBadKey = test("Corpus/aBadKeyIsNotTheShadersFault") = []
{
    auto directory = freshDirectory("badkey");
    auto api = FakeApi {};

    auto fetcher = fetcherFor(api);
    fetcher.transport = [&api](const std::string& url)
    {
        api.requested.add(url);
        return Corpus::Reply {200, R"({"Error":"Invalid key"})", {}};
    };

    auto options = optionsFor(directory);
    options.ids.add("AaaAaa");
    options.ids.add("BbbBbb");
    options.ids.add("CccCcc");

    auto summary = fetcher.run(options);

    check(!summary.ok());
    check(summary.failed == 1);
    check(summary.refused == 0);
    check(summary.leftToDo == 2);

    // Asked once, and nothing written down about any of them.
    check(api.requested.size() == 1);
    check(!std::filesystem::exists(options.out / ".refused"));
};

auto tOptions = test("Corpus/optionsAreParsed") = []
{
    auto options = Corpus::parseOptions({"--list",
                                         "500",
                                         "--sort",
                                         "newest",
                                         "--budget",
                                         "40",
                                         "--ids-only",
                                         "XsXXDn"});

    check(options.valid);
    check(options.discover == 500);
    check(options.sort == "newest");
    check(options.budget == 40);
    check(options.idsOnly);
    check(options.ids.size() == 1);

    check(!Corpus::parseOptions({"--list", "many"}).valid);
    check(!Corpus::parseOptions({"--list", "-5"}).valid);
    check(!Corpus::parseOptions({"--nonsense"}).valid);

    // A search with no count would otherwise discover nothing and quietly
    // fetch the whole list instead.
    check(Corpus::parseOptions({"--query", "plasma"}).discover > 0);
};
