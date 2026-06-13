//! A process wrapper for `mdbook serve`.
//!
//! `mdbook serve` cannot be pointed directly at the runfiles tree: `book.toml`
//! and source files appear as symlinks back to the workspace (for hand-written
//! sources) and to `bazel-out/` (for generated sources). When mdbook resolves
//! relative paths it follows the `book.toml` symlink to the workspace, fails to
//! find generated chapters there, and helpfully writes empty stubs back into
//! the workspace. Instead, stage every input into an isolated workdir of real
//! files and serve from that.
//!
//! When run under `ibazel` with the `ibazel_notify_changes` tag, the server
//! listens on stdin for `IBAZEL_BUILD_COMPLETED SUCCESS` messages and
//! re-stages the inputs each time, which `mdbook serve`'s internal file
//! watcher picks up and reloads any connected browsers.

use std::collections::BTreeMap;
use std::io::{self, BufRead};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::{env, fs, thread};

use runfiles::{rlocation, Runfiles};

#[cfg(target_family = "unix")]
const PATH_SEP: &str = ":";

#[cfg(target_family = "windows")]
const PATH_SEP: &str = ";";

const RULES_MDBOOK_TMP_NAME: &str = "rules_mdbook_server";

struct Args {
    pub mdbook: PathBuf,

    /// Path of `book.toml` relative to the staging workdir.
    pub config_dest: PathBuf,

    pub hostname: String,

    pub port: String,

    pub plugins: Vec<PathBuf>,

    /// Map of `dest_relative_to_workdir -> absolute_runfiles_path` for every
    /// input that must be staged for `mdbook serve` to see a consistent tree.
    pub srcs: BTreeMap<PathBuf, PathBuf>,

    pub mdbook_args: Vec<String>,
}

impl Args {
    pub fn parse(runfiles: &Runfiles) -> Self {
        let args_env = env::var("RULES_MDBOOK_SERVE_ARGS_FILE").unwrap();
        let args_file = rlocation!(runfiles, args_env).unwrap();
        let raw_args = action_args::try_parse_args(&args_file).unwrap();

        let mut mdbook: Option<PathBuf> = None;
        let mut config_dest: Option<PathBuf> = None;
        let mut hostname: Option<String> = None;
        let mut port: Option<String> = None;
        let mut plugins: Vec<PathBuf> = Vec::new();
        let mut srcs: BTreeMap<PathBuf, PathBuf> = BTreeMap::new();

        for arg in raw_args {
            if let Some(val) = arg.strip_prefix("--mdbook=") {
                mdbook = Some(rlocation!(runfiles, val).unwrap());
            } else if let Some(val) = arg.strip_prefix("--plugin=") {
                plugins.push(rlocation!(runfiles, val).unwrap());
            } else if let Some(val) = arg.strip_prefix("--config=") {
                config_dest = Some(PathBuf::from(val));
            } else if let Some(val) = arg.strip_prefix("--hostname=") {
                hostname = Some(val.to_string());
            } else if let Some(val) = arg.strip_prefix("--port=") {
                port = Some(val.to_string());
            } else if let Some(val) = arg.strip_prefix("--src=") {
                let (rloc, dest) = val.split_once('=').unwrap_or_else(|| {
                    panic!("Malformed --src arg (expected `rlocation=dest`): {}", val)
                });
                let resolved = rlocation!(runfiles, rloc)
                    .unwrap_or_else(|| panic!("Failed to resolve src runfile: {}", rloc));
                srcs.insert(PathBuf::from(dest), resolved);
            }
        }

        Self {
            mdbook: mdbook.unwrap(),
            config_dest: config_dest.unwrap(),
            hostname: hostname.unwrap(),
            port: port.unwrap(),
            plugins,
            srcs,
            mdbook_args: env::args().skip(1).collect(),
        }
    }
}

fn tmp_root() -> PathBuf {
    for var in ["TMP", "TEMP", "TMPDIR", "TEMPDIR"] {
        if let Ok(val) = env::var(var) {
            return PathBuf::from(val);
        }
    }

    let tmp = PathBuf::from("/tmp");
    if tmp.exists() {
        return tmp;
    }

    if let Ok(val) = env::var("USERPROFILE") {
        let tmp = PathBuf::from(val)
            .join("AppData")
            .join("Local")
            .join("Temp");
        if tmp.exists() {
            return tmp;
        }
    }

    panic!("Could not determine how to create temp dir.")
}

/// Create a fresh, process-unique scratch directory under the system temp root.
fn make_scratch_dir(suffix: &str) -> PathBuf {
    let pid = std::process::id();
    let path = tmp_root()
        .join(RULES_MDBOOK_TMP_NAME)
        .join(format!("{}-{}", pid, suffix));
    if path.exists() {
        fs::remove_dir_all(&path).expect("failed to clear stale scratch dir");
    }
    fs::create_dir_all(&path).expect("failed to create scratch dir");
    path
}

/// Copy every staged input into `workdir`, replacing any existing copy.
/// Removing-then-copying ensures the destination gets a fresh inode and mtime,
/// which is what mdbook's notify-based watcher reacts to on re-stage.
fn stage_inputs(workdir: &Path, srcs: &BTreeMap<PathBuf, PathBuf>) -> io::Result<()> {
    for (dest, src) in srcs {
        let abs_dest = workdir.join(dest);
        if !abs_dest.starts_with(workdir) {
            panic!(
                "Refusing to stage outside workdir: {} -> {}",
                src.display(),
                abs_dest.display()
            );
        }
        if let Some(parent) = abs_dest.parent() {
            fs::create_dir_all(parent)?;
        }
        // Best-effort remove so the write produces a new inode for inotify.
        let _ = fs::remove_file(&abs_dest);
        fs::copy(src, &abs_dest).map_err(|e| {
            io::Error::new(
                e.kind(),
                format!(
                    "copy `{}` -> `{}`: {}",
                    src.display(),
                    abs_dest.display(),
                    e
                ),
            )
        })?;
    }
    Ok(())
}

/// If `IBAZEL_NOTIFY_CHANGES=y` is set, ibazel will write
/// `IBAZEL_BUILD_STARTED\n` / `IBAZEL_BUILD_COMPLETED <SUCCESS|FAILURE>\n` to
/// our stdin. Re-stage inputs on each successful completion so `mdbook serve`'s
/// file watcher reloads connected browsers.
fn spawn_ibazel_watcher(workdir: PathBuf, srcs: Arc<BTreeMap<PathBuf, PathBuf>>) {
    if env::var("IBAZEL_NOTIFY_CHANGES").ok().as_deref() != Some("y") {
        return;
    }

    thread::spawn(move || {
        let stdin = io::stdin();
        let mut reader = stdin.lock();
        let mut line = String::new();
        let reloads = AtomicU64::new(0);
        loop {
            line.clear();
            match reader.read_line(&mut line) {
                Ok(0) => break,
                Ok(_) => {
                    let trimmed = line.trim();
                    if trimmed.starts_with("IBAZEL_BUILD_COMPLETED") && trimmed.ends_with("SUCCESS")
                    {
                        match stage_inputs(&workdir, &srcs) {
                            Ok(()) => {
                                let n = reloads.fetch_add(1, Ordering::Relaxed) + 1;
                                eprintln!(
                                    "[mdbook_server] re-staged sources (#{}) after ibazel build",
                                    n
                                );
                            }
                            Err(e) => eprintln!("[mdbook_server] re-stage failed: {}", e),
                        }
                    }
                }
                Err(_) => break,
            }
        }
    });
}

fn main() {
    let runfiles = Runfiles::create().unwrap();
    let args = Args::parse(&runfiles);

    let workdir = make_scratch_dir("workdir");
    let dest_dir = make_scratch_dir("dest");

    stage_inputs(&workdir, &args.srcs).expect("Initial stage of mdbook inputs failed");

    let staged_config = workdir.join(&args.config_dest);
    let book_dir = staged_config
        .parent()
        .expect("staged book.toml has no parent")
        .to_path_buf();

    let srcs = Arc::new(args.srcs);
    spawn_ibazel_watcher(workdir.clone(), Arc::clone(&srcs));

    let mut command = Command::new(&args.mdbook);

    // Inject plugin paths into PATH.
    let pwd = env::current_dir().expect("Unable to determine current working directory");
    if !args.plugins.is_empty() {
        let path = env::var("PATH").unwrap_or_default();

        let plugin_path = args
            .plugins
            .iter()
            .map(|p| {
                let abs = if p.is_absolute() {
                    p.clone()
                } else {
                    pwd.join(p)
                };
                abs.parent().unwrap().to_string_lossy().to_string()
            })
            .collect::<Vec<_>>()
            .join(PATH_SEP);

        command.env("PATH", format!("{}{}{}", plugin_path, PATH_SEP, path));
    }

    command.arg("serve").arg(&book_dir).args(&args.mdbook_args);

    if !args.mdbook_args.iter().any(|arg| {
        ["-n", "--hostname"].contains(&arg.as_str())
            || arg.starts_with("-n=")
            || arg.starts_with("--hostname=")
    }) {
        command.args(["--hostname", &args.hostname]);
    }

    if !args.mdbook_args.iter().any(|arg| {
        ["-p", "--port"].contains(&arg.as_str())
            || arg.starts_with("-p=")
            || arg.starts_with("--port=")
    }) {
        command.args(["--port", &args.port]);
    }

    // We always own the output dir; users overriding `--dest-dir` is rare and
    // mostly meaningful in build-mode only.
    let user_dest_dir = args.mdbook_args.iter().any(|a| {
        ["-d", "--dest-dir"].contains(&a.as_str())
            || a.starts_with("-d=")
            || a.starts_with("--dest-dir=")
    });
    if !user_dest_dir {
        command.arg("--dest-dir").arg(&dest_dir);
    }

    let status = command
        .status()
        .unwrap_or_else(|e| panic!("Failed to spawn mdbook command\n{:?}\n{:#?}", e, command));

    let _ = fs::remove_dir_all(&workdir);
    if !user_dest_dir {
        let _ = fs::remove_dir_all(&dest_dir);
    }

    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }
}
