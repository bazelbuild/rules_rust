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
#include <sstream>

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
    // \\ yields a single \, so \\\ translates to a single \ and a new line escape
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

std::vector<System::StrType> SplitN(const System::StrType input, const System::StrType::value_type delimiter, const size_t n) {
  size_t start = 0;
  std::vector<System::StrType> parts;
  if (n == 0) {
    return parts;
  }

  size_t remaining = n;
  while (--remaining >= 1) {
    size_t end = input.find(delimiter, start);
    if (end == std::string::npos) {
      break;
    } else {
      parts.push_back(input.substr(start, end - start));
      start = end + 1;
      if (end == input.length()) {
         break;
      }
    }
  }
  if (start <= input.length()) {
    parts.push_back(input.substr(start, input.length() - start));
  }
  return parts;
}

System::StrType MakeEnv(const System::StrType name, const System::StrType value) {
#if defined(PW_WIN_UNICODE)
  std::wstringstream env;
#else
  std::stringstream env;
#endif
  env << name;
  env << PW_SYS_STR('=');
  env << value;
  return env.str();
}

}  // namespace process_wrapper
