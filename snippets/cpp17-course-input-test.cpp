// @desc: read numbers from stdin until -1; exits cleanly on EOF so make test cannot hang
// @created: 2026-11-23

#include <iostream>
using namespace std;
void TestInput() {
  int x = 0;
  do {
    cout << "Enter a number (-1 to quit): ";
    if (!(cin >> x)) {
      if (cin.eof()) {
        cout << "\n[Info]: end of input.\n";
        break;
      }
      cin.clear();
      cin.ignore(1000, '\n');
      cout << "Wrong input, try again.\n";
    } else {
      if (x != -1)
        cout << x << " was entered" << endl;
    }
  } while (x != -1);
  cout << "Exit" << endl;
}
int main() {
  TestInput();
  return 0;
}
