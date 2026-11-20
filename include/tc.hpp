// tc.hpp - tiny assertion header for test-cpp-code snippets. Zero dependencies.
//
// Goal: give a snippet readable output plus an exit code that says whether it
// passed, so `make test` can tell pass from fail automatically.
//
//   #include <tc.hpp>
//
//   int main() {
//       tc::section("string_view");
//       TC_CHECK(std::string("hello").starts_with("he"));
//       TC_CHECK_EQ(std::string("abc").size(), 3u);
//       return tc::summary();   // returns 1 if anything failed
//   }
//
// Assertions are optional: plain std::cout snippets with exit code 0 also pass.
#pragma once

#include <cstddef>
#include <cstdio>
#include <string_view>

namespace tc {

namespace detail {
inline int g_total = 0;
inline int g_failed = 0;
}  // namespace detail

inline void section(std::string_view name) {
    std::printf("\n== %.*s ==\n", static_cast<int>(name.size()), name.data());
}

inline void check(bool ok, const char* expr, const char* file, int line) {
    ++detail::g_total;
    if (ok) {
        std::printf("  [ok]   %s\n", expr);
    } else {
        ++detail::g_failed;
        std::printf("  [FAIL] %s   (%s:%d)\n", expr, file, line);
    }
}

template <class A, class B>
inline void check_eq(const A& a, const B& b, const char* expr, const char* file, int line) {
    ++detail::g_total;
    if (a == b) {
        std::printf("  [ok]   %s\n", expr);
    } else {
        ++detail::g_failed;
        std::printf("  [FAIL] %s   (%s:%d)\n", expr, file, line);
    }
}

inline int summary() {
    std::printf("\n%d checks, %d failed\n", detail::g_total, detail::g_failed);
    return detail::g_failed == 0 ? 0 : 1;
}

}  // namespace tc

#define TC_CHECK(expr)    ::tc::check(static_cast<bool>(expr), #expr, __FILE__, __LINE__)
#define TC_CHECK_EQ(a, b) ::tc::check_eq((a), (b), #a " == " #b, __FILE__, __LINE__)
