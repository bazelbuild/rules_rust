use echo_tonic::verily::surgical::echo::{echo_server::Echo, EchoRequest, EchoResponse};
use tonic::{Request, Response, Status};

#[derive(Default)]
pub struct EchoImpl {}

#[tonic::async_trait]
impl Echo for EchoImpl {
    async fn echo(
        &self,
        mut request: Request<EchoRequest>,
    ) -> Result<Response<EchoResponse>, Status> {
        println!("Got a request from {:?}", request.remote_addr());

        let reply = EchoResponse {
            payload: format!("Hello {}!", request.get_ref().payload),
        };

        // Echo the metadata as well.
        let mut response = Response::new(reply);
        std::mem::swap(response.metadata_mut(), request.metadata_mut());
        Ok(response)
    }
}
