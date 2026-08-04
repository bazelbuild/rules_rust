use anyhow::{Context, Result};

pub fn request(url: &str) -> Result<reqwest::blocking::Response> {
    reqwest::blocking::get(url).context("Failed to make request")
}

#[cfg(test)]
mod test {
    use super::*;

    use httpmock::prelude::*;

    #[test]
    fn test_request() {
        // Start a lightweight mock server.
        let server = MockServer::start();

        // Create a mock on the server.
        let hello_mock = server.mock(|when, then| {
            when.method(GET)
                .path("/translate")
                .query_param("word", "hello");
            then.status(200)
                .header("content-type", "text/html; charset=UTF-8")
                .body("Hallo");
        });

        // Send an HTTP request to the mock server. This simulates your code.
        let response = request(&server.url("/translate?word=hello")).unwrap();

        // Ensure the specified mock was called exactly one time (or fail with a detailed error description).
        hello_mock.assert();

        // Ensure the mock server did respond as specified.
        assert_eq!(response.status(), 200);

        // Ensure the body contains the results we expect
        assert_eq!(response.text().unwrap(), "Hallo")
    }
}
