// @desc: get some common data types' sizes on your computer
#include <climits>
#include <cstddef>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <string>

template <typename T> void printTypeInfo(const char *typeName) {
  std::cout << std::left << std::setw(22) << typeName << std::right
            << std::setw(8) << sizeof(T) << " B" << std::setw(10)
            << sizeof(T) * CHAR_BIT << " bits" << std::setw(10) << alignof(T)
            << " B" << '\n';
}

#define CHECK_TYPE(T) printTypeInfo<T>(#T)

int main() {
  const std::string separator(59, '-');

  std::cout << "System Data Type Sizes (CHAR_BIT = " << CHAR_BIT << ")\n";
  std::cout << separator << '\n';
  std::cout << std::left << std::setw(22) << "Type" << std::right
            << std::setw(10) << "Size" << std::setw(15) << "Bits"
            << std::setw(12) << "Alignment" << '\n';
  std::cout << separator << '\n';

  // Boolean and Character types
  CHECK_TYPE(bool);
  CHECK_TYPE(char);
  CHECK_TYPE(signed char);
  CHECK_TYPE(unsigned char);
  CHECK_TYPE(wchar_t);
#ifdef __cpp_char8_t
  CHECK_TYPE(char8_t); // C++20
#endif
  CHECK_TYPE(char16_t);
  CHECK_TYPE(char32_t);
  std::cout << separator << '\n';

  // Standard Integer types
  CHECK_TYPE(short);
  CHECK_TYPE(unsigned short);
  CHECK_TYPE(int);
  CHECK_TYPE(unsigned int);
  CHECK_TYPE(long);
  CHECK_TYPE(unsigned long);
  CHECK_TYPE(long long);
  CHECK_TYPE(unsigned long long);
  std::cout << separator << '\n';

  // Fixed-width Integer types (<cstdint>)
  CHECK_TYPE(std::int8_t);
  CHECK_TYPE(std::int16_t);
  CHECK_TYPE(std::int32_t);
  CHECK_TYPE(std::int64_t);
  std::cout << separator << '\n';

  // Floating-point types
  CHECK_TYPE(float);
  CHECK_TYPE(double);
  CHECK_TYPE(long double);
  std::cout << separator << '\n';

  // Pointer and Size types
  CHECK_TYPE(void *);
  CHECK_TYPE(int *);
  CHECK_TYPE(std::size_t);
  CHECK_TYPE(std::ptrdiff_t);
  std::cout << separator << '\n';

  return 0;
}
