// @desc: std::expected / std::unexpected (C++23) basics
// @std: c++23
#include <exception>
#include <expected>
#include <iostream>
#include <string>
#include <string_view>

std::expected<int, std::string> to_int(std::string_view s) {
    try {
        std::size_t used = 0;
        int v = std::stoi(std::string{s}, &used);
        if (used != s.size()) {
            return std::unexpected("trailing characters");
        }
        return v;
    } catch (const std::exception&) {
        return std::unexpected("not a valid integer");
    }
}

int main() {
    for (std::string_view s : {"42", "42x", "abc"}) {
        auto r = to_int(s);
        if (r) {
            std::cout << s << " -> " << *r << '\n';
        } else {
            std::cout << s << " -> error: " << r.error() << '\n';
        }
    }
    return 0;
}
