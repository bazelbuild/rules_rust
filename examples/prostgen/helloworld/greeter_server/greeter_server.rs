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

use helloworld_proto::helloworld::{HelloReply, HelloRequest, greeter_server::{Greeter, GreeterServer}};
use std::env;
use std::str::FromStr;
use tonic::{Request, Response, Status, transport::Server};

#[derive(Default)]
struct GreeterImpl;

#[tonic::async_trait]
impl Greeter for GreeterImpl {
    async fn say_hello(
        &self,
        request: Request<HelloRequest>,
    ) -> Result<Response<HelloReply>, Status> {
        let name = request.into_inner().name;
        let return_value = if name.is_empty() { "world".to_string() } else { name.clone() };
        println!("Got a request from {:?}", return_value);
        Ok(Response::new(HelloReply{message: format!("Hello {}", return_value)}))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let port = u16::from_str(&env::args().nth(1).unwrap_or_else(|| "50051".to_owned())).unwrap();
    let addr = format!("[::1]:{}", port).parse().unwrap();
    
    let greeter = GreeterImpl::default();

    println!("greeter server started on port {}", port);

    Server::builder()
        .add_service(GreeterServer::new(greeter))
        .serve(addr)
        .await?;

    Ok(())
}
