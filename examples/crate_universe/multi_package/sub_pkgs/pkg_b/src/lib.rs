//! Demo code for rustls

use rustls::client::ClientConfig;
use rustls::pki_types::CertificateDer;
use rustls::RootCertStore;
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
    let mut root_store = RootCertStore::empty();

    if let Some(cert_der) = fake_cert {
        let certificate = CertificateDer::from(cert_der.to_vec());
        root_store.add(certificate)?;
    }

    let config = Arc::new(
        ClientConfig::builder()
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
        let result = init_client_config(None);

        assert!(
            result.is_ok(),
            "Failed to initialize ClientConfig without certificate"
        );
    }
}
