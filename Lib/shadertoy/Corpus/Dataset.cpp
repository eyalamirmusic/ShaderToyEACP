#include "Dataset.h"

#include "Json.h"

#include <algorithm>
#include <charconv>
#include <fstream>
#include <map>
#include <sstream>

namespace Shadertoy::Corpus::Dataset
{
namespace
{
bool toInt(std::string_view text, int& into)
{
    const auto* end = text.data() + text.size();

    return std::from_chars(text.data(), end, into).ptr == end;
}

std::string rowsUrl(const Options& options, int offset, int length)
{
    auto root = options.server;

    while (!root.empty() && root.back() == '/')
        root.pop_back();

    return root + "/rows?dataset=" + percentEncoded(options.name)
           + "&config=" + percentEncoded(options.config) + "&split="
           + percentEncoded(options.split) + "&offset=" + std::to_string(offset)
           + "&length=" + std::to_string(length);
}

// The endpoint shortens a cell rather than refusing the row, and says which
// ones it shortened. A shader cut off mid-function still parses far enough to
// report gaps, so taking one would put a blocker in the table that belongs to
// this file rather than to the shader.
bool wasTruncated(const Miro::Json::Value& row, const char* cell)
{
    const auto* truncated = field(row, "truncated_cells");

    if (truncated == nullptr || !truncated->isArray())
        return false;

    for (const auto& name: truncated->asArray())
        if (name.isString() && name.asString() == cell)
            return true;

    return false;
}

// What the shader is, who wrote it and what they licensed it under - the three
// things the dataset carries that the source does not, and the last of which
// decides whether a shader may ever be committed here or only measured.
struct Credit
{
    std::string author;
    std::string licence;
};

std::string header(const std::string& id, const Credit& credit, const Options& in)
{
    auto text = "// " + id;
    text += credit.author.empty() ? "\n" : " - " + credit.author + "\n";
    text += "// https://www.shadertoy.com/view/" + id + "\n";
    text += "//\n";
    text += "// From " + in.name + ",\n";
    text += "// which is the corpus the coverage tables here are measured\n";
    text += "// over. Its author licensed it " + credit.licence + ",\n";
    text += "// and that is what decides whether a shader may be committed to\n";
    text += "// this repository or only measured in it - .licences beside this\n";
    text += "// file is the same record for the whole directory.\n";

    return text + "\n";
}

// The record of what the directory is allowed to be. It is read before it is
// written so that a run which only saw half the dataset does not forget the
// other half, which is the same discipline the id list beside it keeps.
struct Licences
{
    void read()
    {
        auto file = std::ifstream(path);

        for (std::string line; std::getline(file, line);)
        {
            line = line.substr(0, line.find('#'));

            auto id = std::string {};
            auto credit = Credit {};
            auto fields = std::istringstream(line);

            if (fields >> id >> credit.licence >> credit.author)
                creditById[id] = credit;
        }
    }

    void write() const
    {
        auto file = std::ofstream(path);

        if (!file)
            return;

        file << "# What every shader here is licensed under, and by whom, as\n"
             << "# the dataset it came from records it. This is what decides\n"
             << "# whether a shader may be committed to this repository or\n"
             << "# only measured in it: Corpus/Imported holds the ones whose\n"
             << "# licence permits redistribution, and the rest stay here.\n"
             << "#\n"
             << "# id  licence  author\n";

        for (const auto& [id, credit]: creditById)
            file << id << "  " << credit.licence << "  " << credit.author << "\n";
    }

    std::filesystem::path path;
    std::map<std::string, Credit> creditById;
};

// One run, which is a few requests and then a directory. Everything below is
// bookkeeping over what the transport returned, which is what lets a test drive
// the whole of it without a socket.
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

        licences.path = options.out / ".licences";
        licences.read();

        readPages();
        writeShaders();

        licences.write();
        report();

        return summary;
    }

    void readPages()
    {
        auto total = options.limit > 0 ? options.limit : options.pageSize;

        for (auto offset = 0; offset < total;)
        {
            auto length = std::min(options.pageSize, total - offset);
            auto reply = fetcher.transport(rowsUrl(options, offset, length));

            ++summary.requests;

            if (!reply.arrived())
            {
                ++summary.failed;
                fetcher.warn("rows from " + std::to_string(offset) + ": "
                             + describe(reply));
                return;
            }

            auto page = Miro::Json::getParsedValue(reply.content);
            auto read = takeRows(page);

            if (read == 0)
            {
                ++summary.failed;
                fetcher.warn("the endpoint answered in a shape this does not "
                             "know, or with nothing in it");
                return;
            }

            offset += read;

            // What the split holds is only known once something has come back,
            // and a limit nobody set is the whole of it.
            if (options.limit == 0)
                total = intField(page, "num_rows_total", offset);
        }
    }

    // A row is one function of one shader, so the same id arrives several
    // times over: the first complete copy of it is the shader, and the rest
    // say nothing this does not already have.
    int takeRows(const Miro::Json::Value& page)
    {
        const auto* rows = field(page, "rows");

        if (rows == nullptr || !rows->isArray())
            return 0;

        for (const auto& entry: rows->asArray())
        {
            const auto* row = field(entry, "row");

            if (row == nullptr)
                continue;

            ++summary.rows;

            auto id = stringField(*row, "id");

            if (id.empty())
                continue;

            if (!seen.contains(id))
            {
                seen.add(id);
                ++summary.shaders;
            }

            licences.creditById[id] = {stringField(*row, "author"),
                                       stringField(*row, "license")};

            if (codeById.count(id) > 0)
                continue;

            if (wasTruncated(entry, "image_code"))
                continue;

            auto code = stringField(*row, "image_code");

            if (!code.empty())
                codeById[id] = code;
        }

        return rows->asArray().size();
    }

    void writeShaders()
    {
        for (const auto& id: seen)
        {
            auto found = codeById.find(id);

            if (found == codeById.end())
            {
                ++summary.incomplete;
                fetcher.warn(id + ": every copy of it came back truncated");
                continue;
            }

            auto path = options.out / (id + ".glsl");

            if (std::filesystem::exists(path))
            {
                ++summary.alreadyHad;
                continue;
            }

            auto file = std::ofstream(path, std::ios::binary);

            if (!file)
            {
                ++summary.failed;
                fetcher.warn("cannot write " + path.string());
                continue;
            }

            file << header(id, licences.creditById[id], options) << found->second;
            ++summary.written;
        }
    }

    void report() const
    {
        auto line = std::to_string(summary.written) + " written";

        if (summary.alreadyHad > 0)
            line += ", " + std::to_string(summary.alreadyHad) + " already here";

        if (summary.incomplete > 0)
            line += ", " + std::to_string(summary.incomplete) + " truncated";

        if (summary.failed > 0)
            line += ", " + std::to_string(summary.failed) + " failed";

        fetcher.note("");
        fetcher.note(line);
        fetcher.note(std::to_string(summary.shaders) + " shaders in "
                     + std::to_string(summary.rows) + " rows, "
                     + std::to_string(summary.requests) + " requests, no key");
    }

    static std::string describe(const Reply& reply)
    {
        if (!reply.error.empty())
            return reply.error;

        return "HTTP " + std::to_string(reply.statusCode);
    }

    const Fetcher& fetcher;
    const Options& options;

    // In the order the rows arrived, so that a limited run takes the front of
    // the split rather than an arbitrary slice of it.
    Vector<std::string> seen;
    std::map<std::string, std::string> codeById;

    Licences licences;
    Summary summary;
};
} // namespace

Options parseOptions(const Vector<std::string>& arguments)
{
    auto options = Options {};

    auto number = [&options](const std::string& text, int& into)
    {
        if (!toInt(text, into) || into <= 0)
            options.valid = false;
    };

    for (auto index = 0; index < arguments.size(); ++index)
    {
        const auto& argument = arguments[index];
        auto hasValue = index + 1 < arguments.size();

        if (argument == "--dataset")
        {
            options.requested = true;

            // The name is optional: --dataset on its own means the one the
            // tables here are measured over, which is the whole point of it.
            if (hasValue && arguments[index + 1].rfind('-', 0) != 0)
                options.name = arguments[++index];
        }
        else if (argument == "--out" && hasValue)
            options.out = arguments[++index];
        else if (argument == "--server" && hasValue)
            options.server = arguments[++index];
        else if (argument == "--config" && hasValue)
            options.config = arguments[++index];
        else if (argument == "--split" && hasValue)
            options.split = arguments[++index];
        else if (argument == "--rows" && hasValue)
            number(arguments[++index], options.limit);
        else if (argument == "--help" || argument == "-h")
            options.help = true;
        else
            options.valid = false;
    }

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
} // namespace Shadertoy::Corpus::Dataset
