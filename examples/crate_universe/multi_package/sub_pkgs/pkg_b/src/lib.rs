//! Demo code for rustls

use rustls::{client::ClientConfig, Certificate, RootCertStore};
use std::sync::Arc;

/// Initializes a rustls `ClientConfig` with a provided `RootCertStore`.
///
/// Optionally, you can provide a fake certificate in DER format for testing purposes.
///
/// # Arguments
/// * `fake_cert` - Optional fake certificate in DER format.
///
/// # Returns
/// An `Arc`-wrapped `ClientConfig`.
pub fn init_client_config(
    fake_cert: Option<&[u8]>,
) -> Result<Arc<ClientConfig>, Box<dyn std::error::Error>> {
    // Initialize an empty RootCertStore
    let mut root_store = RootCertStore::empty();

    // If a fake certificate is provided, try adding it to the root store
    if let Some(cert_der) = fake_cert {
        let certificate = Certificate(cert_der.to_vec());
        root_store.add(&certificate)?;
    }

    // Create a ClientConfig with the root store
    let config = Arc::new(
        ClientConfig::builder()
            .with_safe_defaults()
            .with_root_certificates(root_store)
            .with_no_client_auth(),
    );

    Ok(config)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_init_client_config_without_cert() {
        // Call the library function without providing a fake certificate
        let result = init_client_config(None);

        // Assert that the initialization was successful
        assert!(
            result.is_ok(),
            "Failed to initialize ClientConfig without certificate"
        );
    }
}
