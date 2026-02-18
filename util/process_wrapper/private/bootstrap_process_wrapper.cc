#include <cerrno>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#if defined(_WIN32)
#include <direct.h>
#include <process.h>
#include <sys/stat.h>
#define getcwd _getcwd
#define stat _stat
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

namespace {

constexpr const char* kPwdPlaceholder = "${pwd}";
constexpr const char* kOutputBasePlaceholder = "${output_base}";
constexpr const char* kExecRootPlaceholder = "${exec_root}";

#if defined(_WIN32)
constexpr char kPathSeparator = '\\';
#else
constexpr char kPathSeparator = '/';
#endif

bool is_directory(const std::string& path) {
  struct stat stat_buffer;
  return stat(path.c_str(), &stat_buffer) == 0 &&
         (stat_buffer.st_mode & S_IFDIR) != 0;
}

std::string dirname(const std::string& path) {
  std::string::size_type slash = path.find_last_of("/\\");
  if (slash == std::string::npos) {
    return path;
  }
  if (slash == 0) {
    return path.substr(0, 1);
  }
  return path.substr(0, slash);
}

std::string basename(const std::string& path) {
  std::string::size_type slash = path.find_last_of("/\\");
  if (slash == std::string::npos) {
    return path;
  }
  return path.substr(slash + 1);
}

std::string join_path(const std::string& left, const std::string& right) {
  if (left.empty()) {
    return right;
  }
  if (left.back() == '/' || left.back() == '\\') {
    return left + right;
  }
  return left + kPathSeparator + right;
}

std::string canonicalize(const std::string& path) {
#if defined(_WIN32)
  char* resolved = _fullpath(nullptr, path.c_str(), 0);
#else
  char* resolved = realpath(path.c_str(), nullptr);
#endif
  if (resolved == nullptr) {
    return path;
  }
  std::string out = resolved;
  std::free(resolved);
  return out;
}

std::string replace_all(std::string out,
                        const std::string& placeholder,
                        const std::string& replacement) {
  std::string::size_type pos = 0;
  while ((pos = out.find(placeholder, pos)) != std::string::npos) {
    out.replace(pos, placeholder.size(), replacement);
    pos += replacement.size();
  }
  return out;
}

std::string replace_placeholders(const std::string& arg,
                                 const std::string& pwd,
                                 const std::string& output_base,
                                 const std::string& exec_root) {
  std::string out = arg;
  out = replace_all(out, kPwdPlaceholder, pwd);
  out = replace_all(out, kOutputBasePlaceholder, output_base);
  out = replace_all(out, kExecRootPlaceholder, exec_root);
  return out;
}

std::string get_output_base(const std::string& pwd) {
  const std::string external = join_path(pwd, "external");
  if (is_directory(external)) {
    return canonicalize(join_path(external, ".."));
  }
  return dirname(dirname(canonicalize(pwd)));
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
  const std::string output_base = get_output_base(pwd);
  const std::string exec_root =
      join_path(join_path(output_base, "execroot"), basename(pwd));

  std::vector<std::string> command_args;
  command_args.reserve(static_cast<size_t>(argc - first_arg_index));
  for (int i = first_arg_index; i < argc; ++i) {
    command_args.push_back(
        replace_placeholders(argv[i], pwd, output_base, exec_root));
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
