use echo_prost::verily::surgical::echo::{EchoRequest, EchoResponse};

#[cfg(test)]
#[test]
fn structs_are_usable() {
    let request = EchoRequest {
        payload: "hello".to_owned(),
    };
    let response = EchoResponse {
        payload: "hello".to_owned(),
    };

    assert_eq!(request.payload, response.payload);
}
