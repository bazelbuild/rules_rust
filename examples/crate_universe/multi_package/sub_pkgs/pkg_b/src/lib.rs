//! A reimplementation of https://github.com/rustls/rustls/blob/v/0.20.8/rustls/tests/client_cert_verifier.rs

use std::io;
use std::sync::Arc;

use rustls::client::WebPkiVerifier;
use rustls::server::{ClientCertVerified, ClientCertVerifier};
use rustls::PrivateKey;
use rustls::{Certificate, DistinguishedNames, Error, ServerConfig, SignatureScheme};

macro_rules! embed_files {
    (
        $(
            ($name:ident, $keytype:expr, $path:expr);
        )+
    ) => {
        $(
            const $name: &'static [u8] = include_bytes!(
                concat!(env!("CARGO_MANIFEST_DIR"), "/data/ca/", $keytype, "/", $path));
        )+

        pub fn bytes_for(keytype: &str, path: &str) -> &'static [u8] {
            match (keytype, path) {
                $(
                    ($keytype, $path) => $name,
                )+
                _ => panic!("unknown keytype {} with path {}", keytype, path),
            }
        }
    }
}

embed_files! {
    (ECDSA_CA_CERT, "ecdsa", "ca.cert");
    (ECDSA_CLIENT_FULLCHAIN, "ecdsa", "client.fullchain");
    (ECDSA_CLIENT_KEY, "ecdsa", "client.key");
    (ECDSA_END_FULLCHAIN, "ecdsa", "end.fullchain");
    (ECDSA_END_KEY, "ecdsa", "end.key");

    (EDDSA_CA_CERT, "eddsa", "ca.cert");
    (EDDSA_CLIENT_FULLCHAIN, "eddsa", "client.fullchain");
    (EDDSA_CLIENT_KEY, "eddsa", "client.key");
    (EDDSA_END_FULLCHAIN, "eddsa", "end.fullchain");
    (EDDSA_END_KEY, "eddsa", "end.key");

    (RSA_CA_CERT, "rsa", "ca.cert");
    (RSA_CLIENT_FULLCHAIN, "rsa", "client.fullchain");
    (RSA_CLIENT_KEY, "rsa", "client.key");
    (RSA_END_FULLCHAIN, "rsa", "end.fullchain");
    (RSA_END_KEY, "rsa", "end.key");
}

#[derive(Clone, Copy, PartialEq)]
pub enum KeyType {
    Rsa,
    Ecdsa,
    Ed25519,
}

pub static ALL_KEY_TYPES: [KeyType; 3] = [KeyType::Rsa, KeyType::Ecdsa, KeyType::Ed25519];

impl KeyType {
    fn bytes_for(&self, part: &str) -> &'static [u8] {
        match self {
            Self::Rsa => bytes_for("rsa", part),
            Self::Ecdsa => bytes_for("ecdsa", part),
            Self::Ed25519 => bytes_for("eddsa", part),
        }
    }

    pub fn get_chain(&self) -> Vec<Certificate> {
        rustls_pemfile::certs(&mut io::BufReader::new(self.bytes_for("end.fullchain")))
            .unwrap()
            .iter()
            .map(|v| Certificate(v.clone()))
            .collect()
    }

    pub fn get_key(&self) -> PrivateKey {
        PrivateKey(
            rustls_pemfile::pkcs8_private_keys(&mut io::BufReader::new(self.bytes_for("end.key")))
                .unwrap()[0]
                .clone(),
        )
    }

    pub fn get_client_chain(&self) -> Vec<Certificate> {
        rustls_pemfile::certs(&mut io::BufReader::new(self.bytes_for("client.fullchain")))
            .unwrap()
            .iter()
            .map(|v| Certificate(v.clone()))
            .collect()
    }

    pub fn get_client_key(&self) -> PrivateKey {
        PrivateKey(
            rustls_pemfile::pkcs8_private_keys(&mut io::BufReader::new(
                self.bytes_for("client.key"),
            ))
            .unwrap()[0]
                .clone(),
        )
    }
}

#[derive(Debug)]
pub enum ErrorFromPeer {
    Client(Error),
    Server(Error),
}

pub struct MockClientVerifier {
    pub verified: fn() -> Result<ClientCertVerified, Error>,
    pub subjects: Option<DistinguishedNames>,
    pub mandatory: Option<bool>,
    pub offered_schemes: Option<Vec<SignatureScheme>>,
}

impl ClientCertVerifier for MockClientVerifier {
    fn client_auth_mandatory(&self) -> Option<bool> {
        self.mandatory
    }

    fn client_auth_root_subjects(&self) -> Option<DistinguishedNames> {
        self.subjects.as_ref().cloned()
    }

    fn verify_client_cert(
        &self,
        _end_entity: &Certificate,
        _intermediates: &[Certificate],
        _now: std::time::SystemTime,
    ) -> Result<ClientCertVerified, Error> {
        (self.verified)()
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        if let Some(schemes) = &self.offered_schemes {
            schemes.clone()
        } else {
            WebPkiVerifier::verification_schemes()
        }
    }
}

pub fn server_config_with_verifier(
    kt: KeyType,
    client_cert_verifier: MockClientVerifier,
) -> ServerConfig {
    ServerConfig::builder()
        .with_safe_defaults()
        .with_client_cert_verifier(Arc::new(client_cert_verifier))
        .with_single_cert(kt.get_chain(), kt.get_key())
        .unwrap()
}

#[cfg(test)]
mod test {
    use super::*;

    use std::convert::TryInto;
    use std::io;
    use std::ops::{Deref, DerefMut};
    use std::sync::Arc;

    use rustls::internal::msgs::base::PayloadU16;
    use rustls::server::ClientCertVerified;
    use rustls::{
        ClientConfig, ClientConnection, ConnectionCommon, Error, RootCertStore, ServerConfig,
        ServerConnection, SideData,
    };

    fn assert_debug_eq<T>(err: T, expect: T)
    where
        T: std::fmt::Debug,
    {
        assert_eq!(format!("{err:?}"), format!("{expect:?}"));
    }

    fn finish_client_config_with_creds(
        kt: KeyType,
        config: rustls::ConfigBuilder<ClientConfig, rustls::WantsVerifier>,
    ) -> ClientConfig {
        let mut root_store = RootCertStore::empty();
        let mut rootbuf = io::BufReader::new(kt.bytes_for("ca.cert"));
        root_store.add_parsable_certificates(&rustls_pemfile::certs(&mut rootbuf).unwrap());

        config
            .with_root_certificates(root_store)
            .with_single_cert(kt.get_client_chain(), kt.get_client_key())
            .unwrap()
    }

    fn make_client_config_with_versions_with_auth(
        kt: KeyType,
        versions: &[&'static rustls::SupportedProtocolVersion],
    ) -> ClientConfig {
        let builder = ClientConfig::builder()
            .with_safe_default_cipher_suites()
            .with_safe_default_kx_groups()
            .with_protocol_versions(versions)
            .unwrap();
        finish_client_config_with_creds(kt, builder)
    }

    fn get_client_root_store(kt: KeyType) -> RootCertStore {
        let roots = kt.get_chain();
        let mut client_auth_roots = RootCertStore::empty();
        for root in roots {
            client_auth_roots.add(&root).unwrap();
        }
        client_auth_roots
    }

    fn do_handshake_until_error(
        client: &mut ClientConnection,
        server: &mut ServerConnection,
    ) -> Result<(), ErrorFromPeer> {
        while server.is_handshaking() || client.is_handshaking() {
            transfer(client, server);
            server
                .process_new_packets()
                .map_err(ErrorFromPeer::Server)?;
            transfer(server, client);
            client
                .process_new_packets()
                .map_err(ErrorFromPeer::Client)?;
        }

        Ok(())
    }

    fn transfer(
        left: &mut (impl DerefMut + Deref<Target = ConnectionCommon<impl SideData>>),
        right: &mut (impl DerefMut + Deref<Target = ConnectionCommon<impl SideData>>),
    ) -> usize {
        let mut buf = [0u8; 262144];
        let mut total = 0;

        while left.wants_write() {
            let sz = {
                let into_buf: &mut dyn io::Write = &mut &mut buf[..];
                left.write_tls(into_buf).unwrap()
            };
            total += sz;
            if sz == 0 {
                return total;
            }

            let mut offs = 0;
            loop {
                let from_buf: &mut dyn io::Read = &mut &buf[offs..sz];
                offs += right.read_tls(from_buf).unwrap();
                if sz == offs {
                    break;
                }
            }
        }

        total
    }

    fn dns_name(name: &'static str) -> rustls::ServerName {
        name.try_into().unwrap()
    }

    fn make_pair_for_arc_configs(
        client_config: &Arc<ClientConfig>,
        server_config: &Arc<ServerConfig>,
    ) -> (ClientConnection, ServerConnection) {
        (
            ClientConnection::new(Arc::clone(client_config), dns_name("localhost")).unwrap(),
            ServerConnection::new(Arc::clone(server_config)).unwrap(),
        )
    }

    fn ver_ok() -> Result<ClientCertVerified, Error> {
        Ok(rustls::server::ClientCertVerified::assertion())
    }

    #[test]
    // Happy path, we resolve to a root, it is verified OK, should be able to connect
    fn client_verifier_works() {
        for kt in ALL_KEY_TYPES.iter() {
            let client_verifier = MockClientVerifier {
                verified: ver_ok,
                subjects: Some(
                    get_client_root_store(*kt)
                        .roots
                        .iter()
                        .map(|r| PayloadU16(r.subject().to_vec()))
                        .collect(),
                ),
                mandatory: Some(true),
                offered_schemes: None,
            };

            let server_config = server_config_with_verifier(*kt, client_verifier);
            let server_config = Arc::new(server_config);

            for version in rustls::ALL_VERSIONS {
                let client_config = make_client_config_with_versions_with_auth(*kt, &[version]);
                let (mut client, mut server) =
                    make_pair_for_arc_configs(&Arc::new(client_config.clone()), &server_config);
                let err = do_handshake_until_error(&mut client, &mut server);
                assert_debug_eq(err, Ok(()));
            }
        }
    }
}
