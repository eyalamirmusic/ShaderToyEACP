#pragma once

#include "Common.h"

namespace Shadertoy::Glsl
{
enum class TokenType
{
    End,
    Identifier,
    Number,
    Punctuator
};

struct Token
{
    bool is(std::string_view expected) const { return text == expected; }

    bool isIdentifier() const { return type == TokenType::Identifier; }
    bool isEnd() const { return type == TokenType::End; }

    TokenType type = TokenType::End;
    std::string text;
    int line = 1;
};
} // namespace Shadertoy::Glsl
