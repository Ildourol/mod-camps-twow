#pragma once
#include <string>
#include <vector>
#include <cstdint>

namespace Camps
{
constexpr unsigned ProtocolVersion = 1;
constexpr unsigned PageSize = 8;
struct Request
{
    uint32_t id = 0;
    std::string op;
    std::vector<std::string> args;
};
bool UInt(std::string const& text, uint32_t& value);
bool Number(std::string const& text, float& value, float limit);
std::string Escape(std::string const& text);
bool Parse(std::string const& text, Request& out);
std::string Reply(uint32_t id, std::string const& op, std::vector<std::string> const& fields);
}
