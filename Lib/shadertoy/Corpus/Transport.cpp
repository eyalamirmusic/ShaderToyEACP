#include "Transport.h"

#include <eacp/Network/HTTP/Http.h>

#include <cctype>
#include <iostream>

namespace Shadertoy::Corpus
{
Reply httpGet(const std::string& url)
{
    auto request = eacp::HTTP::Request {url};
    request.headers["User-Agent"] = "ShaderToyEACP corpus fetcher";

    auto response = request.perform();

    return {response.statusCode, response.content, response.error};
}

std::string percentEncoded(const std::string& text)
{
    static constexpr auto digits = "0123456789ABCDEF";
    auto encoded = std::string {};

    for (auto character: text)
    {
        if (std::isalnum((unsigned char) character) != 0 || character == '-'
            || character == '_' || character == '.' || character == '~')
        {
            encoded += character;
            continue;
        }

        encoded += '%';
        encoded += digits[(unsigned char) character >> 4];
        encoded += digits[(unsigned char) character & 0xf];
    }

    return encoded;
}

void printNote(const std::string& text)
{
    std::cout << text << "\n";
}

void printWarning(const std::string& text)
{
    std::cerr << text << "\n";
}
} // namespace Shadertoy::Corpus
