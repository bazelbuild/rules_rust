// Copyright 2018 The Bazel Authors. All rights reserved.
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

extern crate grpc;
extern crate helloworld_proto;

use grpc::ClientStubExt;
use std::env;
use std::str::FromStr;

use helloworld_proto::*;

fn parse_args() -> (String, u16) {
    let mut name = "world".to_owned();
    let mut port = 50051;
    for arg in env::args().skip(1) {
        if let Some(argp) = arg.strip_prefix("-p=") {
            port = u16::from_str(argp).unwrap()
        } else {
            name = arg.to_owned();
        }
    }
    (name, port)
}

fn main() {
    let (name, port) = parse_args();
    let client = GreeterClient::new_plain("::1", port, Default::default()).unwrap();
    let mut req = HelloRequest::new();
    req.set_name(name);
    let resp = client.say_hello(grpc::RequestOptions::new(), req);
    println!("{:?}", resp.wait());
}
