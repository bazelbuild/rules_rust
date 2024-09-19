//! A tool for building runfiles directories for Bazel environments that don't
//! support runfiles or have runfiles disabled.

use std::collections::BTreeMap;
use std::path::PathBuf;

struct Args {
    pub output_dir: PathBuf,
    pub runfiles: BTreeMap<PathBuf, PathBuf>,
}

impl Args {
    fn parse() -> Self {
        let args_file = std::env::args().nth(1).expect("No args file was passed.");

        let content = std::fs::read_to_string(
            args_file
                .strip_prefix('@')
                .expect("Param files should start with @"),
        )
        .unwrap();
        let mut args = content.lines();

        let output_dir = PathBuf::from(
            args.next()
                .unwrap_or_else(|| panic!("Not enough arguments provided.")),
        );
        let runfiles = args
            .map(|s| {
                let s = if s.starts_with('\'') && s.ends_with('\'') {
                    s.trim_matches('\'')
                } else {
                    s
                };
                let (src, dest) = s
                    .split_once('=')
                    .unwrap_or_else(|| panic!("Unexpected runfiles argument: {}", s));
                (PathBuf::from(src), PathBuf::from(dest))
            })
            .collect::<BTreeMap<_, _>>();

        assert!(!runfiles.is_empty(), "No runfiles found");

        Args {
            output_dir,
            runfiles,
        }
    }
}

fn main() {
    let args = Args::parse();

    for (src, dest) in args.runfiles.iter() {
        let out_dest = args.output_dir.join(dest);
        std::fs::create_dir_all(
            out_dest
                .parent()
                .expect("The output location should have a valid parent."),
        )
        .expect("Failed to create output directory");
        std::fs::copy(src, &out_dest).unwrap_or_else(|e| {
            panic!(
                "Failed to copy file {} -> {}\n{:?}",
                src.display(),
                out_dest.display(),
                e
            )
        });
    }
}
