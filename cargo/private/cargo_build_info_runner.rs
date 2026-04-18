//! Process wrapper for `CargoBuildInfo` actions.
//!
//! Copies source files into an OUT_DIR and writes metadata files
//! (env, dep_env, flags, link_flags, link_search_paths) consumed by `BuildInfo`.

use std::fs;
use std::path::Path;

struct Args {
    /// Directory path for the `OUT_DIR` output tree.
    out_dir: String,
    /// Files to copy into `out_dir` as `(dest_relative_path, src_path)` pairs.
    files: Vec<(String, String)>,
    /// Output path for the `BuildInfo.rustc_env` file (one `K=V` per line).
    env_out: String,
    /// Output path for the `BuildInfo.flags` file (one rustc flag per line).
    flags_out: String,
    /// Output path for the `BuildInfo.linker_flags` file (one linker flag per line).
    link_flags_out: String,
    /// Output path for the `BuildInfo.link_search_paths` file (one `-Lnative=` path per line).
    link_search_paths_out: String,
    /// Output path for the `BuildInfo.dep_env` file (one `K=V` per line, already prefixed).
    dep_env_out: String,
    /// Extra flags to pass to rustc, written to `flags_out`.
    rustc_flags: Vec<String>,
    /// Extra environment variables for rustc as `K=V`, written to `env_out`.
    rustc_envs: Vec<String>,
    /// Dependency environment variables as `K=V`, written to `dep_env_out`.
    dep_envs: Vec<String>,
    /// Linker flags derived from `CcInfo` (e.g. `-lstatic=crypto`), written to `link_flags_out`.
    link_flags: Vec<String>,
    /// Library search paths derived from `CcInfo`, formatted as `-Lnative=` and written to `link_search_paths_out`.
    link_search_paths: Vec<String>,
}

impl Args {
    /// Parse command line arguments.
    fn parse() -> Self {
        let mut out_dir: Option<String> = None;
        let mut files = Vec::new();
        let mut env_out: Option<String> = None;
        let mut flags_out: Option<String> = None;
        let mut link_flags_out: Option<String> = None;
        let mut link_search_paths_out: Option<String> = None;
        let mut dep_env_out: Option<String> = None;
        let mut rustc_flags = Vec::new();
        let mut rustc_envs = Vec::new();
        let mut dep_envs = Vec::new();
        let mut link_flags = Vec::new();
        let mut link_search_paths = Vec::new();

        for mut arg in std::env::args().skip(1) {
            if arg.starts_with("--out_dir=") {
                out_dir = Some(arg.split_off("--out_dir=".len()));
            } else if arg.starts_with("--file=") {
                let val = arg.split_off("--file=".len());
                let (dest, src) = val
                    .split_once('=')
                    .unwrap_or_else(|| panic!("--file value must be dest=src, got: {val}"));
                files.push((dest.to_owned(), src.to_owned()));
            } else if arg.starts_with("--env_out=") {
                env_out = Some(arg.split_off("--env_out=".len()));
            } else if arg.starts_with("--flags_out=") {
                flags_out = Some(arg.split_off("--flags_out=".len()));
            } else if arg.starts_with("--link_flags=") {
                link_flags_out = Some(arg.split_off("--link_flags=".len()));
            } else if arg.starts_with("--link_search_paths=") {
                link_search_paths_out = Some(arg.split_off("--link_search_paths=".len()));
            } else if arg.starts_with("--dep_env_out=") {
                dep_env_out = Some(arg.split_off("--dep_env_out=".len()));
            } else if arg.starts_with("--rustc_flag=") {
                rustc_flags.push(arg.split_off("--rustc_flag=".len()));
            } else if arg.starts_with("--rustc_env=") {
                rustc_envs.push(arg.split_off("--rustc_env=".len()));
            } else if arg.starts_with("--dep_env=") {
                dep_envs.push(arg.split_off("--dep_env=".len()));
            } else if arg.starts_with("--link_flag=") {
                link_flags.push(arg.split_off("--link_flag=".len()));
            } else if arg.starts_with("--link_search_path=") {
                link_search_paths.push(arg.split_off("--link_search_path=".len()));
            } else {
                panic!("cargo_build_info_runner: unknown argument: {arg}");
            }
        }

        Args {
            out_dir: out_dir.expect("--out_dir is required"),
            files,
            env_out: env_out.expect("--env_out is required"),
            flags_out: flags_out.expect("--flags_out is required"),
            link_flags_out: link_flags_out.expect("--link_flags is required"),
            link_search_paths_out: link_search_paths_out.expect("--link_search_paths is required"),
            dep_env_out: dep_env_out.expect("--dep_env_out is required"),
            rustc_flags,
            rustc_envs,
            dep_envs,
            link_flags,
            link_search_paths,
        }
    }
}

fn write_lines(path: &str, lines: &[String]) {
    let content = if lines.is_empty() {
        String::new()
    } else {
        lines.join("\n")
    };
    fs::write(path, content).unwrap_or_else(|e| panic!("Failed to write {path}: {e}"));
}

fn main() {
    let args = Args::parse();

    fs::create_dir_all(&args.out_dir)
        .unwrap_or_else(|e| panic!("Failed to create out_dir {:?}: {e}", args.out_dir));

    if args.files.is_empty() {
        fs::write(Path::new(&args.out_dir).join(".empty"), "")
            .unwrap_or_else(|e| panic!("Failed to write .empty sentinel: {e}"));
    }

    for (dest_name, src_path) in &args.files {
        let dest = Path::new(&args.out_dir).join(dest_name);
        if let Some(parent) = dest.parent() {
            fs::create_dir_all(parent)
                .unwrap_or_else(|e| panic!("Failed to create parent dir {:?}: {e}", parent));
        }
        fs::copy(src_path, &dest)
            .unwrap_or_else(|e| panic!("Failed to copy {:?} -> {:?}: {e}", src_path, dest));
    }

    write_lines(&args.flags_out, &args.rustc_flags);
    write_lines(&args.env_out, &args.rustc_envs);
    write_lines(&args.dep_env_out, &args.dep_envs);
    write_lines(&args.link_flags_out, &args.link_flags);

    let search_paths: Vec<String> = args
        .link_search_paths
        .iter()
        .map(|p| format!("-Lnative=${{pwd}}/{p}"))
        .collect();
    write_lines(&args.link_search_paths_out, &search_paths);
}
