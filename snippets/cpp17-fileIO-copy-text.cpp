// @desc: copy a text file line by line (fixture lives in data/)

#include <fstream>
#include <iostream>
#include <string>

int main() {
  // This snippet runs with CWD = data/cpp17-fileIO-copy-text/:
  // input.txt is a committed fixture, out/ is generated and gitignored.
  const std::string inFileName = "input.txt";
  const std::string outFileName = "out/copy.txt";

  std::ifstream inFileStream(inFileName);
  if (!inFileStream) {
    std::cerr << "[Error]: cannot open " << inFileName << '\n';
    return 1;
  }

  std::ofstream outFileStream(outFileName);
  if (!outFileStream) {
    std::cerr << "[Error]: cannot open " << outFileName << '\n';
    return 1;
  }

  std::string bufferLine;
  while (getline(inFileStream, bufferLine)) {
    outFileStream << bufferLine << '\n';
    std::cout << bufferLine << '\n';
  }

  std::cout << "[Info]: End of reading.\n";
  return 0;
}
