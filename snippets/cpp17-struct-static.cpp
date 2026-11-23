// @desc: see how static works in a class
// @created: 2026-11-23

#include <iostream>

struct Monster {
  // 1. Non-static (instance) members:
  // Each Monster object has its own separate copy of 'id' and 'hp'.
  int id;
  int hp;

  // 2. Static members (C++17 'inline static'):
  // Shared across ALL Monster objects. They do NOT live inside each object.
  // Note: Before C++17, 'inline' was not allowed here for non-const statics,
  // and you had to define them outside the struct (e.g., int
  // Monster::alive_count = 0;).
  inline static int alive_count = 0;
  inline static bool is_boss_dead = false;

  // Constructor: runs whenever a Monster is created
  Monster(int monster_id, int initial_hp) : id(monster_id), hp(initial_hp) {
    alive_count++;
    std::cout << "[Spawn] Monster #" << id << " | Total alive: " << alive_count
              << "\n";
  }

  // Destructor: runs whenever a Monster is destroyed
  ~Monster() {
    alive_count--;
    std::cout << "[Despawn] Monster #" << id
              << " | Total alive: " << alive_count << "\n";
  }

  // Non-static member function: must be called on a specific object (e.g.,
  // m1.printStatus())
  void printStatus() const {
    std::cout << "  -> Monster #" << id << " | HP: " << hp
              << " | Boss dead: " << (is_boss_dead ? "Yes" : "No") << "\n";
  }

  // 3. Static member function:
  // Belongs to the Monster type itself, NOT any specific instance.
  static void notifyBossDied() {
    is_boss_dead = true; // OK: can access static members

    // hp = 0;           // ERROR: static functions have no 'this' pointer;
    // the compiler would not know which Monster's hp to modify.

    std::cout << "\n>>> Broadcast: The Boss has been defeated! <<<\n";
  }
};

int main() {
  // Case 1: Static members exist even before any Monster object is created.
  std::cout << "Game start | Total alive: " << Monster::alive_count << "\n";
  std::cout
      << "sizeof(Monster): " << sizeof(Monster)
      << " bytes (only 'id' and 'hp', statics take 0 bytes in instances)\n\n";

  // Case 2: Create two independent Monster objects
  Monster m1(1, 100);
  Monster m2(2, 200);

  // Modifying a non-static member only affects that specific object
  std::cout << "\n--- Player hits Monster #1 ---\n";
  m1.hp = 50;
  m1.printStatus(); // HP: 50
  m2.printStatus(); // HP: 200 (unaffected)

  // Case 3: Call static function using TypeName::FunctionName()
  Monster::notifyBossDied();
  m1.printStatus(); // Boss dead: Yes
  m2.printStatus(); // Boss dead: Yes (shared state updated for all!)

  // Case 4: Scope-based lifetime check
  std::cout << "\n--- Entering a cave (temporary Monster #3) ---\n";
  {
    Monster m3(3, 500);
  } // m3 goes out of scope here, triggering ~Monster()

  std::cout << "Left the cave | Total alive: " << Monster::alive_count
            << "\n\n";

  return 0;
} // m2 and m1 are destroyed here in reverse order of creation
