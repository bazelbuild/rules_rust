use std::fs;
use std::path::{Path, PathBuf};

const USAGE: &str = r#"usage: doc_merger --output <dir> --inputs <dir>...

Merges multiple rustdoc output directories into a single documentation tree.

Args:
  --output: Directory to write the merged documentation to.
  --inputs: Rustdoc output directories to copy into the output directory, in
    order. Later directories overwrite colliding files from earlier ones, so
    the directory produced by `rustdoc --merge=finalize` must be passed last.
"#;

macro_rules! die {
    ($($arg:tt)*) => {
        {
            eprintln!($($arg)*);
            std::process::exit(1);
        }
    };
}

struct Args {
    output: PathBuf,
    inputs: Vec<PathBuf>,
}

fn parse_args() -> Args {
    let mut output = None;
    let mut inputs = Vec::new();

    #[derive(PartialEq)]
    enum State {
        None,
        Output,
        Inputs,
    }

    let mut state = State::None;
    for arg in std::env::args().skip(1) {
        match arg.as_str() {
            "--output" => state = State::Output,
            "--inputs" => state = State::Inputs,
            _ => match state {
                State::Output => {
                    output = Some(PathBuf::from(&arg));
                    state = State::None;
                }
                State::Inputs => inputs.push(PathBuf::from(&arg)),
                State::None => die!("unexpected argument `{}`\n{}", arg, USAGE),
            },
        }
    }

    let output = output.unwrap_or_else(|| die!("missing --output\n{}", USAGE));
    if inputs.is_empty() {
        die!("missing --inputs\n{}", USAGE);
    }

    Args { output, inputs }
}

/// Recursively copy the contents of `src` into `dst`, overwriting existing files.
fn copy_tree(src: &Path, dst: &Path) {
    let entries = fs::read_dir(src)
        .unwrap_or_else(|e| die!("fatal: failed to read directory {}: {}", src.display(), e));
    for entry in entries {
        let entry = entry
            .unwrap_or_else(|e| die!("fatal: failed to read entry in {}: {}", src.display(), e));
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());
        let file_type = entry
            .file_type()
            .unwrap_or_else(|e| die!("fatal: failed to stat {}: {}", src_path.display(), e));

        // rustdoc leaves a write-only `.lock` flock file in its output
        // directory which is not part of the documentation.
        if entry.file_name() == ".lock" {
            continue;
        }

        // Tree artifact inputs may be exposed as symlinks; resolve them.
        let is_dir = if file_type.is_symlink() {
            src_path.is_dir()
        } else {
            file_type.is_dir()
        };

        if is_dir {
            fs::create_dir_all(&dst_path)
                .unwrap_or_else(|e| die!("fatal: failed to create {}: {}", dst_path.display(), e));
            copy_tree(&src_path, &dst_path);
        } else {
            // Copies preserve permissions, so an earlier copy of a read-only
            // file must be removed before it can be overwritten.
            if let Err(first_error) = fs::copy(&src_path, &dst_path) {
                let _ = fs::remove_file(&dst_path);
                fs::copy(&src_path, &dst_path).unwrap_or_else(|_| {
                    die!(
                        "fatal: failed to copy {} to {}: {}",
                        src_path.display(),
                        dst_path.display(),
                        first_error
                    )
                });
            }
        }
    }
}

fn main() {
    let args = parse_args();

    fs::create_dir_all(&args.output)
        .unwrap_or_else(|e| die!("fatal: failed to create {}: {}", args.output.display(), e));

    for input in &args.inputs {
        copy_tree(input, &args.output);
    }
}
