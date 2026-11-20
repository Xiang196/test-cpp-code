// @desc: std::jthread and stop_token; also shows @flags: -pthread
// @std: c++20
// @flags: -pthread
#include <iostream>
#include <stop_token>
#include <thread>

int main() {
    std::jthread worker([](std::stop_token tok) {
        int n = 0;
        while (!tok.stop_requested() && n < 3) {
            std::cout << "worker " << ++n << '\n';
        }
    });
    worker.request_stop();  // the destructor joins automatically as well
    std::cout << "main done\n";
    return 0;
}
