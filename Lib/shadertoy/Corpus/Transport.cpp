#include "Transport.h"

#include <eacp/Network/HTTP/Http.h>

#include <cctype>
#include <chrono>
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

std::string today()
{
    auto now = std::chrono::system_clock::now();
    auto days = std::chrono::floor<std::chrono::days>(now);
    auto date = std::chrono::year_month_day {days};

    auto text = std::to_string((int) date.year()) + "-";
    text += (unsigned) date.month() < 10 ? "0" : "";
    text += std::to_string((unsigned) date.month()) + "-";
    text += (unsigned) date.day() < 10 ? "0" : "";

    return text + std::to_string((unsigned) date.day());
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
