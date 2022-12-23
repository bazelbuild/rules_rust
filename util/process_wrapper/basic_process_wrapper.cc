#include <algorithm>
#include <fstream>
#include <iostream>
#include <string>
#include <utility>

#include "util/process_wrapper/system.h"

using CharType = process_wrapper::System::StrType::value_type;

// A basic process wrapper whose only purpose is to preserve determinism when
// building the true process wrapper. We do this by passing --remap-path-prefix=$pwd=
// to the command line.
int PW_MAIN(int argc, const CharType* argv[], const CharType* envp[]) {
  using namespace process_wrapper;

  System::EnvironmentBlock environment_block;

  // Taking all environment variables from the current process
  // and sending them down to the child process
  for (int i = 0; envp[i] != nullptr; ++i) {
    environment_block.push_back(envp[i]);
  }

  System::StrType exec_path = argv[1];

  System::Arguments arguments;

  for (int i = 2; i < argc; ++i) {
    arguments.push_back(argv[i]);
  }
  System::StrType pwd_prefix =
      PW_SYS_STR("--remap-path-prefix=") + System::GetWorkingDirectory() + PW_SYS_STR("=");
  arguments.push_back(pwd_prefix);

  return System::Exec(exec_path, arguments, environment_block);
}
