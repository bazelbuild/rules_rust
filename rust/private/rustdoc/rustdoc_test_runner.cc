#include <fstream>
#include <iostream>
#include <string>

namespace {

bool CopyFileToStream(const std::string &path, std::ostream &out) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        std::cerr << "failed to open rustdoc test output file: " << path << "\n";
        return false;
    }
    out << file.rdbuf();
    return true;
}

int ReadExitCode(const std::string &path) {
    std::ifstream file(path);
    if (!file) {
        std::cerr << "failed to open rustdoc test exit code file: " << path << "\n";
        return -1;
    }

    int exit_code = -1;
    if (!(file >> exit_code) || exit_code < 0 || exit_code > 255) {
        std::cerr << "invalid rustdoc test exit code file: " << path << "\n";
        return -1;
    }

    return exit_code;
}

}  // namespace

int main(int argc, char **argv) {
    if (argc < 1 || argv[0] == nullptr || argv[0][0] == '\0') {
        std::cerr << "failed to determine rustdoc test executable path\n";
        return 1;
    }

    const std::string test_executable(argv[0]);

    bool ok = true;
    ok = CopyFileToStream(test_executable + ".rustdoc_test.stdout", std::cout) && ok;
    ok = CopyFileToStream(test_executable + ".rustdoc_test.stderr", std::cerr) && ok;

    const int exit_code = ReadExitCode(test_executable + ".rustdoc_test.exit_code");
    return ok && exit_code >= 0 ? exit_code : 1;
}
