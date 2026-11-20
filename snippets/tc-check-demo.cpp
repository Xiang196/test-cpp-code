// @desc: self-checking snippet with TC_CHECK (make test can see pass/fail)
// @std: c++20
#include <tc.hpp>

#include <string>
#include <vector>

int main() {
    tc::section("string");
    TC_CHECK(std::string("hello").starts_with("he"));
    TC_CHECK_EQ(std::string("abc").size(), 3u);

    tc::section("vector");
    std::vector<int> v{3, 1, 2};
    TC_CHECK(v.size() == 3);
    TC_CHECK_EQ(v.front(), 3);

    return tc::summary();
}
