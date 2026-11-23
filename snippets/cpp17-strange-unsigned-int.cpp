// @desc: from learncpp.com 4.5 - unsigned integers, and why to avoid them

#include <iostream>

// assume int is 4 bytes
int main() {
  signed int s{-1};
  unsigned int u{1};

  // learncpp writes `if (s < u)` here: -1 is implicitly converted to
  // 4294967295, and 4294967295 < 1 is false, so the else branch runs. The
  // conversion is spelled out below so -Wsign-compare stays on and the
  // surprise shows up in the output instead of in a build error.
  const unsigned int s_as_unsigned{static_cast<unsigned int>(s)};
  std::cout << "s = " << s << ", (unsigned)s = " << s_as_unsigned << '\n';

  if (s_as_unsigned < u) // 4294967295 < 1 is false
    std::cout << "-1 is less than 1\n";
  else
    std::cout << "1 is less than -1\n"; // this statement executes

  return 0;
}
