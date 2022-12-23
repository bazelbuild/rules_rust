#include "util/process_wrapper/system.h"

// posix headers
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>
#include <iostream>
#include <vector>

namespace process_wrapper {

namespace {

class OutputPipe {
 public:
  static constexpr size_t kReadEndDesc = 0;
  static constexpr size_t kWriteEndDesc = 1;

  ~OutputPipe() {
    CloseReadEnd();
    CloseWriteEnd();
  }

  int CreateEnds() {
    if (pipe(output_pipe_desc_) != 0) {
      std::cerr << "process wrapper error: failed to open the stdout pipes.\n";
      return false;
    }
    return true;
  }
  void DupWriteEnd(int newfd) {
    dup2(output_pipe_desc_[kWriteEndDesc], newfd);
    CloseReadEnd();
    CloseWriteEnd();
  }

  void CloseReadEnd() { Close(kReadEndDesc); }
  void CloseWriteEnd() { Close(kWriteEndDesc); }

  int ReadEndDesc() const { return output_pipe_desc_[kReadEndDesc]; }
  int WriteEndDesc() const { return output_pipe_desc_[kWriteEndDesc]; }

 private:
  void Close(size_t idx) {
    if (output_pipe_desc_[idx] > 0) {
      close(output_pipe_desc_[idx]);
    }
    output_pipe_desc_[idx] = -1;
  }
  int output_pipe_desc_[2] = {-1};
};

}  // namespace

System::StrType System::GetWorkingDirectory() {
  const size_t kMaxBufferLength = 4096;
  char cwd[kMaxBufferLength];
  if (getcwd(cwd, sizeof(cwd)) == NULL) {
    return System::StrType{};
  }
  return System::StrType{cwd};
}

int System::Exec(const System::StrType &executable,
                 const System::Arguments &arguments,
                 const System::EnvironmentBlock &environment_block) {
  OutputPipe stdout_pipe;
  if (!stdout_pipe.CreateEnds()) {
    return -1;
  }
  OutputPipe stderr_pipe;
  if (!stderr_pipe.CreateEnds()) {
    return -1;
  }

  pid_t child_pid = fork();
  if (child_pid < 0) {
    std::cerr << "process wrapper error: failed to fork the current process: "
              << std::strerror(errno) << ".\n";
    return -1;
  } else if (child_pid == 0) {
    std::vector<char *> argv;
    argv.push_back(const_cast<char *>(executable.c_str()));
    for (const StrType &argument : arguments) {
      argv.push_back(const_cast<char *>(argument.c_str()));
    }
    argv.push_back(nullptr);

    std::vector<char *> envp;
    for (const StrType &ev : environment_block) {
      envp.push_back(const_cast<char *>(ev.c_str()));
    }
    envp.push_back(nullptr);

    umask(022);
    execve(executable.c_str(), argv.data(), envp.data());
    std::cerr << "process wrapper error: failed to exec the new process: "
              << std::strerror(errno) << ".\n";
    return -1;
  }

  int err, exit_status;
  do {
    err = waitpid(child_pid, &exit_status, 0);
  } while (err == -1 && errno == EINTR);

  if (WIFEXITED(exit_status)) {
    return WEXITSTATUS(exit_status);
  } else if (WIFSIGNALED(exit_status)) {
    raise(WTERMSIG(exit_status));
  } else if (WIFSTOPPED(exit_status)) {
    raise(WSTOPSIG(exit_status));
  } else {
    std::cerr << "process wrapper error: failed to parse exit code of the "
                 "child process: "
              << exit_status << ".\n";
  }
  return -1;
}

}  // namespace process_wrapper
