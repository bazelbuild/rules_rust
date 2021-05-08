use tonic::{transport::Server, Request, Response, Status};

use echo_tonic::verily::surgical::echo::echo_server::{Echo, EchoServer};
use echo_tonic::verily::surgical::echo::{EchoRequest, EchoResponse};

#[derive(Default)]
pub struct EchoImpl {}

#[tonic::async_trait]
impl Echo for EchoImpl {
    async fn echo(&self, request: Request<EchoRequest>) -> Result<Response<EchoResponse>, Status> {
        println!("Got a request from {:?}", request.remote_addr());

        let reply = EchoResponse {
            payload: format!("Hello {}!", request.into_inner().payload),
        };
        Ok(Response::new(reply))
    }
}

#[cfg(test)]
#[test]
fn structs_are_usable() {
    Server::builder().add_service(EchoServer::new(EchoImpl::default()));
}
