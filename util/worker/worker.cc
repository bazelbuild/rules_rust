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
#include <memory>
#include <sstream>
#include <string>
#include <utility>

#include <google/protobuf/io/coded_stream.h>
#include <google/protobuf/io/zero_copy_stream_impl.h>

#include "util/process_wrapper/system.h"
#include "util/process_wrapper/utils.h"
#include "util/worker/worker_protocol.pb.h"

using blaze::worker::WorkRequest;
using blaze::worker::WorkResponse;
using google::protobuf::io::CodedInputStream;
using google::protobuf::io::CodedOutputStream;
using google::protobuf::io::FileInputStream;
using google::protobuf::io::FileOutputStream;

using namespace process_wrapper;

bool ReadRequest(FileInputStream *input, WorkRequest &request)
{
  uint32_t req_len;
  CodedInputStream stream(input);
  if (!stream.ReadVarint32(&req_len)) {
    std::cerr << "Unable to read message length\n";
    return false;
  }

  CodedInputStream::Limit limit = stream.PushLimit(req_len);
  if (!request.MergeFromCodedStream(&stream)) {
    std::cerr << "Unable to merge from stream\n";
    return false;
  }

  if (!stream.ConsumedEntireMessage()) {
    std::cerr << "Did not consume entire message\n";
    return false;
  }

  stream.PopLimit(limit);
  return true;
}

bool HandleRequest(
  const WorkRequest &request,
  WorkResponse &response,
  const System::StrType& exec_path,
  const System::StrType& compilation_mode,
  const System::EnvironmentBlock& environment_block
) {
  System::Arguments arguments;
  // Pre-allocate. +2 for the incremental argument.
  arguments.reserve(request.arguments_size() + 2);

  auto request_args = request.arguments();
  std::string target;
  for (int i = 0; i < request.arguments_size(); i++) {
    auto argument = request.arguments(i);
    // Starts with
    if (argument.rfind("--target=", 0) != std::string::npos) {
      target = argument.substr(9) + '/';
    }
    arguments.push_back(argument);
  }

  // Considering
  // https://github.com/rust-lang/rust/blob/673d0db5e393e9c64897005b470bfeb6d5aec61b/compiler/rustc_incremental/src/persist/fs.rs#L145
  // as the canonical description of how incremental compilation is affected by
  // the choice of directory, it helps to segment based on compilation mode.
  // That prevents the GC phase from clearing the cache of a debug build when running an opt build.
  arguments.push_back("--codegen");
  // TODO: Can be shared across requests to avoid concatenation.
  arguments.push_back("incremental=" + System::GetWorkingDirectory() + "/rustc-target/" + target + compilation_mode + "/incremental");

  // Since the worker is not multiplexed, we can always log to the same file and overwrite on the next request.
  System::StrType stdout_file = System::GetWorkingDirectory() + "/stdout.log";
  System::StrType stderr_file = System::GetWorkingDirectory() + "/stderr.log";

  int exit_code = System::Exec(exec_path, arguments, environment_block,
                               stdout_file, stderr_file);
  std::ifstream source(stderr_file, std::ios::binary);
  std::string stderr_output;
  if (source.fail()) {
    stderr_output = "[worker] Error getting stderr\n";
  } else {
    std::stringstream stderr_stream;
    stderr_stream << source.rdbuf();
    stderr_output = stderr_stream.str();
  }

  response.set_exit_code(exit_code);
  response.set_request_id(request.request_id());
  response.set_output(std::move(stderr_output));
  return true;
}

int RunAsWorker(
  const System::StrType& exec_path,
  const System::StrType& compilation_mode,
  const System::EnvironmentBlock& environment_block
) {
  std::unique_ptr<FileInputStream> input(new FileInputStream(0));
  std::unique_ptr<FileOutputStream> output(new FileOutputStream(1));

  while (true) {
    WorkRequest request;
    if (!ReadRequest(input.get(), request)) {
      return 1;
    }

    WorkResponse response;
    if (!HandleRequest(request, response, exec_path, compilation_mode, environment_block)) {
      return 1;
    }

    // A CodedInputStream will try to move around the underlying buffer when destroyed.
    // If we Flush stdout, that fails. So ensure it goes out of scope before we flush.
    {
      CodedOutputStream coded_out(output.get());
      coded_out.WriteVarint32(response.ByteSize());
      response.SerializeWithCachedSizes(&coded_out);
      if (coded_out.HadError()) {
        std::cerr << "Error serializing response\n";
        return 1;
      }
    }
    output->Flush();
  }

  return 0;
}

int RunStandalone(
  const System::StrType& exec_path,
  const System::EnvironmentBlock& environment_block,
  const System::StrType& param_file_param
) {
  if (param_file_param[0] != '@') {
    std::cerr << "Param file must start with '@', got \"" << param_file_param << "\"\n";
    return -1;
  }

  std::string param_file = ToUtf8(param_file_param).substr(1);
  System::Arguments arguments;

  std::ifstream source(param_file);
  std::string line;
  while (std::getline(source, line)) {
    arguments.push_back(line);
  }

  std::string empty;

  return System::Exec(exec_path, arguments, environment_block, empty, empty);
}

using CharType = process_wrapper::System::StrType::value_type;

int PW_MAIN(int argc, const CharType* argv[], const CharType* envp[]) {
  System::StrType exec_path;
  System::StrType compilation_mode;
  System::StrType param_file;
  System::EnvironmentBlock environment_block;
  // Taking all environment variables from the current process
  // and sending them down to the child process
  for (int i = 0; envp[i] != nullptr; ++i) {
    environment_block.push_back(envp[i]);
  }

  // Have the last values added take precedence over the first.
  // This is simpler than needing to track duplicates and explicitly override them.
  std::reverse(environment_block.begin(), environment_block.end());

  // This will need support for understanding param file argument.
  // As well as parsing other flags generally.

  bool as_worker = false;

  // Processing current process argument list until -- is encountered
  // everthing after gets sent down to the child process
  for (int i = 1; i < argc; ++i) {
    System::StrType arg = argv[i];
    if (arg == PW_SYS_STR("--persistent_worker")) {
      as_worker = true;
    } else if (arg == PW_SYS_STR("--compilation_mode")) {
      if (++i == argc) {
        std::cerr << "--compilation_mode flag missing argument\n";
        return -1;
      }
      compilation_mode = argv[i];
    } else if (arg == PW_SYS_STR("--compiler")) {
      if (++i == argc) {
        std::cerr << "--compiler flag missing argument\n";
        return -1;
      }
      exec_path = argv[i];
    } else if (arg[0] == '@') {
      param_file = arg;
    } else {
      std::cerr << "worker wrapper error: unknown argument \"" << ToUtf8(arg)
                << "\"." << '\n';
      return -1;
    }
  }

  if (as_worker) {
    if (!param_file.empty()) {
      std::cerr << "Param file argument \"" << param_file << "\" not supported in worker mode\n";
      return -1;
    }
    return RunAsWorker(exec_path, compilation_mode, environment_block);
  } else {
    return RunStandalone(exec_path, environment_block, param_file);
  }
}
