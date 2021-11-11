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

#include "util/process_wrapper/utils.h"

#include <fstream>
#include <iostream>
#include <streambuf>

#if defined(PW_WIN_UNICODE)
#include <codecvt>
#include <locale>
#endif  // defined(PW_WIN_UNICODE)

namespace process_wrapper {

System::StrType FromUtf8(const std::string& string) {
#if defined(PW_WIN_UNICODE)
  return std::wstring_convert<std::codecvt_utf8<wchar_t>>().from_bytes(string);
#else
  return string;
#endif  // defined(PW_WIN_UNICODE)
}

std::string ToUtf8(const System::StrType& string) {
#if defined(PW_WIN_UNICODE)
  return std::wstring_convert<std::codecvt_utf8<wchar_t>>().to_bytes(string);
#else
  return string;
#endif  // defined(PW_WIN_UNICODE)
}

void ReplaceToken(System::StrType& str, const System::StrType& token,
                  const System::StrType& replacement) {
  std::size_t pos = str.find(token);
  if (pos != std::string::npos) {
    str.replace(pos, token.size(), replacement);
  }
}

bool ReadFileToArray(const System::StrType& file_path,
                     System::StrVecType& vec) {
  std::ifstream file(file_path);
  if (file.fail()) {
    std::cerr << "process wrapper error: failed to open file: "
              << ToUtf8(file_path) << '\n';
    return false;
  }
  std::string read_line, escaped_line;
  while (std::getline(file, read_line)) {
    // handle CRLF files when as they might be
    // written on windows and read from linux
    if (!read_line.empty() && read_line.back() == '\r') {
      read_line.pop_back();
    }
    // Skip empty lines if any
    if (read_line.empty()) {
      continue;
    }

    // a \ at the end of a line allows us to escape the new line break,
    // \\ yields a single \, so \\\ translates to a single \ and a new line
    // escape
    int end_backslash_count = 0;
    for (std::string::reverse_iterator rit = read_line.rbegin();
         rit != read_line.rend() && *rit == '\\'; ++rit) {
      end_backslash_count++;
    }

    // a 0 or pair number of backslashes do not lead to a new line escape
    bool escape = false;
    if (end_backslash_count & 1) {
      escape = true;
    }

    // remove backslashes
    while (end_backslash_count > 0) {
      end_backslash_count -= 2;
      read_line.pop_back();
    }

    if (escape) {
      read_line.push_back('\n');
      escaped_line += read_line;
    } else {
      vec.push_back(FromUtf8(escaped_line + read_line));
      escaped_line.clear();
    }
  }
  return true;
}

bool ReadStampStatusToArray(
    const System::StrType& stamp_path,
    std::vector<std::pair<System::StrType, System::StrType>>& vec) {
  // Read each line of the stamp file and split on the first space
  System::StrVecType stamp_block;
  if (!ReadFileToArray(stamp_path, stamp_block)) {
    return false;
  }

  for (System::StrVecType::size_type i = 0; i < stamp_block.size(); ++i) {
    size_t space_pos = stamp_block[i].find(' ');
    if (space_pos == std::string::npos) {
      std::cerr << "process wrapper error: wrong workspace status file "
                   "format for \""
                << ToUtf8(stamp_block[i]) << "\".\n";
      return false;
    }
    System::StrType key = stamp_block[i].substr(0, space_pos);
    System::StrType value =
        stamp_block[i].substr(space_pos + 1, stamp_block[i].size());
    vec.push_back({std::move(key), std::move(value)});
  }

  return true;
}

}  // namespace process_wrapper
