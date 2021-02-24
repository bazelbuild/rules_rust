// Copyright 2020 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <algorithm>
#include <fstream>
#include <iostream>
#include <string>
#include <utility>

#include "util/process_wrapper/system.h"
#include "util/process_wrapper/utils.h"

using CharType = process_wrapper::System::StrType::value_type;

// Simple process wrapper allowing us to not depend on the shell to run a
// process to perform basic operations like capturing the output or having
// the $pwd used in command line arguments or environment variables
int PW_MAIN(int argc, const CharType* argv[], const CharType* envp[]) {
  using namespace process_wrapper;

  System::EnvironmentBlock environment_block;
  // Taking all environment variables from the current process
  // and sending them down to the child process
  for (int i = 0; envp[i] != nullptr; ++i) {
    environment_block.push_back(envp[i]);
  }

  using Subst = std::pair<System::StrType, System::StrType>;

  System::StrType exec_path;
  std::vector<Subst> subst_mappings;
  System::StrType stdout_file;
  System::StrType stderr_file;
  System::StrType touch_file;
  System::StrType copy_source;
  System::StrType copy_dest;
  System::Arguments arguments;
  System::Arguments file_arguments;

  // Processing current process argument list until -- is encountered
  // everthing after gets sent down to the child process
  for (int i = 1; i < argc; ++i) {
    System::StrType arg = argv[i];
    if (++i == argc) {
      std::cerr << "process wrapper error: argument \"" << ToUtf8(arg)
                << "\" missing parameter.\n";
      return -1;
    }
    if (arg == PW_SYS_STR("--subst")) {
      System::StrType subst = argv[i];
      size_t equal_pos = subst.find('=');
      if (equal_pos == std::string::npos) {
        std::cerr << "process wrapper error: wrong substituion format for \""
                  << ToUtf8(subst) << "\".\n";
        return -1;
      }
      System::StrType key = subst.substr(0, equal_pos);
      if (key.empty()) {
        std::cerr << "process wrapper error: empty key for substituion \""
                  << ToUtf8(subst) << "\".\n";
        return -1;
      }
      System::StrType value = subst.substr(equal_pos + 1, subst.size());
      if (value == PW_SYS_STR("${pwd}")) {
        value = System::GetWorkingDirectory();
      }
      subst_mappings.push_back({std::move(key), std::move(value)});
    } else if (arg == PW_SYS_STR("--env-file")) {
      if (!ReadFileToArray(argv[i], environment_block)) {
        return -1;
      }
    } else if (arg == PW_SYS_STR("--arg-file")) {
      if (!ReadFileToArray(argv[i], file_arguments)) {
        return -1;
      }
    } else if (arg == PW_SYS_STR("--touch-file")) {
      if (!touch_file.empty()) {
        std::cerr << "process wrapper error: \"--touch-file\" can only appear "
                     "once.\n";
        return -1;
      }
      touch_file = argv[i];
    } else if (arg == PW_SYS_STR("--copy-output")) {
      // i is already at the first arg position, accountint we need another arg
      // and then -- executable_name.
      if (i + 1 > argc) {
        std::cerr
            << "process wrapper error: \"--copy-output\" needs 2 parameters.\n";
        return -1;
      }
      if (!copy_source.empty() || !copy_dest.empty()) {
        std::cerr << "process wrapper error: \"--copy-output\" can only appear "
                     "once.\n";
        return -1;
      }
      copy_source = argv[i];
      copy_dest = argv[++i];
      if (copy_source == copy_dest) {
        std::cerr << "process wrapper error: \"--copy-output\" source and dest "
                     "need to be different.\n";
        return -1;
      }
    } else if (arg == PW_SYS_STR("--stdout-file")) {
      if (!stdout_file.empty()) {
        std::cerr << "process wrapper error: \"--stdout-file\" can only appear "
                     "once.\n";
        return -1;
      }
      stdout_file = argv[i];
    } else if (arg == PW_SYS_STR("--stderr-file")) {
      if (!stderr_file.empty()) {
        std::cerr << "process wrapper error: \"--stderr-file\" can only appear "
                     "once.\n";
        return -1;
      }
      stderr_file = argv[i];
    } else if (arg == PW_SYS_STR("--")) {
      exec_path = argv[i];
      for (++i; i < argc; ++i) {
        arguments.push_back(argv[i]);
      }
      // after we consume all arguments we append the files arguments
      for (const System::StrType& file_arg : file_arguments) {
        arguments.push_back(file_arg);
      }
    } else {
      std::cerr << "process wrapper error: unknow argument \"" << ToUtf8(arg)
                << "\"." << '\n';
      return -1;
    }
  }

  if (subst_mappings.size()) {
    for (const Subst& subst : subst_mappings) {
      System::StrType token = PW_SYS_STR("${");
      token += subst.first;
      token.push_back('}');
      for (System::StrType& arg : arguments) {
        ReplaceToken(arg, token, subst.second);
      }

      for (System::StrType& env : environment_block) {
        ReplaceToken(env, token, subst.second);
      }
    }
  }

  // Have the last values added take precedence over the first.
  // This is simpler than needing to track duplicates and explicitly override them.
  std::reverse(environment_block.begin(), environment_block.end());

  int exit_code = System::Exec(exec_path, arguments, environment_block,
                               stdout_file, stderr_file);
  if (exit_code == 0) {
    if (!touch_file.empty()) {
      std::ofstream file(touch_file);
      if (file.fail()) {
        std::cerr << "process wrapper error: failed to create touch file: \""
                  << ToUtf8(touch_file) << "\"\n";
        return -1;
      }
      file.close();
    }

    // we perform a copy of the output if necessary
    if (!copy_source.empty() && !copy_dest.empty()) {
      std::ifstream source(copy_source, std::ios::binary);
      if (source.fail()) {
        std::cerr << "process wrapper error: failed to open copy source: \""
                  << ToUtf8(copy_source) << "\"\n";
        return -1;
      }
      std::ofstream dest(copy_dest, std::ios::binary);
      if (dest.fail()) {
        std::cerr << "process wrapper error: failed to open copy dest: \""
                  << ToUtf8(copy_dest) << "\"\n";
        return -1;
      }
      dest << source.rdbuf();
    }
  }
  return exit_code;
}
