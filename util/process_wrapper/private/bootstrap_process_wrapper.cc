#include <cerrno>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#if defined(_WIN32)
#include <direct.h>
#include <process.h>
#define getcwd _getcwd
#else
#include <unistd.h>
#endif

namespace {

constexpr const char* kPwdPlaceholder = "${pwd}";

std::string replace_pwd_placeholder(const std::string& arg,
                                    const std::string& pwd) {
  std::string out = arg;
  std::string::size_type pos = 0;
  while ((pos = out.find(kPwdPlaceholder, pos)) != std::string::npos) {
    out.replace(pos, std::strlen(kPwdPlaceholder), pwd);
    pos += pwd.size();
  }
  return out;
}

std::vector<char*> build_exec_argv(const std::vector<std::string>& args) {
  std::vector<char*> exec_argv;
  exec_argv.reserve(args.size() + 1);
  for (const std::string& arg : args) {
    exec_argv.push_back(const_cast<char*>(arg.c_str()));
  }
  exec_argv.push_back(nullptr);
  return exec_argv;
}

}  // namespace

int main(int argc, char** argv) {
  int first_arg_index = 1;
  if (argc > 1 && std::strcmp(argv[1], "--") == 0) {
    first_arg_index = 2;
  }

  if (first_arg_index >= argc) {
    std::fprintf(stderr, "bootstrap_process_wrapper: missing command\n");
    return 1;
  }

  char* pwd_raw = getcwd(nullptr, 0);
  if (pwd_raw == nullptr) {
    std::perror("bootstrap_process_wrapper: getcwd");
    return 1;
  }
  std::string pwd = pwd_raw;
  std::free(pwd_raw);

  std::vector<std::string> command_args;
  command_args.reserve(static_cast<size_t>(argc - first_arg_index));
  for (int i = first_arg_index; i < argc; ++i) {
    command_args.push_back(replace_pwd_placeholder(argv[i], pwd));
  }

#if defined(_WIN32)
  for (char& c : command_args[0]) {
    if (c == '/') {
      c = '\\';
    }
  }
#endif

  std::vector<char*> exec_argv = build_exec_argv(command_args);

#if defined(_WIN32)
  int exit_code = _spawnvp(_P_WAIT, exec_argv[0], exec_argv.data());
  if (exit_code == -1) {
    std::perror("bootstrap_process_wrapper: _spawnvp");
    return 1;
  }
  return exit_code;
#else
  execvp(exec_argv[0], exec_argv.data());
  std::perror("bootstrap_process_wrapper: execvp");
  return 1;
#endif
}
