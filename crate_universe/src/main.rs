//! The `cargo->bazel` binary's entrypoint

use cargo_bazel::cli;

fn main() -> cli::Result<()> {
    // Parse arguments
    let opt = cli::parse_args();

    match opt {
        cli::Options::Generate(opt) => {
            cli::init_logging("Generate");
            cli::generate(opt)
        }
        cli::Options::Splice(opt) => {
            cli::init_logging("Splice");
            cli::splice(opt)
        }
        cli::Options::Query(opt) => {
            cli::init_logging("Query");
            cli::query(opt)
        }
        cli::Options::Vendor(opt) => {
            cli::init_logging("Vendor");
            cli::vendor(opt)
        }
    }
}
