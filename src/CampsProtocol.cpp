#include "CampsProtocol.h"
#include <cmath>
#include <sstream>
#include <locale>

namespace Camps
{
bool UInt(std::string const& text, uint32_t& value)
{
    if (text.empty() || text.size() > 10) return false;
    uint64_t n = 0;
    for (char c : text)
    {
        if (c < '0' || c > '9') return false;
        n = n * 10 + c - '0';
        if (n > UINT32_MAX) return false;
    }
    value = static_cast<uint32_t>(n);
    return true;
}
bool Number(std::string const& text, float& value, float limit)
{
    if (text.empty() || text.size() > 16) return false;
    for (char c : text)
        if ((c < '0' || c > '9') && c != '-' && c != '.') return false;
    std::istringstream input(text);
    input.imbue(std::locale::classic());
    input >> std::noskipws >> value;
    return !input.fail() && input.eof() && std::isfinite(value) && std::fabs(value) <= limit;
}
static int Hex(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}
std::string Escape(std::string const& text)
{
    static char const hex[] = "0123456789ABCDEF";
    std::string out;
    for (unsigned char c : text)
    {
        if (c == '%' || c == '|' || c == '~' || c < 32 || c == 127)
        {
            out += '%'; out += hex[c >> 4]; out += hex[c & 15];
        }
        else out += c;
    }
    return out;
}
bool Parse(std::string const& text, Request& out)
{
    out = Request{};
    if (text.size() > 210) return false;
    std::vector<std::string> fields;
    size_t start = 0;
    for (;;)
    {
        size_t end = text.find('~', start);
        std::string value;
        for (size_t i = start; i < (end == std::string::npos ? text.size() : end); ++i)
        {
            unsigned char c = text[i];
            if (c == '%')
            {
                size_t stop = end == std::string::npos ? text.size() : end;
                if (i + 2 >= stop || Hex(text[i+1]) < 0 || Hex(text[i+2]) < 0) return false;
                c = static_cast<unsigned char>(Hex(text[i+1]) * 16 + Hex(text[i+2])); i += 2;
            }
            if (c < 32 || c == 127) return false;
            value += c;
        }
        fields.push_back(value);
        if (fields.size() > 10) return false;
        if (end == std::string::npos) break;
        start = end + 1;
    }
    if (fields.size() < 3 || fields[0] != "1" || !UInt(fields[1], out.id) || !out.id) return false;
    if (fields[2].empty() || fields[2].size() > 16) return false;
    for (char c : fields[2]) if (c < 'A' || c > 'Z') return false;
    out.op = fields[2];
    out.args.assign(fields.begin() + 3, fields.end());
    return true;
}
std::string Reply(uint32_t id, std::string const& op, std::vector<std::string> const& fields)
{
    std::string out = "TCAMP/1~" + std::to_string(id) + "~" + op;
    for (auto const& field : fields) out += "~" + Escape(field);
    return out;
}
}
