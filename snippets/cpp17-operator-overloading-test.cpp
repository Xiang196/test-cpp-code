// @desc: test operator overloading by writing a Rational class
// @created: 2026-11-23
// @std: c++17

#include <cassert>
#include <cstdint>
#include <iostream>
#include <ostream>
#include <sstream>
#include <stdexcept>

class Rational {
private:
  int num_;
  int den_;

  static int gcd(int a, int b) {
    if (a < 0)
      a = -a;
    if (b < 0)
      b = -b;
    while (b != 0) {
      int t = a % b;
      a = b;
      b = t;
    }
    return a == 0 ? 1 : a;
  }

  // Keeps den_ > 0, reduces fraction, and sets 0 as 0/1.
  void normalize() {
    if (den_ == 0) {
      throw std::invalid_argument("Denominator cannot be zero");
    }
    if (num_ == 0) {
      den_ = 1;
      return;
    }
    if (den_ < 0) {
      num_ = -num_;
      den_ = -den_;
    }
    int g = gcd(num_, den_);
    num_ /= g;
    den_ /= g;
  }

public:
  // Non-explicit constructor allows implicit conversion from int (e.g., 1 + r).
  Rational(int num = 0, int den = 1) : num_(num), den_(den) { normalize(); }

  int num() const { return num_; }
  int den() const { return den_; }

  // -------------------------------------------------------------------------
  // 1. Unary operators
  // -------------------------------------------------------------------------
  Rational operator+() const { return *this; }

  Rational operator-() const { return Rational(-num_, den_); }

  // -------------------------------------------------------------------------
  // 2. Compound assignment operators
  // -------------------------------------------------------------------------
  Rational &operator+=(const Rational &rhs) {
    int new_num = num_ * rhs.den_ + den_ * rhs.num_;
    int new_den = den_ * rhs.den_;
    num_ = new_num;
    den_ = new_den;
    normalize();
    return *this;
  }

  Rational &operator-=(const Rational &rhs) {
    *this += -rhs;
    return *this;
  }

  Rational &operator*=(const Rational &rhs) {
    num_ *= rhs.num_;
    den_ *= rhs.den_;
    normalize();
    return *this;
  }

  Rational &operator/=(const Rational &rhs) {
    if (rhs.den_ == 0) {
      throw std::invalid_argument("Division by zero");
    }
    // Use temporaries to keep safe on self-division
    int new_num = num_ * rhs.den_;
    int new_den = den_ * rhs.num_;
    num_ = new_num;
    den_ = new_den;
    normalize();
    return *this;
  }

  // -------------------------------------------------------------------------
  // 3. Increment and decrement operators (adds/subtracts 1)
  // -------------------------------------------------------------------------
  // Prefix: ++r
  Rational &operator++() {
    // No need to normalize
    num_ += den_;
    return *this;
  }

  // Postfix: r++
  Rational operator++(int) {
    Rational old(*this);
    ++(*this);
    return old;
  }

  // Prefix: --r
  Rational &operator--() {
    num_ -= den_;
    return *this;
  }

  // Postfix: r--
  Rational operator--(int) {
    Rational old(*this);
    --(*this);
    return old;
  }

  // -------------------------------------------------------------------------
  // 4. Type conversion operator
  // -------------------------------------------------------------------------
  explicit operator double() const { return static_cast<double>(num_) / den_; }
};

// -----------------------------------------------------------------------------
// 5. Binary arithmetic operators (non-member functions allow int op Rational)
// -----------------------------------------------------------------------------
Rational operator+(const Rational &lhs, const Rational &rhs) {
  Rational res(lhs);
  res += rhs;
  return res;
}

Rational operator-(const Rational &lhs, const Rational &rhs) {
  Rational res(lhs);
  res -= rhs;
  return res;
}

Rational operator*(const Rational &lhs, const Rational &rhs) {
  Rational res(lhs);
  res *= rhs;
  return res;
}

Rational operator/(const Rational &lhs, const Rational &rhs) {
  Rational res(lhs);
  res /= rhs;
  return res;
}

// -----------------------------------------------------------------------------
// 6. Comparison operators (non-member functions)
// -----------------------------------------------------------------------------
bool operator==(const Rational &lhs, const Rational &rhs) {
  return lhs.num() == rhs.num() && lhs.den() == rhs.den();
}

bool operator!=(const Rational &lhs, const Rational &rhs) {
  return !(lhs == rhs);
}

bool operator<(const Rational &lhs, const Rational &rhs) {
  return static_cast<std::int64_t>(lhs.num()) * rhs.den() <
         static_cast<std::int64_t>(rhs.num()) * lhs.den();
}

bool operator<=(const Rational &lhs, const Rational &rhs) {
  return lhs < rhs || lhs == rhs;
}

bool operator>(const Rational &lhs, const Rational &rhs) {
  return !(lhs <= rhs);
}

bool operator>=(const Rational &lhs, const Rational &rhs) {
  return !(lhs < rhs);
}

// -----------------------------------------------------------------------------
// 7. Stream I/O operators
// -----------------------------------------------------------------------------
// Output format:
//   - If den() == 1, print "num" (e.g., "3", "-5", "0")
//   - Otherwise, print "num/den" (e.g., "3/4", "-1/2")
std::ostream &operator<<(std::ostream &os, const Rational &r) {
  if (r.den() == 1) {
    os << r.num();
  } else {
    os << r.num() << "/" << r.den();
  }
  return os;
}

// Input format:
//   - Accept "num/den" or "num" (e.g., "3/4" or "5")
//   - Hint: read int n; if (is.peek() == '/') { consume '/'; read int d; }
//   - Construct Rational(n, d) inside try-catch; if den == 0, set failbit.
std::istream &operator>>(std::istream &is, Rational &r) {
  int n = 0;
  int d = 1;
  if (!(is >> n)) {
    return is;
  }
  // Check !is.eof() before peek(), otherwise peek() at EOF sets failbit.
  if (!is.eof() && is.peek() == '/') {
    is.get();
    if (!(is >> d)) {
      return is;
    }
  }
  try {
    r = Rational(n, d);
  } catch (const std::invalid_argument &) {
    is.setstate(std::ios::failbit);
  }
  return is;
}

// =============================================================================
// Unit Tests
// =============================================================================
void test_comparisons() {
  assert(Rational(2, 4) == Rational(1, 2));
  assert(Rational(1, -2) == Rational(-1, 2));
  assert(Rational(0, 5) == Rational(0, -3));
  assert(Rational(3) == 3);
  assert(3 == Rational(3, 1));
  assert(Rational(1, 2) != Rational(1, 3));

  assert(Rational(1, 3) < Rational(1, 2));
  assert(Rational(-1, 2) < Rational(-1, 3));
  assert(Rational(1, 2) <= Rational(2, 4));
  assert(Rational(2, 3) > Rational(1, 2));
  assert(Rational(2, 3) >= Rational(2, 3));
  assert(1 < Rational(3, 2));
  std::cout << "[PASS] test_comparisons\n";
}

void test_unary_and_inc_dec() {
  Rational r(3, 4);
  assert(+r == Rational(3, 4));
  assert(-r == Rational(-3, 4));
  assert(-Rational(-1, 2) == Rational(1, 2));

  Rational a(1, 2);
  assert(++a == Rational(3, 2));
  assert(a == Rational(3, 2));
  assert(a++ == Rational(3, 2));
  assert(a == Rational(5, 2));

  assert(--a == Rational(3, 2));
  assert(a-- == Rational(3, 2));
  assert(a == Rational(1, 2));
  std::cout << "[PASS] test_unary_and_inc_dec\n";
}

void test_arithmetic() {
  Rational a(1, 2);
  Rational b(1, 3);

  assert(a + b == Rational(5, 6));
  assert(a - b == Rational(1, 6));
  assert(a * b == Rational(1, 6));
  assert(a / b == Rational(3, 2));

  // Implicit conversion with int on both sides
  assert(a + 1 == Rational(3, 2));
  assert(1 + a == Rational(3, 2));
  assert(2 - a == Rational(3, 2));
  assert(3 * b == 1);

  // Compound assignment
  Rational c(1, 4);
  c += Rational(1, 4);
  assert(c == Rational(1, 2));
  c -= Rational(1, 6);
  assert(c == Rational(1, 3));
  c *= 6;
  assert(c == 2);
  c /= 4;
  assert(c == Rational(1, 2));

  bool threw = false;
  try {
    c /= 0;
  } catch (const std::invalid_argument &) {
    threw = true;
  }
  assert(threw);
  std::cout << "[PASS] test_arithmetic\n";
}

void test_conversion_and_io() {
  Rational r(3, 4);
  double d = static_cast<double>(r);
  assert(d > 0.749999 && d < 0.750001);

  std::ostringstream oss;
  oss << Rational(3, 4) << " " << Rational(-6, 2) << " " << Rational(0, 7);
  assert(oss.str() == "3/4 -3 0");

  std::istringstream iss("2/6 -5 4/-8");
  Rational r1, r2, r3;
  iss >> r1 >> r2 >> r3;
  assert(iss.good() || iss.eof());
  assert(r1 == Rational(1, 3));
  assert(r2 == Rational(-5, 1));
  assert(r3 == Rational(-1, 2));

  std::istringstream bad_iss("1/0");
  Rational r_bad;
  bad_iss >> r_bad;
  assert(bad_iss.fail());
  std::cout << "[PASS] test_conversion_and_io\n";
}

int main() {
  std::cout << "Rational exercise template compiled successfully.\n";

  test_comparisons();
  test_unary_and_inc_dec();
  test_arithmetic();
  test_conversion_and_io();

  return 0;
}
