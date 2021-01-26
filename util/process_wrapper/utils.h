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

#ifndef LIB_PROCESS_WRAPPER_UTILS_H_
#define LIB_PROCESS_WRAPPER_UTILS_H_

#include <string>

#include "util/process_wrapper/system.h"

namespace process_wrapper {

// Converts to and frin the system string format
System::StrType FromUtf8(const std::string& string);
std::string ToUtf8(const System::StrType& string);

// Replaces a token in str by replacement
void ReplaceToken(System::StrType& str, const System::StrType& token,
                  const System::StrType& replacement);

// Reads a file in text mode and feeds each line to item in the vec output
bool ReadFileToArray(const System::StrType& file_path, System::StrVecType& vec);

// Splits input into at most n substrings. If delimiter appears more than n-1 times, the remaining characters will be in the last element of the vector.
// If n == 0, an empty vector will be returned.
std::vector<System::StrType> SplitN(const System::StrType input, const System::StrType::value_type delimiter, const size_t n);

// Makes a value suitable for adding to an environment variables vector.
System::StrType MakeEnv(const System::StrType name, const System::StrType value);

}  // namespace process_wrapper

#endif  // LIB_PROCESS_WRAPPER_UTILS_H_
