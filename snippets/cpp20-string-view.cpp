// @desc: string_view vs string, substring without copying
// @std: c++20
#include <iostream>
#include <string>
#include <string_view>

int main() {
    std::string s = "hello, world";
    std::string_view sv{s};

    std::string_view word = sv.substr(0, 5);
    std::cout << "word           = " << word << '\n';
    std::cout << "without prefix = " << sv.substr(7) << '\n';

    std::cout << "starts_with / ends_with: "
              << sv.starts_with("hello") << ' ' << sv.ends_with("world") << '\n';

    // string_view does not own memory; converting back to string copies.
    std::string back{word};
    std::cout << "back.size()    = " << back.size() << '\n';
    return 0;
}
