#pragma once

#include <functional>
#include <string>

// The one thing either fetcher here needs a network for, and so the one thing
// either of them replaces to be tested.
//
// There are two corpora and they are reached in two different ways. Shadertoy's
// own API serves any shader its author marked Public+API, wants a key that wants
// an account with Silver status, and is worth 1500 requests a month - so Fetch.h
// is bookkeeping around a budget. A dataset somebody has already collected
// through that API is a handful of unauthenticated requests over a public
// endpoint, and Dataset.h is the paging around that. What the two share is
// exactly this file: a request, whatever came back, and where to say so.
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

// YYYY-MM-DD. The month of it is what the quota ledger is keyed on, and the
// whole of it is what a block of discovered ids is stamped with.
std::string today();

void printNote(const std::string& text);
void printWarning(const std::string& text);
} // namespace Shadertoy::Corpus
