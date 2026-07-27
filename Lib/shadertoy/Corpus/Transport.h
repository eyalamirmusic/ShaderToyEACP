#pragma once

#include <functional>
#include <string>

// The one thing the fetcher needs a network for, and so the one thing it
// replaces to be tested: a request, whatever came back, and where to say so.
namespace Shadertoy::Corpus
{
struct Reply
{
    // Whether the server itself answered, as opposed to the edge in front of
    // it. Only an answer costs a request, which is why the distinction is a
    // predicate rather than a comment at the call site.
    bool arrived() const { return error.empty() && statusCode == 200; }

    int statusCode = 0;
    std::string content;
    std::string error;
};

using Transport = std::function<Reply(const std::string& url)>;

Reply httpGet(const std::string& url);

std::string percentEncoded(const std::string& text);

void printNote(const std::string& text);
void printWarning(const std::string& text);
} // namespace Shadertoy::Corpus
