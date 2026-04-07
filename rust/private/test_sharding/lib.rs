use runfiles::Runfiles;
use std::env;
use std::ffi::OsString;
use std::fs::{self, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{self, Command, ExitStatus, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

pub const TEST_BINARY_EXEC_PATH_ENV: &str = "RULES_RUST_TEST_BINARY_EXEC_PATH";
pub const TEST_BINARY_RLOCATIONPATH_ENV: &str = "RULES_RUST_TEST_BINARY_RLOCATIONPATH";
pub const TEST_BINARY_RUNFILES_PATH_ENV: &str = "RULES_RUST_TEST_BINARY_RUNFILES_PATH";
pub const TEST_BINARY_SOURCE_REPOSITORY_ENV: &str = "RULES_RUST_TEST_BINARY_SOURCE_REPOSITORY";
pub const TESTBRIDGE_TEST_ONLY_ENV: &str = "TESTBRIDGE_TEST_ONLY";
const EMPTY_SHARD_FILTER_PREFIX: &str = "__rules_rust_shard_empty__";
const LLVM_PROFILE_FILE_ENV: &str = "LLVM_PROFILE_FILE";
const RUNFILES_DIR_ENV: &str = "RUNFILES_DIR";
const RUNFILES_MANIFEST_FILE_ENV: &str = "RUNFILES_MANIFEST_FILE";
const TEST_SRCDIR_ENV: &str = "TEST_SRCDIR";
const TEST_BINARY_ENV: &str = "TEST_BINARY";
const TEST_SHARDING_LAUNCHER_DIR: &str = "_test_sharding_launcher";
const TIMEOUT_EXIT_CODE: i32 = 143;
const XML_OUTPUT_FILE_ENV: &str = "XML_OUTPUT_FILE";

#[cfg(unix)]
type SignalHandler = usize;
#[cfg(unix)]
const SIGTERM_SIGNAL: i32 = 15;
#[cfg(unix)]
const SIGNAL_ERROR: SignalHandler = usize::MAX;
#[cfg(unix)]
static TIMEOUT_SIGNAL_RECEIVED: AtomicBool = AtomicBool::new(false);

#[cfg(unix)]
extern "C" fn record_timeout_signal(_signal: i32) {
    TIMEOUT_SIGNAL_RECEIVED.store(true, Ordering::SeqCst);
}

#[cfg(unix)]
unsafe extern "C" {
    fn signal(signal: i32, handler: SignalHandler) -> SignalHandler;
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ShardConfig {
    pub index: usize,
    pub total: usize,
}

#[derive(Debug, Eq, PartialEq)]
pub struct ParsedArgs {
    pub passthrough: bool,
    pub has_explicit_filters: bool,
    pub listing_args: Vec<OsString>,
    pub execution_args: Vec<OsString>,
}

#[cfg(unix)]
struct TimeoutSignalGuard {
    previous_handler: SignalHandler,
}

#[cfg(unix)]
impl TimeoutSignalGuard {
    fn install() -> Result<Self, String> {
        TIMEOUT_SIGNAL_RECEIVED.store(false, Ordering::SeqCst);
        let previous_handler = unsafe {
            signal(
                SIGTERM_SIGNAL,
                record_timeout_signal as *const () as SignalHandler,
            )
        };
        if previous_handler == SIGNAL_ERROR {
            return Err(
                "failed to install SIGTERM handler for wrapped rust test timeout handling"
                    .to_owned(),
            );
        }

        Ok(TimeoutSignalGuard { previous_handler })
    }

    fn timed_out(&self) -> bool {
        TIMEOUT_SIGNAL_RECEIVED.load(Ordering::SeqCst)
    }
}

#[cfg(unix)]
impl Drop for TimeoutSignalGuard {
    fn drop(&mut self) {
        let _ = unsafe { signal(SIGTERM_SIGNAL, self.previous_handler) };
        TIMEOUT_SIGNAL_RECEIVED.store(false, Ordering::SeqCst);
    }
}

#[cfg(not(unix))]
struct TimeoutSignalGuard;

#[cfg(not(unix))]
impl TimeoutSignalGuard {
    fn timed_out(&self) -> bool {
        false
    }
}

struct TestExecution {
    reported_exit_code: i32,
}

pub fn shard_config_from_env() -> Result<Option<ShardConfig>, String> {
    let total = match env::var("TEST_TOTAL_SHARDS") {
        Ok(value) => parse_usize_env("TEST_TOTAL_SHARDS", &value)?,
        Err(env::VarError::NotPresent) => return Ok(None),
        Err(env::VarError::NotUnicode(_)) => {
            return Err("TEST_TOTAL_SHARDS was not valid UTF-8".to_owned())
        }
    };

    let index = match env::var("TEST_SHARD_INDEX") {
        Ok(value) => parse_usize_env("TEST_SHARD_INDEX", &value)?,
        Err(env::VarError::NotPresent) => {
            return Err("TEST_TOTAL_SHARDS was set but TEST_SHARD_INDEX was missing".to_owned())
        }
        Err(env::VarError::NotUnicode(_)) => {
            return Err("TEST_SHARD_INDEX was not valid UTF-8".to_owned())
        }
    };

    if total == 0 {
        return Err("TEST_TOTAL_SHARDS must be greater than zero".to_owned());
    }
    if index >= total {
        return Err(format!(
            "TEST_SHARD_INDEX ({index}) must be less than TEST_TOTAL_SHARDS ({total})"
        ));
    }

    Ok(Some(ShardConfig { index, total }))
}

pub fn touch_shard_status_file() -> io::Result<()> {
    let path = match env::var_os("TEST_SHARD_STATUS_FILE") {
        Some(path) if !path.is_empty() => PathBuf::from(path),
        _ => return Ok(()),
    };

    OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(path)
        .map(|_| ())
}

pub fn resolve_test_binary() -> Result<PathBuf, String> {
    let mut errors = Vec::new();

    match resolve_test_binary_from_runfiles() {
        Ok(path) => return Ok(path),
        Err(err) => errors.push(err),
    }

    match invoked_launcher_path().and_then(|path| resolve_test_binary_from_launcher_path(&path)) {
        Ok(path) => return Ok(path),
        Err(err) => errors.push(err),
    }

    Err(errors.join("; "))
}

pub fn parse_args<I>(args: I) -> ParsedArgs
where
    I: IntoIterator<Item = OsString>,
{
    let mut passthrough = false;
    let mut has_explicit_filters = false;
    let mut listing_args = Vec::new();
    let mut execution_args = Vec::new();

    let mut args = args.into_iter();
    while let Some(arg) = args.next() {
        let arg_text = arg.to_string_lossy();

        if is_passthrough_flag(&arg_text) {
            passthrough = true;
        }

        if let Some((flag, _value)) = split_flag_value(&arg_text) {
            if is_listing_flag(flag) {
                listing_args.push(arg.clone());
            }
            execution_args.push(arg);
            continue;
        }

        if let Some(flag) = takes_value(&arg_text) {
            if is_listing_flag(&arg_text) {
                listing_args.push(arg.clone());
            }
            execution_args.push(arg);

            if let Some(value) = args.next() {
                if is_listing_flag(flag) {
                    listing_args.push(value.clone());
                }
                execution_args.push(value);
            }
            continue;
        }

        if arg_text.starts_with('-') {
            if is_listing_flag(&arg_text) {
                listing_args.push(arg.clone());
            }
            execution_args.push(arg);
            continue;
        }

        listing_args.push(arg);
        has_explicit_filters = true;
    }

    ParsedArgs {
        passthrough,
        has_explicit_filters,
        listing_args,
        execution_args,
    }
}

pub fn inferred_test_filters(has_explicit_filters: bool) -> Result<Vec<OsString>, String> {
    if has_explicit_filters {
        return Ok(Vec::new());
    }

    match env::var(TESTBRIDGE_TEST_ONLY_ENV) {
        Ok(value) => Ok(vec![OsString::from(value)]),
        Err(env::VarError::NotPresent) => Ok(Vec::new()),
        Err(env::VarError::NotUnicode(_)) => {
            Err(format!("{TESTBRIDGE_TEST_ONLY_ENV} was not valid UTF-8"))
        }
    }
}

pub fn filter_tests_by_name(
    test_names: &[String],
    filters: &[OsString],
    exact: bool,
) -> Vec<String> {
    if filters.is_empty() {
        return test_names.to_vec();
    }

    test_names
        .iter()
        .filter(|name| {
            filters.iter().any(|filter| {
                let filter = filter.to_string_lossy();
                if exact {
                    name.as_str() == filter.as_ref()
                } else {
                    name.contains(filter.as_ref())
                }
            })
        })
        .cloned()
        .collect()
}

pub fn list_tests(test_binary: &Path, listing_args: &[OsString]) -> Result<Vec<String>, String> {
    let mut command = Command::new(test_binary);
    configure_listing_command(&mut command);
    command
        .args(listing_args)
        .arg("--list")
        .arg("--format")
        .arg("terse");

    let output = command.output().map_err(|err| {
        format!(
            "failed to list rust tests from {}: {err}",
            test_binary.display()
        )
    })?;

    if !output.status.success() {
        io::stdout()
            .write_all(&output.stdout)
            .map_err(|err| format!("failed to write test listing stdout: {err}"))?;
        io::stderr()
            .write_all(&output.stderr)
            .map_err(|err| format!("failed to write test listing stderr: {err}"))?;
        exit_with_status(output.status);
    }

    parse_test_listing(&output.stdout)
}

pub fn select_shard_tests(test_names: &[String], shard: ShardConfig) -> Vec<String> {
    test_names
        .iter()
        .enumerate()
        .filter(|(index, _name)| index % shard.total == shard.index)
        .map(|(_index, name)| name.clone())
        .collect()
}

pub fn empty_shard_filter(shard: ShardConfig) -> OsString {
    OsString::from(format!(
        "{EMPTY_SHARD_FILTER_PREFIX}_{}_{}",
        shard.index, shard.total
    ))
}

pub fn empty_test_filter() -> OsString {
    OsString::from(format!("{EMPTY_SHARD_FILTER_PREFIX}_unmatched"))
}

pub fn exec_test_binary(test_binary: &Path, args: &[OsString]) -> Result<(), String> {
    // Prefer the stable public test path Bazel exposes to users. When that
    // wrapper-specific override is unavailable, fall back to the resolved test
    // binary path so direct launcher execution still sees a sensible argv[0].
    let public_test_binary =
        public_test_binary_runfiles_path().unwrap_or_else(|_| test_binary.display().to_string());
    let mut command = Command::new(test_binary);
    command.args(args);
    // Keep the child test process aligned with the public TEST_BINARY value so
    // self-reexec and sibling-resource lookup keep seeing the target-derived
    // executable identity instead of a hidden launcher path.
    command.env(TEST_BINARY_ENV, &public_test_binary);
    configure_direct_exec_runfiles_env(&mut command)?;
    let xml_log_capture = maybe_prepare_xml_log_capture()?;
    let started = Instant::now();
    let execution = run_test_binary(&mut command, xml_log_capture.as_deref())?;

    maybe_write_xml_output(
        &public_test_binary,
        xml_log_capture.as_deref(),
        started.elapsed(),
        execution.reported_exit_code,
    )?;
    cleanup_xml_log_capture(xml_log_capture.as_deref());
    process::exit(execution.reported_exit_code);
}

pub fn has_exact_flag(args: &[OsString]) -> bool {
    args.iter().any(|arg| arg == "--exact")
}

fn parse_usize_env(name: &str, value: &str) -> Result<usize, String> {
    value
        .parse()
        .map_err(|_| format!("{name} was not a valid unsigned integer: {value}"))
}

fn parse_test_listing(stdout: &[u8]) -> Result<Vec<String>, String> {
    let stdout = String::from_utf8(stdout.to_vec())
        .map_err(|err| format!("rust test listing was not valid UTF-8: {err}"))?;
    let mut test_names = Vec::new();

    for line in stdout.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        let (name, kind) = line
            .rsplit_once(": ")
            .ok_or_else(|| format!("unexpected rust test listing line: {line}"))?;
        if kind == "test" || kind == "benchmark" {
            test_names.push(name.to_owned());
        }
    }

    Ok(test_names)
}

fn is_passthrough_flag(arg: &str) -> bool {
    matches!(arg, "--list" | "-h" | "--help")
}

fn is_listing_flag(arg: &str) -> bool {
    matches!(
        arg,
        "--bench"
            | "--exact"
            | "--exclude-should-panic"
            | "--ignored"
            | "--include-ignored"
            | "--skip"
            | "--test"
            | "-Z"
    )
}

fn split_flag_value(arg: &str) -> Option<(&str, &str)> {
    if let Some((flag, value)) = arg.split_once('=') {
        if takes_value(flag).is_some() {
            return Some((flag, value));
        }
    }

    if let Some(value) = arg.strip_prefix("-Z") {
        if !value.is_empty() {
            return Some(("-Z", value));
        }
    }

    None
}

fn resolve_test_binary_from_runfiles() -> Result<PathBuf, String> {
    let runfiles =
        Runfiles::create().map_err(|err| format!("failed to initialize runfiles: {err}"))?;
    let rlocationpath = env::var(TEST_BINARY_RLOCATIONPATH_ENV)
        .map_err(|_| format!("{TEST_BINARY_RLOCATIONPATH_ENV} was not set"))?;
    let source_repository = env::var(TEST_BINARY_SOURCE_REPOSITORY_ENV)
        .map_err(|_| format!("{TEST_BINARY_SOURCE_REPOSITORY_ENV} was not set"))?;
    let path = runfiles
        .rlocation_from(&rlocationpath, &source_repository)
        .ok_or_else(|| format!("failed to resolve runfile: {rlocationpath}"))?;

    ensure_test_binary_exists(path)
}

fn invoked_launcher_path() -> Result<PathBuf, String> {
    let arg0 = env::args_os()
        .next()
        .ok_or_else(|| "argv[0] was missing for wrapped rust test launcher".to_owned())?;
    absolute_invocation_path(PathBuf::from(arg0))
}

fn absolute_invocation_path(path: PathBuf) -> Result<PathBuf, String> {
    if path.as_os_str().is_empty() {
        return Err("wrapped rust test launcher argv[0] was empty".to_owned());
    }
    if path.is_absolute() {
        return Ok(path);
    }
    if path
        .parent()
        .map(|parent| !parent.as_os_str().is_empty())
        .unwrap_or(false)
    {
        return env::current_dir()
            .map(|cwd| cwd.join(path))
            .map_err(|err| format!("failed to get current directory for argv[0]: {err}"));
    }

    let path_env =
        env::var_os("PATH").ok_or_else(|| "PATH was not set for wrapped rust test launcher".to_owned())?;
    for entry in env::split_paths(&path_env) {
        let candidate = if entry.is_absolute() {
            entry.join(&path)
        } else {
            env::current_dir()
                .map(|cwd| cwd.join(&entry).join(&path))
                .map_err(|err| format!("failed to resolve PATH entry for argv[0]: {err}"))?
        };
        if candidate.exists() {
            return Ok(candidate);
        }
    }

    Err(format!(
        "could not resolve wrapped rust test launcher path from argv[0]: {}",
        path.display()
    ))
}

fn resolve_test_binary_from_launcher_path(launcher_path: &Path) -> Result<PathBuf, String> {
    ensure_test_binary_exists(launcher_public_test_binary_path(launcher_path)?)
}

fn launcher_public_test_binary_path(launcher_path: &Path) -> Result<PathBuf, String> {
    let launcher_dir = launcher_path.parent().ok_or_else(|| {
        format!(
            "wrapped rust test launcher had no parent directory: {}",
            launcher_path.display()
        )
    })?;
    let launcher_dir_name = launcher_dir.file_name().ok_or_else(|| {
        format!(
            "wrapped rust test launcher parent had no file name: {}",
            launcher_dir.display()
        )
    })?;
    if launcher_dir_name != std::ffi::OsStr::new(TEST_SHARDING_LAUNCHER_DIR) {
        return Err(format!(
            "wrapped rust test launcher was not under {}: {}",
            TEST_SHARDING_LAUNCHER_DIR,
            launcher_path.display()
        ));
    }

    let public_dir = launcher_dir.parent().ok_or_else(|| {
        format!(
            "wrapped rust test launcher directory had no parent: {}",
            launcher_dir.display()
        )
    })?;
    let launcher_name = launcher_path.file_name().ok_or_else(|| {
        format!(
            "wrapped rust test launcher had no file name: {}",
            launcher_path.display()
        )
    })?;

    Ok(public_dir.join(launcher_name))
}

fn public_test_binary_runfiles_path() -> Result<String, String> {
    env::var(TEST_BINARY_RUNFILES_PATH_ENV)
        .or_else(|_| env::var(TEST_BINARY_ENV).map(|path| normalize_public_test_binary_path(&path)))
        .map_err(|_| format!("{TEST_BINARY_RUNFILES_PATH_ENV} was not set"))
}

fn normalize_public_test_binary_path(path: &str) -> String {
    // Bazel seeds TEST_BINARY from files_to_run.executable, which is the
    // hidden launcher for wrapped rust_test targets. Normalize that private
    // path back to the user-facing test binary so synthesized XML keeps the
    // same suite/testcase names as the pre-launcher implementation.
    for separator in ['/', '\\'] {
        let launcher_segment = format!("{separator}{TEST_SHARDING_LAUNCHER_DIR}{separator}");
        if let Some((prefix, suffix)) = path.split_once(&launcher_segment) {
            return format!("{prefix}{separator}{suffix}");
        }

        let launcher_prefix = format!("{TEST_SHARDING_LAUNCHER_DIR}{separator}");
        if let Some(stripped) = path.strip_prefix(&launcher_prefix) {
            return stripped.to_owned();
        }
    }

    path.to_owned()
}

fn configure_direct_exec_runfiles_env(command: &mut Command) -> Result<(), String> {
    if env::var_os(RUNFILES_DIR_ENV).is_some() || env::var_os(RUNFILES_MANIFEST_FILE_ENV).is_some()
    {
        return Ok(());
    }

    let launcher_path = match invoked_launcher_path() {
        Ok(path) => path,
        Err(_) => return Ok(()),
    };

    let launcher_runfiles_dir = launcher_neighbor_path(&launcher_path, ".runfiles")?;
    if launcher_runfiles_dir.is_dir() {
        command.env(RUNFILES_DIR_ENV, &launcher_runfiles_dir);
        command.env(TEST_SRCDIR_ENV, &launcher_runfiles_dir);
    }

    let launcher_runfiles_manifest = launcher_neighbor_path(&launcher_path, ".runfiles_manifest")?;
    if launcher_runfiles_manifest.exists() {
        command.env(RUNFILES_MANIFEST_FILE_ENV, &launcher_runfiles_manifest);
    }

    Ok(())
}

fn install_timeout_signal_guard() -> Result<Option<TimeoutSignalGuard>, String> {
    if !writes_xml_output() {
        return Ok(None);
    }

    #[cfg(unix)]
    {
        return TimeoutSignalGuard::install().map(Some);
    }

    #[cfg(not(unix))]
    {
        Ok(None)
    }
}

fn writes_xml_output() -> bool {
    matches!(env::var_os(XML_OUTPUT_FILE_ENV), Some(path) if !path.is_empty())
}

fn maybe_prepare_xml_log_capture() -> Result<Option<PathBuf>, String> {
    if !writes_xml_output() {
        return Ok(None);
    }

    // Only create the capture file when we may need to synthesize XML. This
    // keeps direct bazel-bin execution identical to the raw test binary while
    // still giving the launcher a stable on-disk copy of stdout/stderr for
    // timeout and crash fallback paths.
    let capture_dir = match env::var_os("TEST_TMPDIR") {
        Some(path) if !path.is_empty() => PathBuf::from(path),
        _ => env::temp_dir(),
    };
    fs::create_dir_all(&capture_dir).map_err(|err| {
        format!(
            "failed to create XML capture directory {}: {err}",
            capture_dir.display()
        )
    })?;
    let shard_suffix = match shard_config_from_env() {
        Ok(Some(shard)) => format!("_shard_{}_{}", shard.index, shard.total),
        _ => String::new(),
    };

    Ok(Some(capture_dir.join(format!(
        "rules_rust_test_xml_capture_{}{}.log",
        process::id(),
        shard_suffix,
    ))))
}

fn cleanup_xml_log_capture(xml_log_capture: Option<&Path>) {
    if let Some(path) = xml_log_capture {
        let _ = fs::remove_file(path);
    }
}

fn run_test_binary(command: &mut Command, xml_log_capture: Option<&Path>) -> Result<TestExecution, String> {
    match xml_log_capture {
        Some(capture_path) => run_test_binary_with_xml_capture(command, capture_path),
        None => command
            .status()
            .map(|status| TestExecution {
                reported_exit_code: exit_code(status),
            })
            .map_err(|err| {
                format!(
                    "failed to run wrapped rust test binary {:?}: {err}",
                    command
                )
            }),
    }
}

fn run_test_binary_with_xml_capture(
    command: &mut Command,
    xml_log_capture: &Path,
) -> Result<TestExecution, String> {
    command.stdout(Stdio::piped());
    command.stderr(Stdio::piped());

    let mut child = command.spawn().map_err(|err| {
        format!(
            "failed to run wrapped rust test binary {:?}: {err}",
            command
        )
    })?;

    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| "wrapped rust test child stdout was not captured".to_owned())?;
    let stderr = child
        .stderr
        .take()
        .ok_or_else(|| "wrapped rust test child stderr was not captured".to_owned())?;
    let capture_writer = OpenOptions::new()
        .create(true)
        .truncate(true)
        .write(true)
        .open(xml_log_capture)
        .map_err(|err| format!("failed to open {}: {err}", xml_log_capture.display()))?;
    let capture_writer = Arc::new(Mutex::new(capture_writer));
    let timeout_signal_guard = install_timeout_signal_guard()?;

    let stdout_thread =
        spawn_stream_tee(stdout, io::stdout(), Arc::clone(&capture_writer), "stdout");
    let stderr_thread =
        spawn_stream_tee(stderr, io::stderr(), Arc::clone(&capture_writer), "stderr");

    let status = wait_for_test_binary(command, &mut child, timeout_signal_guard.as_ref())?;
    join_stream_tee(stdout_thread, "stdout")?;
    join_stream_tee(stderr_thread, "stderr")?;
    let reported_exit_code = reported_exit_code(
        status,
        timeout_signal_guard
            .as_ref()
            .map(TimeoutSignalGuard::timed_out)
            .unwrap_or(false),
    );
    drop(timeout_signal_guard);
    Ok(TestExecution {
        reported_exit_code,
    })
}

fn wait_for_test_binary(
    command: &Command,
    child: &mut process::Child,
    timeout_signal_guard: Option<&TimeoutSignalGuard>,
) -> Result<ExitStatus, String> {
    let mut force_killed_after_timeout = false;

    loop {
        match child.try_wait().map_err(|err| {
            format!(
                "failed to wait for wrapped rust test binary {:?}: {err}",
                command
            )
        })? {
            Some(status) => return Ok(status),
            None => {}
        }

        if timeout_signal_guard.is_some_and(TimeoutSignalGuard::timed_out) && !force_killed_after_timeout {
            // Once Bazel timed the shard out, keep that timeout state sticky and
            // force the child down so a SIG_IGN test cannot keep running well
            // past --test_timeout and later report success in synthetic XML.
            match child.kill() {
                Ok(()) => {}
                Err(err) if err.kind() == io::ErrorKind::InvalidInput => {}
                Err(err) => {
                    return Err(format!(
                        "failed to kill wrapped rust test binary {:?} after timeout: {err}",
                        command
                    ))
                }
            }
            force_killed_after_timeout = true;
        }

        thread::sleep(Duration::from_millis(10));
    }
}

fn spawn_stream_tee<R, W>(
    mut reader: R,
    mut writer: W,
    capture_writer: Arc<Mutex<fs::File>>,
    stream_name: &'static str,
) -> thread::JoinHandle<Result<(), String>>
where
    R: Read + Send + 'static,
    W: Write + Send + 'static,
{
    thread::spawn(move || {
        let mut buffer = [0_u8; 8192];
        loop {
            let read = reader
                .read(&mut buffer)
                .map_err(|err| format!("failed to read wrapped rust test {stream_name}: {err}"))?;
            if read == 0 {
                return Ok(());
            }

            writer
                .write_all(&buffer[..read])
                .map_err(|err| format!("failed to forward wrapped rust test {stream_name}: {err}"))?;
            writer
                .flush()
                .map_err(|err| format!("failed to flush wrapped rust test {stream_name}: {err}"))?;

            // Preserve Bazel's merged stdout/stderr semantics without buffering
            // the whole child log in memory. The fallback XML path only ever
            // re-reads this temporary file if the child left XML_OUTPUT_FILE
            // untouched, which matches Bazel's own generate-xml.sh contract.
            let mut capture_writer = capture_writer
                .lock()
                .map_err(|_| format!("failed to lock wrapped rust test {stream_name} capture"))?;
            capture_writer
                .write_all(&buffer[..read])
                .map_err(|err| format!("failed to capture wrapped rust test {stream_name}: {err}"))?;
            capture_writer
                .flush()
                .map_err(|err| format!("failed to flush wrapped rust test {stream_name} capture: {err}"))?;
        }
    })
}

fn join_stream_tee(
    handle: thread::JoinHandle<Result<(), String>>,
    stream_name: &str,
) -> Result<(), String> {
    match handle.join() {
        Ok(result) => result,
        Err(_) => Err(format!(
            "wrapped rust test {stream_name} tee thread panicked"
        )),
    }
}

fn launcher_neighbor_path(launcher_path: &Path, suffix: &str) -> Result<PathBuf, String> {
    let launcher_name = launcher_path.file_name().ok_or_else(|| {
        format!(
            "wrapped rust test launcher had no file name: {}",
            launcher_path.display()
        )
    })?;
    let mut neighbor_name = launcher_name.to_os_string();
    neighbor_name.push(suffix);
    Ok(launcher_path.with_file_name(neighbor_name))
}

fn maybe_write_xml_output(
    public_test_binary: &str,
    xml_log_capture: Option<&Path>,
    elapsed: Duration,
    reported_exit_code: i32,
) -> Result<(), String> {
    let xml_output = match env::var_os(XML_OUTPUT_FILE_ENV) {
        Some(path) if !path.is_empty() => PathBuf::from(path),
        _ => return Ok(()),
    };

    if xml_output.exists() {
        return Ok(());
    }

    if let Some(parent) = xml_output.parent() {
        fs::create_dir_all(parent).map_err(|err| {
            format!(
                "failed to create XML output directory {}: {err}",
                parent.display()
            )
        })?;
    }

    write_synthetic_xml_output(
        &xml_output,
        public_test_binary,
        xml_log_capture,
        elapsed,
        reported_exit_code,
    )
}

fn is_valid_xml_char(ch: char) -> bool {
    matches!(
        ch,
        '\u{9}'
            | '\u{A}'
            | '\u{D}'
            | '\u{20}'..='\u{D7FF}'
            | '\u{E000}'..='\u{FFFD}'
            | '\u{10000}'..='\u{10FFFF}'
    )
}

fn write_synthetic_xml_output(
    xml_output: &Path,
    public_test_binary: &str,
    xml_log_capture: Option<&Path>,
    elapsed: Duration,
    exit_code: i32,
) -> Result<(), String> {
    let test_name = xml_attribute_escape(&xml_test_name(public_test_binary));
    let duration = format!("{:.3}", elapsed.as_secs_f64());
    let error = if exit_code == 0 {
        String::new()
    } else {
        format!(
            "<error message=\"{}\"></error>",
            xml_attribute_escape(&format!("exited with error code {exit_code}"))
        )
    };
    let mut writer = io::BufWriter::new(
        fs::File::create(xml_output)
            .map_err(|err| format!("failed to create {}: {err}", xml_output.display()))?,
    );

    // Match Bazel's fallback XML shape closely so downstream JUnit/BEP readers
    // see the same suite and testcase metadata they would get from generate-xml.sh.
    writeln!(writer, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        .map_err(|err| format!("failed to write {}: {err}", xml_output.display()))?;
    writeln!(writer, "<testsuites>")
        .map_err(|err| format!("failed to write {}: {err}", xml_output.display()))?;
    writeln!(
        writer,
        "  <testsuite name=\"{test_name}\" tests=\"1\" failures=\"0\" errors=\"{errors}\">",
        errors = if exit_code == 0 { 0 } else { 1 },
    )
    .map_err(|err| format!("failed to write {}: {err}", xml_output.display()))?;
    writeln!(
        writer,
        "    <testcase name=\"{test_name}\" status=\"run\" duration=\"{duration}\" time=\"{duration}\">{error}</testcase>",
    )
    .map_err(|err| format!("failed to write {}: {err}", xml_output.display()))?;
    write_synthetic_xml_system_out(&mut writer, xml_log_capture)?;
    writeln!(writer, "  </testsuite>")
        .map_err(|err| format!("failed to write {}: {err}", xml_output.display()))?;
    writeln!(writer, "</testsuites>")
        .map_err(|err| format!("failed to write {}: {err}", xml_output.display()))
}

fn write_synthetic_xml_system_out<W: Write>(
    writer: &mut W,
    xml_log_capture: Option<&Path>,
) -> Result<(), String> {
    writeln!(writer, "      <system-out>")
        .map_err(|err| format!("failed to write synthetic system-out: {err}"))?;
    writeln!(
        writer,
        "Generated test.log (if the file is not UTF-8, then this may be unreadable):"
    )
    .map_err(|err| format!("failed to write synthetic system-out header: {err}"))?;
    write!(writer, "<![CDATA[")
        .map_err(|err| format!("failed to start synthetic system-out CDATA: {err}"))?;
    if let Some(path) = xml_log_capture {
        write_test_log_as_cdata(writer, path)?;
    }
    writeln!(writer, "]]>")
        .map_err(|err| format!("failed to finish synthetic system-out CDATA: {err}"))?;
    writeln!(writer, "      </system-out>")
        .map_err(|err| format!("failed to write synthetic system-out footer: {err}"))
}

fn write_test_log_as_cdata<W: Write>(writer: &mut W, xml_log_capture: &Path) -> Result<(), String> {
    let mut reader = match fs::File::open(xml_log_capture) {
        Ok(file) => io::BufReader::new(file),
        Err(err) if err.kind() == io::ErrorKind::NotFound => return Ok(()),
        Err(err) => {
            return Err(format!(
                "failed to open {}: {err}",
                xml_log_capture.display()
            ))
        }
    };
    let mut decode_buffer = Vec::new();
    let mut raw_buffer = [0_u8; 8192];
    let mut escape_state = CdataEscapeState::default();

    loop {
        let read = reader
            .read(&mut raw_buffer)
            .map_err(|err| format!("failed to read {}: {err}", xml_log_capture.display()))?;
        if read == 0 {
            break;
        }
        decode_buffer.extend_from_slice(&raw_buffer[..read]);
        write_decoded_test_log_chunk(writer, &mut escape_state, &mut decode_buffer, false)?;
    }

    write_decoded_test_log_chunk(writer, &mut escape_state, &mut decode_buffer, true)?;
    escape_state.finish(writer)
}

#[derive(Default)]
struct CdataEscapeState {
    pending_right_brackets: usize,
}

impl CdataEscapeState {
    fn write_text<W: Write>(&mut self, writer: &mut W, text: &str) -> Result<(), String> {
        for ch in text.chars() {
            let ch = if is_valid_xml_char(ch) { ch } else { '?' };
            self.write_char(writer, ch)?;
        }
        Ok(())
    }

    fn write_char<W: Write>(&mut self, writer: &mut W, ch: char) -> Result<(), String> {
        if ch == ']' {
            self.pending_right_brackets += 1;
            return Ok(());
        }

        if ch == '>' && self.pending_right_brackets >= 2 {
            for _ in 0..(self.pending_right_brackets - 2) {
                writer
                    .write_all(b"]")
                    .map_err(|err| format!("failed to escape synthetic system-out: {err}"))?;
            }
            writer
                .write_all(b"]]>]]<![CDATA[>")
                .map_err(|err| format!("failed to split synthetic system-out CDATA: {err}"))?;
            self.pending_right_brackets = 0;
            return Ok(());
        }

        self.flush_right_brackets(writer)?;
        let mut utf8 = [0_u8; 4];
        writer
            .write_all(ch.encode_utf8(&mut utf8).as_bytes())
            .map_err(|err| format!("failed to write synthetic system-out: {err}"))
    }

    fn flush_right_brackets<W: Write>(&mut self, writer: &mut W) -> Result<(), String> {
        while self.pending_right_brackets > 0 {
            writer
                .write_all(b"]")
                .map_err(|err| format!("failed to flush synthetic system-out: {err}"))?;
            self.pending_right_brackets -= 1;
        }
        Ok(())
    }

    fn finish<W: Write>(&mut self, writer: &mut W) -> Result<(), String> {
        self.flush_right_brackets(writer)
    }
}

fn write_decoded_test_log_chunk<W: Write>(
    writer: &mut W,
    escape_state: &mut CdataEscapeState,
    decode_buffer: &mut Vec<u8>,
    eof: bool,
) -> Result<(), String> {
    loop {
        match std::str::from_utf8(decode_buffer) {
            Ok(text) => {
                escape_state.write_text(writer, text)?;
                decode_buffer.clear();
                return Ok(());
            }
            Err(err) => {
                let valid_up_to = err.valid_up_to();
                if valid_up_to > 0 {
                    let valid_text = std::str::from_utf8(&decode_buffer[..valid_up_to])
                        .map_err(|utf8_err| {
                            format!("failed to decode synthetic system-out chunk: {utf8_err}")
                        })?;
                    escape_state.write_text(writer, valid_text)?;
                    decode_buffer.drain(..valid_up_to);
                    continue;
                }

                if let Some(invalid_len) = err.error_len() {
                    decode_buffer.drain(..invalid_len);
                    escape_state.write_char(writer, '?')?;
                    continue;
                }

                if eof {
                    decode_buffer.clear();
                    escape_state.write_char(writer, '?')?;
                }
                return Ok(());
            }
        }
    }
}

fn xml_test_name(public_test_binary: &str) -> String {
    let mut test_name = public_test_binary.trim_start_matches("./").to_owned();
    if let Some(stripped) = test_name.strip_prefix("../") {
        test_name = stripped.to_owned();
    }

    match shard_config_from_env() {
        Ok(Some(shard)) if shard.total > 0 => {
            format!("{}_shard_{}/{}", test_name, shard.index + 1, shard.total)
        }
        _ => test_name,
    }
}

fn xml_attribute_escape(value: &str) -> String {
    let mut escaped = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&apos;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            _ => escaped.push(ch),
        }
    }
    escaped
}

fn ensure_test_binary_exists(path: PathBuf) -> Result<PathBuf, String> {
    if !path.exists() {
        return Err(format!(
            "wrapped rust test binary does not exist at: {}",
            path.display()
        ));
    }

    Ok(path)
}

fn takes_value(arg: &str) -> Option<&'static str> {
    match arg {
        "--color" => Some("--color"),
        "--ensure-time" => Some("--ensure-time"),
        "--format" => Some("--format"),
        "--logfile" => Some("--logfile"),
        "--report-time" => Some("--report-time"),
        "--shuffle-seed" => Some("--shuffle-seed"),
        "--skip" => Some("--skip"),
        "--test-threads" => Some("--test-threads"),
        "-Z" => Some("-Z"),
        _ => None,
    }
}

fn configure_listing_command(command: &mut Command) {
    if env::var_os(LLVM_PROFILE_FILE_ENV).is_some() {
        command.env(LLVM_PROFILE_FILE_ENV, discarded_listing_profile_path());
    }
}

fn discarded_listing_profile_path() -> PathBuf {
    let base_dir = match env::var_os("TEST_TMPDIR") {
        Some(path) if !path.is_empty() => PathBuf::from(path),
        _ => env::temp_dir(),
    };

    base_dir.join("rules_rust_test_listing_%p-%m.profraw")
}

fn exit_code(status: ExitStatus) -> i32 {
    if let Some(code) = status.code() {
        return code;
    }

    #[cfg(target_family = "unix")]
    {
        use std::os::unix::process::ExitStatusExt;

        if let Some(signal) = status.signal() {
            return 128 + signal;
        }
    }

    1
}

fn reported_exit_code(status: ExitStatus, timed_out: bool) -> i32 {
    if timed_out {
        // Bazel reports timeouts as SIGTERM-style failures even when the child
        // later exits 0 or the launcher has to force-kill a SIG_IGN child.
        return TIMEOUT_EXIT_CODE;
    }

    exit_code(status)
}

fn exit_with_status(status: ExitStatus) -> ! {
    process::exit(exit_code(status));
}

#[cfg(test)]
mod tests {
    use super::{
        absolute_invocation_path, configure_listing_command, discarded_listing_profile_path,
        empty_shard_filter, empty_test_filter, filter_tests_by_name, has_exact_flag,
        inferred_test_filters, launcher_neighbor_path, launcher_public_test_binary_path,
        install_timeout_signal_guard, maybe_write_xml_output, normalize_public_test_binary_path,
        maybe_prepare_xml_log_capture, parse_args, parse_test_listing, public_test_binary_runfiles_path,
        reported_exit_code, select_shard_tests, writes_xml_output, xml_test_name, ParsedArgs,
        ShardConfig, LLVM_PROFILE_FILE_ENV, SIGTERM_SIGNAL, TEST_BINARY_ENV,
        TEST_BINARY_RUNFILES_PATH_ENV,
        TESTBRIDGE_TEST_ONLY_ENV, XML_OUTPUT_FILE_ENV,
    };
    use std::env;
    use std::ffi::OsString;
    use std::fs;
    use std::io;
    #[cfg(unix)]
    use std::os::unix::process::ExitStatusExt;
    #[cfg(windows)]
    use std::os::windows::process::ExitStatusExt;
    use std::path::{Path, PathBuf};
    use std::process::{self, Command, ExitStatus};
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::{Duration, SystemTime, UNIX_EPOCH};
    #[cfg(unix)]
    unsafe extern "C" {
        fn getpid() -> i32;
        fn kill(pid: i32, signal: i32) -> i32;
    }

    struct EnvGuard {
        key: &'static str,
        previous: Option<OsString>,
    }

    impl EnvGuard {
        fn set(key: &'static str, value: Option<&str>) -> Self {
            let previous = env::var_os(key);
            match value {
                Some(value) => env::set_var(key, value),
                None => env::remove_var(key),
            }
            EnvGuard { key, previous }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            match &self.previous {
                Some(value) => env::set_var(self.key, value),
                None => env::remove_var(self.key),
            }
        }
    }

    struct TempDir {
        path: PathBuf,
    }

    impl TempDir {
        fn new(prefix: &str) -> io::Result<Self> {
            static NEXT_ID: AtomicUsize = AtomicUsize::new(0);

            let unique_id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
            let timestamp = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_else(|_| Duration::from_secs(0))
                .as_nanos();
            let path = env::temp_dir().join(format!(
                "{prefix}_{}_{}_{}",
                process::id(),
                timestamp,
                unique_id
            ));
            fs::create_dir_all(&path)?;
            Ok(TempDir { path })
        }

        fn path(&self) -> &Path {
            &self.path
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.path);
        }
    }

    fn success_exit_status() -> ExitStatus {
        #[cfg(unix)]
        {
            ExitStatus::from_raw(0)
        }
        #[cfg(windows)]
        {
            ExitStatus::from_raw(0)
        }
    }

    #[test]
    fn parse_args_keeps_membership_flags_for_listing() {
        let parsed = parse_args(vec![
            OsString::from("--ignored"),
            OsString::from("--skip"),
            OsString::from("skip_me"),
            OsString::from("alpha"),
            OsString::from("beta"),
            OsString::from("--format"),
            OsString::from("json"),
        ]);

        assert_eq!(
            parsed,
            ParsedArgs {
                passthrough: false,
                has_explicit_filters: true,
                listing_args: vec![
                    OsString::from("--ignored"),
                    OsString::from("--skip"),
                    OsString::from("skip_me"),
                    OsString::from("alpha"),
                    OsString::from("beta"),
                ],
                execution_args: vec![
                    OsString::from("--ignored"),
                    OsString::from("--skip"),
                    OsString::from("skip_me"),
                    OsString::from("--format"),
                    OsString::from("json"),
                ],
            }
        );
    }

    #[test]
    fn parse_args_supports_inline_values_and_passthrough_mode() {
        let parsed = parse_args(vec![
            OsString::from("--skip=beta"),
            OsString::from("--shuffle-seed=42"),
            OsString::from("--list"),
        ]);

        assert_eq!(
            parsed,
            ParsedArgs {
                passthrough: true,
                has_explicit_filters: false,
                listing_args: vec![OsString::from("--skip=beta")],
                execution_args: vec![
                    OsString::from("--skip=beta"),
                    OsString::from("--shuffle-seed=42"),
                    OsString::from("--list"),
                ],
            }
        );
    }

    #[test]
    fn parse_args_preserves_repeated_skip_flags() {
        let parsed = parse_args(vec![
            OsString::from("--skip"),
            OsString::from("alpha"),
            OsString::from("--skip"),
            OsString::from("beta"),
        ]);

        assert_eq!(
            parsed.listing_args,
            vec![
                OsString::from("--skip"),
                OsString::from("alpha"),
                OsString::from("--skip"),
                OsString::from("beta"),
            ]
        );
        assert_eq!(parsed.execution_args, parsed.listing_args);
        assert!(!parsed.has_explicit_filters);
    }

    #[test]
    fn parse_listing_accepts_test_and_benchmark_entries() {
        let names = parse_test_listing(b"alpha: test\nbeta: benchmark\n").unwrap();
        assert_eq!(names, vec!["alpha".to_owned(), "beta".to_owned()]);
    }

    #[test]
    fn select_shard_tests_uses_round_robin_partitioning() {
        let names = vec![
            "test_0".to_owned(),
            "test_1".to_owned(),
            "test_2".to_owned(),
            "test_3".to_owned(),
            "test_4".to_owned(),
        ];

        assert_eq!(
            select_shard_tests(&names, ShardConfig { index: 1, total: 3 }),
            vec!["test_1".to_owned(), "test_4".to_owned()],
        );
    }

    #[test]
    fn empty_shard_filter_is_unique_per_shard() {
        assert_eq!(
            empty_shard_filter(ShardConfig { index: 2, total: 5 }),
            OsString::from("__rules_rust_shard_empty___2_5"),
        );
    }

    #[test]
    fn empty_test_filter_is_stable() {
        assert_eq!(
            empty_test_filter(),
            OsString::from("__rules_rust_shard_empty___unmatched"),
        );
    }

    #[test]
    fn inferred_test_filters_preserve_namespaced_testbridge_value() {
        let _testbridge_guard = EnvGuard::set(
            TESTBRIDGE_TEST_ONLY_ENV,
            Some("tests::empty_test_filter_is_stable"),
        );

        assert_eq!(
            inferred_test_filters(false).unwrap(),
            vec![OsString::from("tests::empty_test_filter_is_stable")],
        );
    }

    #[test]
    fn explicit_filters_override_testbridge_value() {
        let _testbridge_guard = EnvGuard::set(TESTBRIDGE_TEST_ONLY_ENV, Some("alpha:beta"));

        assert!(inferred_test_filters(true).unwrap().is_empty());
    }

    #[test]
    fn filter_tests_by_name_uses_substring_matching_by_default() {
        let test_names = vec!["alpha::one".to_owned(), "beta::two".to_owned()];

        assert_eq!(
            filter_tests_by_name(&test_names, &[OsString::from("alpha")], false),
            vec!["alpha::one".to_owned()],
        );
    }

    #[test]
    fn filter_tests_by_name_respects_exact_matching() {
        let test_names = vec!["alpha".to_owned(), "alpha::one".to_owned()];

        assert_eq!(
            filter_tests_by_name(&test_names, &[OsString::from("alpha")], true),
            vec!["alpha".to_owned()],
        );
    }

    #[test]
    fn has_exact_flag_detects_existing_flag() {
        assert!(has_exact_flag(&[
            OsString::from("--ignored"),
            OsString::from("--exact"),
        ]));
        assert!(!has_exact_flag(&[OsString::from("--ignored")]));
    }

    #[test]
    fn discarded_listing_profile_path_prefers_test_tmpdir() {
        let _tmpdir_guard = EnvGuard::set("TEST_TMPDIR", Some("/tmp/rules_rust_sharding"));

        assert_eq!(
            discarded_listing_profile_path(),
            PathBuf::from("/tmp/rules_rust_sharding/rules_rust_test_listing_%p-%m.profraw"),
        );
    }

    #[test]
    fn listing_command_redirects_profile_file() {
        let _profile_guard = EnvGuard::set(LLVM_PROFILE_FILE_ENV, Some("real.profraw"));
        let _tmpdir_guard = EnvGuard::set("TEST_TMPDIR", Some("/tmp/rules_rust_sharding"));
        let mut command = Command::new("echo");

        configure_listing_command(&mut command);

        let envs: Vec<_> = command.get_envs().collect();
        assert_eq!(envs.len(), 1);
        assert_eq!(envs[0].0, std::ffi::OsStr::new(LLVM_PROFILE_FILE_ENV));
        assert_eq!(
            envs[0].1,
            Some(
                PathBuf::from("/tmp/rules_rust_sharding/rules_rust_test_listing_%p-%m.profraw")
                    .as_os_str()
            ),
        );
    }

    #[test]
    fn public_test_binary_runfiles_path_uses_wrapper_override() {
        let _runfiles_guard = EnvGuard::set(
            TEST_BINARY_RUNFILES_PATH_ENV,
            Some("test/unit/test_sharding/sharded_test"),
        );

        assert_eq!(
            public_test_binary_runfiles_path().unwrap(),
            "test/unit/test_sharding/sharded_test",
        );
    }

    #[test]
    fn public_test_binary_runfiles_path_normalizes_launcher_test_binary() {
        let _runfiles_guard = EnvGuard::set(TEST_BINARY_RUNFILES_PATH_ENV, None);
        let _test_binary_guard = EnvGuard::set(
            TEST_BINARY_ENV,
            Some("test/unit/test_sharding/_test_sharding_launcher/sharded_test"),
        );

        assert_eq!(
            public_test_binary_runfiles_path().unwrap(),
            "test/unit/test_sharding/sharded_test",
        );
    }

    #[test]
    fn normalize_public_test_binary_path_strips_private_launcher_segment() {
        assert_eq!(
            normalize_public_test_binary_path(
                "test\\unit\\test_sharding\\_test_sharding_launcher\\sharded_test.exe"
            ),
            "test\\unit\\test_sharding\\sharded_test.exe",
        );
    }

    #[test]
    fn xml_test_name_uses_public_binary_name() {
        let _total_guard = EnvGuard::set("TEST_TOTAL_SHARDS", Some("3"));
        let _index_guard = EnvGuard::set("TEST_SHARD_INDEX", Some("1"));

        assert_eq!(
            xml_test_name("./test/unit/test_sharding/sharded_test"),
            "test/unit/test_sharding/sharded_test_shard_2/3",
        );
    }

    #[test]
    fn writes_xml_output_only_when_requested() {
        let _xml_guard = EnvGuard::set(XML_OUTPUT_FILE_ENV, None);
        assert!(!writes_xml_output());

        let _xml_guard = EnvGuard::set(XML_OUTPUT_FILE_ENV, Some("test.xml"));
        assert!(writes_xml_output());
    }

    #[test]
    fn maybe_prepare_xml_log_capture_prefers_test_tmpdir() {
        let temp_dir = TempDir::new("rules_rust_sharding_capture").unwrap();
        let xml_output = temp_dir.path().join("test.xml");
        let _xml_guard = EnvGuard::set(XML_OUTPUT_FILE_ENV, Some(xml_output.to_str().unwrap()));
        let _tmpdir_guard = EnvGuard::set("TEST_TMPDIR", Some(temp_dir.path().to_str().unwrap()));

        let capture = maybe_prepare_xml_log_capture().unwrap().unwrap();

        assert_eq!(capture.parent().unwrap(), temp_dir.path());
        assert!(
            capture
                .file_name()
                .unwrap()
                .to_string_lossy()
                .contains("rules_rust_test_xml_capture_")
        );
    }

    #[test]
    fn maybe_write_xml_output_preserves_system_out_from_test_log() {
        let temp_dir = TempDir::new("rules_rust_sharding_xml").unwrap();
        let xml_output = temp_dir.path().join("test.xml");
        let capture_path = temp_dir.path().join("captured.log");
        let _xml_guard = EnvGuard::set(XML_OUTPUT_FILE_ENV, Some(xml_output.to_str().unwrap()));
        fs::write(&capture_path, b"stdout line\ninvalid \x00 byte\ncdata ]]> marker\n").unwrap();

        maybe_write_xml_output(
            "test/unit/test_sharding/sharded_test",
            Some(&capture_path),
            Duration::from_millis(1250),
            0,
        )
        .unwrap();

        let xml = fs::read_to_string(&xml_output).unwrap();
        assert!(xml.contains("test/unit/test_sharding/sharded_test"));
        assert!(xml.contains("<system-out>"));
        assert!(xml.contains("Generated test.log"));
        assert!(xml.contains("stdout line"));
        assert!(xml.contains("invalid ? byte"));
        assert!(xml.contains("cdata ]]>]]<![CDATA[> marker"));
        assert!(!xml.contains("_test_sharding_launcher"));
        assert!(!xml.contains("__test_sharding_bin"));
    }

    #[test]
    fn maybe_write_xml_output_uses_public_name_when_test_binary_is_launcher_path() {
        let temp_dir = TempDir::new("rules_rust_sharding_timeout_xml").unwrap();
        let xml_output = temp_dir.path().join("test.xml");
        let _xml_guard = EnvGuard::set(XML_OUTPUT_FILE_ENV, Some(xml_output.to_str().unwrap()));
        let _runfiles_guard = EnvGuard::set(TEST_BINARY_RUNFILES_PATH_ENV, None);
        let _test_binary_guard = EnvGuard::set(
            TEST_BINARY_ENV,
            Some("test/unit/test_sharding/_test_sharding_launcher/sharded_test"),
        );
        let capture_path = temp_dir.path().join("captured.log");
        fs::write(&capture_path, b"-- Test timed out at 2026-04-09 10:11:08 UTC --\n").unwrap();

        let public_test_binary = public_test_binary_runfiles_path().unwrap();
        maybe_write_xml_output(
            &public_test_binary,
            Some(&capture_path),
            Duration::from_secs(1),
            0,
        )
        .unwrap();

        let xml = fs::read_to_string(&xml_output).unwrap();
        assert!(xml.contains("test/unit/test_sharding/sharded_test"));
        assert!(xml.contains("-- Test timed out at 2026-04-09 10:11:08 UTC --"));
        assert!(!xml.contains("_test_sharding_launcher"));
    }

    #[cfg(unix)]
    #[test]
    fn timeout_signal_guard_subprocess_helper() {
        if env::var_os("RULES_RUST_TIMEOUT_SIGNAL_SELF_TEST").is_none() {
            return;
        }

        let _xml_guard = EnvGuard::set(XML_OUTPUT_FILE_ENV, Some("test.xml"));
        let _guard = install_timeout_signal_guard().unwrap();

        // This exercises the timeout-specific launcher path in a subprocess so
        // the parent test process can assert that SIGTERM is recorded, not
        // dropped, while the wrapper stays alive to write fallback XML.
        let rc = unsafe { kill(getpid(), SIGTERM_SIGNAL) };
        assert_eq!(rc, 0);
        assert!(_guard.as_ref().map(|guard| guard.timed_out()).unwrap_or(false));
    }

    #[cfg(unix)]
    #[test]
    fn timeout_signal_guard_records_sigterm_when_xml_output_is_requested() {
        let output = Command::new(env::current_exe().unwrap())
            .arg("--exact")
            .arg("timeout_signal_guard_subprocess_helper")
            .env("RULES_RUST_TIMEOUT_SIGNAL_SELF_TEST", "1")
            .env("RUST_TEST_THREADS", "1")
            .output()
            .unwrap();

        assert!(
            output.status.success(),
            "expected subprocess to survive SIGTERM with XML output enabled, stdout:\n{}\nstderr:\n{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr),
        );
    }

    #[cfg(unix)]
    #[test]
    fn reported_exit_code_preserves_timeout_even_after_success() {
        assert_eq!(reported_exit_code(success_exit_status(), true), 143);
    }

    #[test]
    fn launcher_path_uses_public_test_binary() {
        assert_eq!(
            launcher_public_test_binary_path(Path::new(
                "/execroot/rules_rust/bazel-out/dbg-fastbuild/bin/test/unit/test_sharding/_test_sharding_launcher/sharded_test"
            ))
            .unwrap(),
            PathBuf::from(
                "/execroot/rules_rust/bazel-out/dbg-fastbuild/bin/test/unit/test_sharding/sharded_test"
            ),
        );
    }

    #[test]
    fn launcher_neighbor_path_appends_suffix() {
        assert_eq!(
            launcher_neighbor_path(
                Path::new("/execroot/rules_rust/bazel-out/dbg-fastbuild/bin/test/unit/test_sharding/_test_sharding_launcher/sharded_test"),
                ".runfiles_manifest",
            )
            .unwrap(),
            PathBuf::from(
                "/execroot/rules_rust/bazel-out/dbg-fastbuild/bin/test/unit/test_sharding/_test_sharding_launcher/sharded_test.runfiles_manifest"
            ),
        );
    }

    #[test]
    fn absolute_invocation_path_uses_cwd_for_relative_paths() {
        let relative = PathBuf::from("./bazel-bin/test/unit/test_sharding/_test_sharding_launcher/sharded_test");
        let expected = env::current_dir().unwrap().join(&relative);
        assert_eq!(absolute_invocation_path(relative).unwrap(), expected);
    }

}
