#include "Fetch.h"

#include "Json.h"

#include <charconv>
#include <filesystem>
#include <fstream>
#include <map>
#include <thread>

namespace Shadertoy::Corpus
{
namespace
{
std::string monthOf(const std::string& date)
{
    return date.substr(0, date.find_last_of('-'));
}

bool toInt(std::string_view text, int& into)
{
    const auto* end = text.data() + text.size();

    return std::from_chars(text.data(), end, into).ptr == end;
}

// One id per line, with everything after a # a comment - so the file can say
// which shader each id is without the fetcher having to care.
Vector<std::string> readIds(const std::filesystem::path& path)
{
    auto ids = Vector<std::string> {};
    auto file = std::ifstream(path);

    for (std::string line; std::getline(file, line);)
    {
        line = line.substr(0, line.find('#'));

        auto first = line.find_first_not_of(" \t\r");

        if (first == std::string::npos)
            continue;

        ids.add(line.substr(first, line.find_last_not_of(" \t\r") + 1 - first));
    }

    return ids;
}

// Ids the index handed over, appended under a line saying where they came from
// and when. Appended rather than written, because the list is the committed
// record of what was measured and the hand-picked entries at the top of it are
// somebody's choice.
int appendIds(const std::filesystem::path& path,
              const Vector<std::string>& ids,
              const std::string& source,
              const std::string& date)
{
    auto existing = readIds(path);
    auto fresh = Vector<std::string> {};

    for (const auto& id: ids)
        if (!existing.contains(id) && !fresh.contains(id))
            fresh.add(id);

    if (fresh.empty())
        return 0;

    auto file = std::ofstream(path, std::ios::app);

    if (!file)
        return 0;

    file << "\n# " << fresh.size() << " ids from " << source << ", " << date << "\n";

    for (const auto& id: fresh)
        file << id << "\n";

    return fresh.size();
}

// What a key has spent, by month, in a file beside the shaders it bought. It
// is a local mirror of a count only Shadertoy really keeps, so it errs high:
// anything the API answered is counted, whether or not the answer was a
// shader.
struct MonthlyQuota
{
    int remaining() const
    {
        auto left = budget - spentThisMonth();
        return left > 0 ? left : 0;
    }

    int spentThisMonth() const
    {
        auto found = byMonth.find(month);
        return found != byMonth.end() ? found->second : 0;
    }

    void spend()
    {
        ++byMonth[month];
        write();
    }

    void write() const
    {
        auto file = std::ofstream(path);

        if (!file)
            return;

        file << "# Requests spent against the API key, by month. Shadertoy\n"
             << "# grants 1500 a month; this is what that budget is measured\n"
             << "# against between runs, and it does not survive being moved\n"
             << "# away from the shaders it bought.\n";

        for (const auto& [key, count]: byMonth)
            file << key << " " << count << "\n";
    }

    std::filesystem::path path;
    std::string month;
    int budget = 0;
    std::map<std::string, int> byMonth;
};

MonthlyQuota loadQuota(const std::filesystem::path& path,
                       const std::string& month,
                       int budget)
{
    auto quota = MonthlyQuota {path, month, budget, {}};
    auto file = std::ifstream(path);

    for (std::string line; std::getline(file, line);)
    {
        line = line.substr(0, line.find('#'));

        auto separator = line.find(' ');

        if (separator == std::string::npos)
            continue;

        auto spent = 0;

        if (toInt(line.substr(separator + 1), spent))
            quota.byMonth[line.substr(0, separator)] = spent;
    }

    return quota;
}

// The ids the API said no to. Most of a list will end up here at corpus scale
// - a shader is only served if its author marked it Public+API - and asking
// again next month would spend the budget on the same refusal.
struct Refusals
{
    bool has(const std::string& id) const
    {
        return reasonById.find(id) != reasonById.end();
    }

    void add(const std::string& id, const std::string& reason)
    {
        reasonById[id] = reason;
        write();
    }

    void forget(const std::string& id)
    {
        if (reasonById.erase(id) > 0)
            write();
    }

    void write() const
    {
        auto file = std::ofstream(path);

        if (!file)
            return;

        file << "# Ids the API refused, and why. Skipped on later runs unless\n"
             << "# --retry-refused says otherwise: a shader that is not\n"
             << "# Public+API stays that way until its author changes it.\n";

        for (const auto& [id, reason]: reasonById)
            file << id << "  # " << reason << "\n";
    }

    std::filesystem::path path;
    std::map<std::string, std::string> reasonById;
};

Refusals loadRefusals(const std::filesystem::path& path)
{
    auto refusals = Refusals {path, {}};
    auto file = std::ifstream(path);

    for (std::string line; std::getline(file, line);)
    {
        auto comment = line.find('#');
        auto reason = comment == std::string::npos
                          ? std::string {}
                          : line.substr(line.find_first_not_of(" \t", comment + 1));

        line = line.substr(0, comment);

        auto first = line.find_first_not_of(" \t\r");

        if (first == std::string::npos)
            continue;

        auto id = line.substr(first, line.find_last_not_of(" \t\r") + 1 - first);
        refusals.reasonById[id] = reason;
    }

    return refusals;
}

std::string apiRoot(const Options& options)
{
    auto root = options.api;

    while (!root.empty() && root.back() == '/')
        root.pop_back();

    return root;
}

std::string shaderUrl(const Options& options, const std::string& id)
{
    return apiRoot(options) + "/" + id + "?key=" + options.key;
}

// The index, or the search when a term was given - the two endpoints that hand
// back ids rather than shaders. Either is one request however many ids come
// back, which is what makes filling the list cheap and draining it expensive.
std::string indexUrl(const Options& options)
{
    auto url = apiRoot(options);

    if (!options.query.empty())
        url += "/query/" + percentEncoded(options.query);

    url += "?key=" + options.key + "&num=" + std::to_string(options.discover)
           + "&from=0";

    if (!options.sort.empty())
        url += "&sort=" + percentEncoded(options.sort);

    if (!options.filter.empty())
        url += "&filter=" + percentEncoded(options.filter);

    return url;
}

// What this writes a pass as. The image pass keeps the shader's own id, so the
// ordinary single-pass case is one file with an obvious name; every other pass
// is suffixed with the name the page gives it, since a Shadertoy with buffers is
// several files here exactly as Corpus/TrailBuffer.glsl and TrailImage.glsl are.
std::string suffixFor(const Miro::Json::Value& renderPass)
{
    auto kind = stringField(renderPass, "type");

    if (kind.empty() || kind == "image")
        return {};

    auto name = stringField(renderPass, "name");

    if (name.empty())
        name = kind;

    // "Buf A" -> "-BufA", which is a name a C++ struct can be called after.
    auto suffix = std::string("-");

    for (auto character: name)
        if (character != ' ')
            suffix += character;

    return suffix;
}

// What each iChannel is bound to, which a port has to know and the source does
// not say. A texture is a file on Shadertoy's server and a buffer is another
// pass here; either way it is the app's job to supply it.
std::string channelNote(const Miro::Json::Value& renderPass)
{
    const auto* inputs = field(renderPass, "inputs");

    if (inputs == nullptr || !inputs->isArray() || inputs->asArray().empty())
        return {};

    auto text = std::string("//\n// Channels:\n");

    for (const auto& channel: inputs->asArray())
    {
        const auto* index = field(channel, "channel");
        auto source = stringField(channel, "src");

        text += "//   iChannel";
        text += index != nullptr && index->isNumber()
                    ? std::to_string((int) index->asNumber())
                    : "?";
        text += ": " + stringField(channel, "ctype");
        text += source.empty() ? "" : " " + source;
        text += "\n";
    }

    return text;
}

std::string header(const Miro::Json::Value& info,
                   const Miro::Json::Value& renderPass)
{
    auto name = stringField(info, "name");
    auto author = stringField(info, "username");

    auto text = "// " + name;
    text += author.empty() ? "\n" : " - " + author + "\n";
    text += "// https://www.shadertoy.com/view/" + stringField(info, "id") + "\n";
    text += "//\n";
    text += "// Fetched rather than vendored: Shadertoy's default licence is\n";
    text += "// CC BY-NC-SA 3.0 unless the author says otherwise. Not for\n";
    text += "// redistribution - this file is measured here and stays here.\n";
    text += channelNote(renderPass);

    return text + "\n";
}

// A `common` pass is not a pass at all: it is a prelude the page pastes in
// front of every other one, so it is written into each of them rather than into
// a file of its own.
std::string preludeOf(const Miro::Json::Array& passes)
{
    auto prelude = std::string {};

    for (const auto& renderPass: passes)
        if (stringField(renderPass, "type") == "common")
            prelude += stringField(renderPass, "code");

    return prelude;
}

// A key the API will not take is answered in the same place a private shader
// is, and telling them apart matters: recording a refusal per id would write
// the whole list off over one bad environment variable.
bool isAboutTheKey(const std::string& reason)
{
    auto lowered = reason;

    for (auto& character: lowered)
        character = (char) std::tolower((unsigned char) character);

    return lowered.find("key") != std::string::npos;
}

// Everything one run needs to remember, so that the steps below read as the
// bookkeeping they are rather than as arguments threaded through five calls.
struct Session
{
    Session(const Fetcher& fetcherToUse, const Options& optionsToUse)
        : fetcher(fetcherToUse)
        , options(optionsToUse)
    {
    }

    Summary run()
    {
        std::filesystem::create_directories(options.out);

        auto stamp = fetcher.date();

        quota = loadQuota(options.out / ".quota", monthOf(stamp), options.budget);
        refusals = loadRefusals(options.out / ".refused");

        if (options.discover > 0)
            discover(stamp);

        auto work = pending();

        if (options.idsOnly || keyRefused)
            fetcher.note(std::to_string(work.size()) + " ids waiting, none asked for"
                         + (keyRefused ? "" : " (--ids-only)"));
        else
            fetchEach(work);

        report();

        summary.spent = quota.spentThisMonth();
        summary.remaining = quota.remaining();

        return summary;
    }

    void discover(const std::string& stamp)
    {
        if (quota.remaining() == 0)
        {
            fetcher.warn("no requests left this month, so the index was not asked");
            return;
        }

        auto reply = fetcher.transport(indexUrl(options));

        if (!reply.arrived())
        {
            ++summary.failed;
            fetcher.warn("the index: " + describe(reply));
            return;
        }

        quota.spend();

        auto value = Miro::Json::getParsedValue(reply.content);

        if (const auto* error = field(value, "Error"))
        {
            auto reason =
                error->isString() ? error->asString() : Miro::Json::print(*error);

            ++summary.failed;
            keyRefused = isAboutTheKey(reason);
            fetcher.warn("the index: " + reason);
            return;
        }

        const auto* results = field(value, "Results");

        if (results == nullptr || !results->isArray())
        {
            ++summary.failed;
            fetcher.warn("the index answered in a shape this does not know");
            return;
        }

        auto ids = Vector<std::string> {};

        for (const auto& id: results->asArray())
            if (id.isString())
                ids.add(id.asString());

        auto source = options.query.empty()
                          ? std::string("the index")
                          : "a search for \"" + options.query + "\"";

        summary.discovered = appendIds(options.idsFile, ids, source, stamp);

        fetcher.note(std::to_string(ids.size()) + " ids from " + source + ", "
                     + std::to_string(summary.discovered) + " of them new in "
                     + options.idsFile.string());
    }

    // The list minus what this machine already has and what the API has
    // already refused - which is the whole of what makes a second run cheap.
    Vector<std::string> pending()
    {
        if (options.ids.empty() && !std::filesystem::exists(options.idsFile))
        {
            ++summary.failed;
            fetcher.warn("cannot read " + options.idsFile.string());
            return {};
        }

        auto ids = options.ids.empty() ? readIds(options.idsFile) : options.ids;
        auto work = Vector<std::string> {};

        for (const auto& id: ids)
        {
            if (std::filesystem::exists(options.out / (id + ".glsl")))
            {
                ++summary.alreadyHad;
                continue;
            }

            if (!options.retryRefused && refusals.has(id))
            {
                ++summary.skippedRefused;
                continue;
            }

            if (!work.contains(id))
                work.add(id);
        }

        return work;
    }

    void fetchEach(const Vector<std::string>& work)
    {
        auto failuresInARow = 0;

        for (auto index = 0; index < work.size(); ++index)
        {
            if (quota.remaining() == 0)
            {
                summary.leftToDo = work.size() - index;
                fetcher.warn("the month's requests are spent; "
                             + std::to_string(summary.leftToDo)
                             + (summary.leftToDo == 1 ? " id stays" : " ids stay")
                             + " on the list for next month");
                return;
            }

            if (index > 0 && options.delayMs > 0)
                std::this_thread::sleep_for(
                    std::chrono::milliseconds(options.delayMs));

            const auto& id = work[index];
            auto reply = fetcher.transport(shaderUrl(options, id));

            // A request the API never answered costs nothing, so it is not
            // counted - but a network that is down will not come back up
            // halfway through a list, and every id after it would report the
            // same thing.
            if (!reply.arrived())
            {
                ++summary.failed;
                fetcher.warn(id + ": " + describe(reply));

                if (++failuresInARow == 3)
                {
                    summary.leftToDo = work.size() - index - 1;
                    fetcher.warn("three failures in a row, so this stopped");
                    return;
                }

                continue;
            }

            failuresInARow = 0;
            quota.spend();
            take(id, reply);

            if (keyRefused)
            {
                summary.leftToDo = work.size() - index - 1;
                fetcher.warn("the key is the problem, not the shaders, so "
                             "this stopped before spending the month on it");
                return;
            }
        }
    }

    void take(const std::string& id, const Reply& reply)
    {
        auto shader = Miro::Json::getParsedValue(reply.content);

        if (shader.isNull())
        {
            ++summary.failed;
            fetcher.warn(id + ": the answer was not JSON");
            return;
        }

        // The API answers a bad key, a private shader and a missing one the
        // same way: 200, with an Error in the body. Only the middle two are
        // this shader's problem - a key the API will not take is every id's,
        // and writing the whole list off over it would be the one mistake
        // these ledgers cannot be talked out of afterwards.
        if (const auto* error = field(shader, "Error"))
        {
            auto reason =
                error->isString() ? error->asString() : Miro::Json::print(*error);

            if (isAboutTheKey(reason))
            {
                ++summary.failed;
                keyRefused = true;
                fetcher.warn(id + ": " + reason);
                return;
            }

            ++summary.refused;
            refusals.add(id, reason);
            fetcher.warn(id + ": " + reason + " (recorded, not asked again)");
            return;
        }

        // The API wraps the shader in a Shader field; a stub pointed at with
        // --api need not, and the unwrapped shape is the one the files here
        // are named after.
        const auto* wrapped = field(shader, "Shader");

        if (!writePasses(wrapped != nullptr ? *wrapped : shader))
        {
            ++summary.failed;
            return;
        }

        ++summary.fetched;
        refusals.forget(id);
    }

    bool writePasses(const Miro::Json::Value& shader)
    {
        const auto* info = field(shader, "info");
        const auto* passes = field(shader, "renderpass");

        if (info == nullptr || passes == nullptr || !passes->isArray())
        {
            fetcher.warn("a shader came back in a shape this does not know");
            return false;
        }

        auto id = stringField(*info, "id");
        auto prelude = preludeOf(passes->asArray());
        auto written = false;

        for (const auto& renderPass: passes->asArray())
        {
            if (stringField(renderPass, "type") == "common")
                continue;

            auto path = options.out / (id + suffixFor(renderPass) + ".glsl");
            auto file = std::ofstream(path);

            if (!file)
            {
                fetcher.warn("cannot write " + path.string());
                continue;
            }

            file << header(*info, renderPass) << prelude
                 << stringField(renderPass, "code");

            fetcher.note(path.string());
            written = true;
        }

        return written;
    }

    void report() const
    {
        auto line = std::to_string(summary.fetched) + " fetched";

        if (summary.alreadyHad > 0)
            line += ", " + std::to_string(summary.alreadyHad) + " already here";

        if (summary.refused > 0)
            line += ", " + std::to_string(summary.refused) + " refused";

        if (summary.skippedRefused > 0)
            line +=
                ", " + std::to_string(summary.skippedRefused) + " refused before";

        if (summary.failed > 0)
            line += ", " + std::to_string(summary.failed) + " failed";

        fetcher.note("");
        fetcher.note(line);
        fetcher.note(std::to_string(quota.spentThisMonth()) + " of "
                     + std::to_string(options.budget)
                     + " requests spent this month, "
                     + std::to_string(quota.remaining()) + " left");
    }

    static std::string describe(const Reply& reply)
    {
        if (!reply.error.empty())
            return reply.error;

        // 403 is what the site's bot check answers with, and the API is the
        // one path exempt from it - so a 403 here means the request went
        // somewhere other than the API.
        return "HTTP " + std::to_string(reply.statusCode);
    }

    const Fetcher& fetcher;
    const Options& options;

    MonthlyQuota quota;
    Refusals refusals;
    Summary summary;

    bool keyRefused = false;
};
} // namespace

Options parseOptions(const Vector<std::string>& arguments)
{
    auto options = Options {};

    auto number = [&options](const std::string& text, int& into)
    {
        if (!toInt(text, into) || into < 0)
            options.valid = false;
    };

    for (auto index = 0; index < arguments.size(); ++index)
    {
        const auto& argument = arguments[index];
        auto hasValue = index + 1 < arguments.size();

        if (argument == "--ids" && hasValue)
            options.idsFile = arguments[++index];
        else if (argument == "--out" && hasValue)
            options.out = arguments[++index];
        else if (argument == "--api" && hasValue)
            options.api = arguments[++index];
        else if (argument == "--query" && hasValue)
            options.query = arguments[++index];
        else if (argument == "--sort" && hasValue)
            options.sort = arguments[++index];
        else if (argument == "--filter" && hasValue)
            options.filter = arguments[++index];
        else if (argument == "--list" && hasValue)
            number(arguments[++index], options.discover);
        else if (argument == "--budget" && hasValue)
            number(arguments[++index], options.budget);
        else if (argument == "--delay" && hasValue)
            number(arguments[++index], options.delayMs);
        else if (argument == "--ids-only")
            options.idsOnly = true;
        else if (argument == "--retry-refused")
            options.retryRefused = true;
        else if (argument == "--help" || argument == "-h")
            options.help = true;
        else if (!argument.empty() && argument[0] == '-')
            options.valid = false;
        else
            options.ids.add(argument);
    }

    // A search with nothing to fill means the term was meant as a filter on a
    // list nobody asked for, which would silently fetch the whole id file
    // instead.
    if (!options.query.empty() && options.discover == 0)
        options.discover = 100;

    return options;
}

Options parseOptions(int argc, char* argv[])
{
    auto arguments = Vector<std::string> {};

    for (auto index = 1; index < argc; ++index)
        arguments.add(argv[index]);

    return parseOptions(arguments);
}

Summary Fetcher::run(const Options& options) const
{
    auto session = Session {*this, options};

    return session.run();
}
} // namespace Shadertoy::Corpus
