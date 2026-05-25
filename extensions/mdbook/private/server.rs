//! A process wrapper for `mdbook serve`.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::{env, fs};

use runfiles::rlocation;

#[cfg(target_family = "unix")]
const PATH_SEP: &str = ":";

#[cfg(target_family = "windows")]
const PATH_SEP: &str = ";";

struct Args {
    pub mdbook: PathBuf,

    pub config: PathBuf,

    pub hostname: String,

    pub port: String,

    pub plugins: Vec<PathBuf>,

    pub srcs: Vec<(PathBuf, PathBuf)>,

    pub mdbook_args: Vec<String>,
}

impl Args {
    pub fn parse() -> Self {
        let runfiles = runfiles::Runfiles::create().unwrap();

        let args_env = env::var("RULES_MDBOOK_SERVE_ARGS_FILE").unwrap();
        let args_file = rlocation!(runfiles, args_env).unwrap();
        let raw_args = action_args::try_parse_args(&args_file).unwrap();

        let mut mdbook: Option<PathBuf> = None;
        let mut config: Option<PathBuf> = None;
        let mut hostname: Option<String> = None;
        let mut port: Option<String> = None;
        let mut plugins: Vec<PathBuf> = Vec::new();
        let mut srcs: Vec<(PathBuf, PathBuf)> = Vec::new();

        for arg in raw_args {
            if arg.starts_with("--mdbook=") {
                let val = arg.split_once("=").unwrap().1;
                mdbook = Some(rlocation!(runfiles, val).unwrap());
            } else if arg.starts_with("--plugin=") {
                let val = arg.split_once("=").unwrap().1.to_string();
                plugins.push(rlocation!(runfiles, val).unwrap());
            } else if arg.starts_with("--config=") {
                let val = arg.split_once("=").unwrap().1.to_string();
                config = Some(rlocation!(runfiles, val).unwrap());
            } else if arg.starts_with("--hostname=") {
                hostname = Some(arg.split_once("=").unwrap().1.to_string());
            } else if arg.starts_with("--port=") {
                port = Some(arg.split_once("=").unwrap().1.to_string());
            } else if arg.starts_with("--src=") {
                let val = arg.split_once("=").unwrap().1;
                let (rloc, dest) = val.split_once("=").unwrap();
                srcs.push((rlocation!(runfiles, rloc).unwrap(), PathBuf::from(dest)));
            }
        }

        Self {
            mdbook: mdbook.unwrap(),
            config: config.unwrap(),
            hostname: hostname.unwrap(),
            port: port.unwrap(),
            plugins,
            srcs,
            mdbook_args: env::args().skip(1).collect(),
        }
    }
}

const RULES_MDBOOK_TMP_NAME: &str = "rules_mdbook_server";

fn make_temp_dir() -> PathBuf {
    if let Ok(var) = env::var("TMP") {
        return PathBuf::from(var).join(RULES_MDBOOK_TMP_NAME);
    }

    if let Ok(var) = env::var("TEMP") {
        return PathBuf::from(var).join(RULES_MDBOOK_TMP_NAME);
    }

    if let Ok(var) = env::var("TMPDIR") {
        return PathBuf::from(var).join(RULES_MDBOOK_TMP_NAME);
    }

    if let Ok(var) = env::var("TEMPDIR") {
        return PathBuf::from(var).join(RULES_MDBOOK_TMP_NAME);
    }

    let tmp = PathBuf::from("/tmp");
    if tmp.exists() {
        return tmp.join(RULES_MDBOOK_TMP_NAME);
    }

    if let Ok(var) = env::var("USERPROFILE") {
        let tmp = PathBuf::from(var)
            .join("AppData")
            .join("Local")
            .join("Temp");
        if tmp.exists() {
            return tmp.join(RULES_MDBOOK_TMP_NAME);
        }
    }

    panic!("Could not determine how to create temp dir.")
}

#[cfg(target_family = "unix")]
fn symlink<P: AsRef<Path>, Q: AsRef<Path>>(src: P, dst: Q) {
    std::os::unix::fs::symlink(src.as_ref(), dst.as_ref()).unwrap_or_else(|e| {
        panic!(
            "Failed to create symlink: {} -> {}: {}",
            src.as_ref().display(),
            dst.as_ref().display(),
            e
        )
    });
}

#[cfg(target_family = "windows")]
fn symlink<P: AsRef<Path>, Q: AsRef<Path>>(src: P, dst: Q) {
    fs::copy(src.as_ref(), dst.as_ref()).unwrap_or_else(|e| {
        panic!(
            "Failed to copy file: {} -> {}: {}",
            src.as_ref().display(),
            dst.as_ref().display(),
            e
        )
    });
}

fn stage_files_internal(workdir: &Path, config: &Path, srcs: &BTreeMap<PathBuf, PathBuf>) {
    symlink(config, workdir.join("book.toml"));
    for (src, dest) in srcs {
        let abs_dest = workdir.join(dest);
        if let Some(parent) = abs_dest.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        symlink(src, abs_dest);
    }
}

fn main() {
    let args = Args::parse();

    let mut command = Command::new(&args.mdbook);

    let temp_dir = make_temp_dir();
    let _ = fs::remove_dir_all(&temp_dir);
    fs::create_dir_all(&temp_dir).unwrap();

    // If we have source mappings, we need to stage the files in a flat directory
    // so that mdbook can resolve them relative to book.toml.
    if !args.srcs.is_empty() {
        let workdir = temp_dir.join("stage");
        fs::create_dir_all(&workdir).unwrap();
        stage_files_internal(&workdir, &args.config, &args.srcs.iter().cloned().collect());
        command.arg("serve").arg(&workdir);
    } else {
        // No flattening required, run in-place against the runfiles
        command.arg("serve").arg(args.config.parent().unwrap());
    };

    // Inject plugin paths into PATH
    let pwd = env::current_dir().expect("Unable to determine current working directory");
    if !args.plugins.is_empty() {
        let path = env::var("PATH").unwrap_or_default();

        let plugin_path = args
            .plugins
            .iter()
            .map(|p| {
                if p.is_absolute() {
                    p.parent().unwrap().to_string_lossy().to_string()
                } else {
                    let abs = pwd.join(p);
                    abs.parent().unwrap().to_string_lossy().to_string()
                }
            })
            .collect::<Vec<_>>()
            .join(PATH_SEP);

        command.env("PATH", format!("{}{}{}", plugin_path, PATH_SEP, path));
    }

    command.args(&args.mdbook_args);

    // Add default hostname value if commandline was not specified.
    if !args.mdbook_args.iter().any(|arg| {
        ["-n", "--hostname"].contains(&arg.as_str())
            || arg.starts_with("-n=")
            || arg.starts_with("--hostname=")
    }) {
        command.args(["--hostname", &args.hostname]);
    }

    // Add default port value if commandline was not specified.
    if !args.mdbook_args.iter().any(|arg| {
        ["-p", "--port"].contains(&arg.as_str())
            || arg.starts_with("-p=")
            || arg.starts_with("--port=")
    }) {
        command.args(["--port", &args.port]);
    }

    // Check if `-d` or `--dest-dir` was passed. If not, make a temp dir for the output
    if !args.mdbook_args.iter().any(|a| {
        ["-d", "--dest-dir"].contains(&a.as_str())
            || a.starts_with("-d=")
            || a.starts_with("--dest-dir=")
    }) {
        let output_dir = temp_dir.join("output");
        command.arg("--dest-dir").arg(&output_dir);
    };

    // Run mdbook
    let status = command
        .status()
        .unwrap_or_else(|e| panic!("Failed to spawn mdbook command\n{:?}\n{:#?}", e, command));

    // Cleanup
    fs::remove_dir_all(&temp_dir).unwrap();

    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_stage_files() {
        let base = env::temp_dir().join(format!("mdbook_test_{}", std::process::id()));
        let src_dir = base.join("src_dir");
        let workdir = base.join("workdir");
        fs::create_dir_all(&src_dir).unwrap();
        fs::create_dir_all(&workdir).unwrap();

        let config = src_dir.join("book.toml");
        fs::write(&config, "title = 'test'").unwrap();

        let file1 = src_dir.join("file1.md");
        fs::write(&file1, "content1").unwrap();

        let sub_dir = src_dir.join("sub");
        fs::create_dir_all(&sub_dir).unwrap();
        let file2 = sub_dir.join("file2.md");
        fs::write(&file2, "content2").unwrap();

        let mut srcs = BTreeMap::new();
        srcs.insert(file1.clone(), PathBuf::from("file1.md"));
        srcs.insert(file2.clone(), PathBuf::from("sub/file2.md"));

        stage_files_internal(&workdir, &config, &srcs);

        assert!(workdir.join("book.toml").exists());
        assert!(workdir.join("file1.md").exists());
        assert!(workdir.join("sub/file2.md").exists());

        #[cfg(target_family = "unix")]
        {
            assert!(fs::symlink_metadata(workdir.join("file1.md"))
                .unwrap()
                .file_type()
                .is_symlink());
        }

        fs::remove_dir_all(&base).unwrap();
    }
}
