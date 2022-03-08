//! The `cargo->bazel` binary's entrypoint

use cargo_bazel::cli;

fn main() -> cli::Result<()> {
    // Parse arguments
    let opt = cli::parse_args();

    match opt {
        cli::Options::Generate(opt) => cli::generate(opt),
        cli::Options::Splice(opt) => cli::splice(opt),
        cli::Options::Query(opt) => cli::query(opt),
        cli::Options::Vendor(opt) => cli::vendor(opt),
    }
}
