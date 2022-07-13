//! Command line interface entry points and utilities

mod generate;
mod query;
mod splice;
mod vendor;

use clap::Parser;

use self::generate::GenerateOptions;
use self::query::QueryOptions;
use self::splice::SpliceOptions;
use self::vendor::VendorOptions;

// Entrypoints
pub use generate::generate;
pub use query::query;
pub use splice::splice;
pub use vendor::vendor;

#[derive(Parser, Debug)]
#[clap(
    name = "cargo-bazel",
    about = "crate_universe` is a collection of tools which use Cargo to generate build targets for Bazel.",
    version
)]
pub enum Options {
    /// Generate Bazel Build files from a Cargo manifest.
    Generate(GenerateOptions),

    /// Splice together disjoint Cargo and Bazel info into a single Cargo workspace manifest.
    Splice(SpliceOptions),

    /// Query workspace info to determine whether or not a repin is needed.
    Query(QueryOptions),

    /// Vendor BUILD files to the workspace with either repository definitions or `cargo vendor` generated sources.
    Vendor(VendorOptions),
}

// Convenience wrappers to avoid dependencies in the binary
pub type Result<T> = anyhow::Result<T>;

pub fn parse_args() -> Options {
    Options::parse()
}
