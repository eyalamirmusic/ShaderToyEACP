#pragma once

#include <Miro/Json.h>

#include <string>

// Reading a field off a reply that may not have one. Both fetchers parse JSON
// somebody else's server produced, so every access is a question rather than a
// dereference: a shape this does not know is a warning and a skipped shader,
// never a crash.
namespace Shadertoy::Corpus
{
inline const Miro::Json::Value* field(const Miro::Json::Value& value,
                                      const char* key)
{
    if (!value.isObject())
        return nullptr;

    return Miro::Json::find(value.asObject(), key);
}

inline std::string stringField(const Miro::Json::Value& value, const char* key)
{
    const auto* found = field(value, key);

    return found != nullptr && found->isString() ? found->asString()
                                                 : std::string {};
}

inline int intField(const Miro::Json::Value& value, const char* key, int fallback)
{
    const auto* found = field(value, key);

    return found != nullptr && found->isNumber() ? (int) found->asNumber()
                                                 : fallback;
}
} // namespace Shadertoy::Corpus
