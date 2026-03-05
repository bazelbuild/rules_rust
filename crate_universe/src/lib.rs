#![allow(clippy::large_enum_variant)]

use std::sync::LazyLock;

pub mod api;

pub mod cli;

pub fn ensure_tls_provider() {
    static INIT: LazyLock<()> = LazyLock::new(|| {
        rustls::crypto::ring::default_provider()
            .install_default()
            .expect("Failed to install rustls crypto provider");
    });
    *INIT;
}

mod config;
mod context;
mod lockfile;
mod metadata;
mod rendering;
mod select;
mod splicing;
mod utils;

#[cfg(test)]
mod test;
