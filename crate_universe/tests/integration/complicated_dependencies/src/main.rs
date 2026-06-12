//! Minimal binary that links against the openssl crate fetched by this
//! module's `crate.from_specs` extension and prints the linked OpenSSL
//! version. Consuming modules execute it to verify the transitively-fetched
//! crate is reachable and runnable end-to-end.

fn main() {
    println!("{}", openssl::version::version());
}
