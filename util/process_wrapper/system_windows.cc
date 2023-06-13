#include <cstddef>

#include "util/process_wrapper/system.h"

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include <iostream>

namespace process_wrapper {

namespace {

// We need to follow specific quoting rules for maximum compatibility as
// explained here:
// https://docs.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
void ArgumentQuote(const System::StrType& argument,
                   System::StrType& command_line) {
  if (argument.empty() == false &&
      argument.find_first_of(PW_SYS_STR(" \t\n\v\"")) == argument.npos) {
    command_line.append(argument);
  } else {
    command_line.push_back(PW_SYS_STR('"'));

    for (auto it = argument.begin();; ++it) {
      unsigned number_backslashes = 0;

      while (it != argument.end() && *it == PW_SYS_STR('\\')) {
        ++it;
        ++number_backslashes;
      }

      if (it == argument.end()) {
        command_line.append(number_backslashes * 2, PW_SYS_STR('\\'));
        break;
      } else if (*it == L'"') {
        command_line.append(number_backslashes * 2 + 1, PW_SYS_STR('\\'));
        command_line.push_back(*it);
      } else {
        command_line.append(number_backslashes, PW_SYS_STR('\\'));
        command_line.push_back(*it);
      }
    }
    command_line.push_back(PW_SYS_STR('"'));
  }
}

// Arguments needs to be quoted and space separated
void MakeCommandLine(const System::Arguments& arguments,
                     System::StrType& command_line) {
  for (const System::StrType& argument : arguments) {
    command_line.push_back(PW_SYS_STR(' '));
    ArgumentQuote(argument, command_line);
  }
}

// Environment variables are \0 separated
void MakeEnvironmentBlock(const System::EnvironmentBlock& environment_block,
                          System::StrType& environment_block_win) {
  for (const System::StrType& ev : environment_block) {
    environment_block_win += ev;
    environment_block_win.push_back(PW_SYS_STR('\0'));
  }
  environment_block_win.push_back(PW_SYS_STR('\0'));
}

std::string GetLastErrorAsStr() {
  LPVOID msg_buffer = nullptr;
  size_t size = ::FormatMessageA(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      NULL, ::GetLastError(), MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      (LPSTR)&msg_buffer, 0, NULL);
  std::string error((LPSTR)msg_buffer, size);
  LocalFree(msg_buffer);
  return error;
}

class OutputPipe {
 public:
  static constexpr size_t kReadEndHandle = 0;
  static constexpr size_t kWriteEndHandle = 1;

  ~OutputPipe() {
    CloseReadEnd();
    CloseWriteEnd();
  }

  bool CreateEnds(SECURITY_ATTRIBUTES& saAttr) {
    if (!::CreatePipe(&output_pipe_handles_[kReadEndHandle],
                      &output_pipe_handles_[kWriteEndHandle], &saAttr, 0)) {
      return false;
    }

    if (!::SetHandleInformation(output_pipe_handles_[kReadEndHandle],
                                HANDLE_FLAG_INHERIT, 0)) {
      return false;
    }

    return true;
  }

  void CloseReadEnd() { Close(kReadEndHandle); }
  void CloseWriteEnd() { Close(kWriteEndHandle); }

  HANDLE ReadEndHandle() const { return output_pipe_handles_[kReadEndHandle]; }
  HANDLE WriteEndHandle() const {
    return output_pipe_handles_[kWriteEndHandle];
  }


 private:
  void Close(size_t idx) {
    if (output_pipe_handles_[idx] != nullptr) {
      ::CloseHandle(output_pipe_handles_[idx]);
    }
    output_pipe_handles_[idx] = nullptr;
  }
  HANDLE output_pipe_handles_[2] = {nullptr};
};

}  // namespace

System::StrType System::GetWorkingDirectory() {
  constexpr DWORD kMaxBufferLength = 4096;
  TCHAR buffer[kMaxBufferLength];
  if (::GetCurrentDirectory(kMaxBufferLength, buffer) == 0) {
    return System::StrType{};
  }
  return System::StrType{buffer};
}

int System::Exec(const System::StrType& executable,
                 const System::Arguments& arguments,
                 const System::EnvironmentBlock& environment_block) {
  STARTUPINFO startup_info;
  ZeroMemory(&startup_info, sizeof(STARTUPINFO));
  startup_info.cb = sizeof(STARTUPINFO);

  OutputPipe stdout_pipe;
  OutputPipe stderr_pipe;

  System::StrType command_line;
  ArgumentQuote(executable, command_line);
  MakeCommandLine(arguments, command_line);

  System::StrType environment_block_win;
  MakeEnvironmentBlock(environment_block, environment_block_win);

  PROCESS_INFORMATION process_info;
  ZeroMemory(&process_info, sizeof(PROCESS_INFORMATION));

  BOOL success = ::CreateProcess(
      /*lpApplicationName*/ nullptr,
      /*lpCommandLine*/ command_line.empty() ? nullptr : &command_line[0],
      /*lpProcessAttributes*/ nullptr,
      /*lpThreadAttributes*/ nullptr,
      /*bInheritHandles*/ TRUE,
      /*dwCreationFlags*/ 0
#if defined(UNICODE)
          | CREATE_UNICODE_ENVIRONMENT
#endif  // defined(UNICODE)
      ,
      /*lpEnvironment*/ environment_block_win.empty()
          ? nullptr
          : &environment_block_win[0],
      /*lpCurrentDirectory*/ nullptr,
      /*lpStartupInfo*/ &startup_info,
      /*lpProcessInformation*/ &process_info);

  if (success == FALSE) {
    std::cerr << "process wrapper error: failed to launch a new process: "
              << GetLastErrorAsStr();
    return -1;
  }

  DWORD exit_status;
  WaitForSingleObject(process_info.hProcess, INFINITE);
  if (GetExitCodeProcess(process_info.hProcess, &exit_status) == FALSE)
    exit_status = -1;
  CloseHandle(process_info.hThread);
  CloseHandle(process_info.hProcess);
  return exit_status;
}

}  // namespace process_wrapper
