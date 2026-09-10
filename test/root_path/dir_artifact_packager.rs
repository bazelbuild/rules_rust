//! A tool which copies source files into the `src` subdirectory of a directory artifact.

use std::path::PathBuf;

fn main() {
    let mut args = std::env::args_os().skip(1).map(PathBuf::from);

    let outdir = args.next().expect("No output directory was provided");
    let dest = outdir.join("src");
    std::fs::create_dir_all(&dest)
        .unwrap_or_else(|e| panic!("Failed to create `{}`\n{:?}", dest.display(), e));

    for src in args {
        let name = src
            .file_name()
            .unwrap_or_else(|| panic!("Source `{}` has no file name", src.display()));
        std::fs::copy(&src, dest.join(name))
            .unwrap_or_else(|e| panic!("Failed to copy `{}`\n{:?}", src.display(), e));
    }
}
