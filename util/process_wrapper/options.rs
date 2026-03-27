use std::collections::HashMap;
use std::env;
use std::fmt;
use std::fs::{self, File};
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::exit;

use crate::flags::{FlagParseError, Flags, ParseOutcome};
use crate::rustc;
use crate::util::*;

#[derive(Debug)]
pub(crate) enum OptionError {
    FlagError(FlagParseError),
    Generic(String),
}

impl fmt::Display for OptionError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::FlagError(e) => write!(f, "error parsing flags: {e}"),
            Self::Generic(s) => write!(f, "{s}"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum SubprocessPipeliningMode {
    Metadata,
    Full,
}

#[derive(Debug)]
pub(crate) struct Options {
    // Contains the path to the child executable
    pub(crate) executable: String,
    // Contains arguments for the child process fetched from files.
    pub(crate) child_arguments: Vec<String>,
    // Temporary standalone-mode paramfiles that should be removed after the
    // child process completes.
    pub(crate) temporary_expanded_paramfiles: Vec<PathBuf>,
    // Contains environment variables for the child process fetched from files.
    pub(crate) child_environment: HashMap<String, String>,
    // If set, create the specified file after the child process successfully
    // terminated its execution.
    pub(crate) touch_file: Option<String>,
    // If set to (source, dest) copies the source file to dest.
    pub(crate) copy_output: Option<(String, String)>,
    // If set, redirects the child process stdout to this file.
    pub(crate) stdout_file: Option<String>,
    // If set, redirects the child process stderr to this file.
    pub(crate) stderr_file: Option<String>,
    // If set, also logs all unprocessed output from the rustc output to this file.
    // Meant to be used to get json output out of rustc for tooling usage.
    pub(crate) output_file: Option<String>,
    // This controls the output format of rustc messages.
    pub(crate) rustc_output_format: Option<rustc::ErrorFormat>,
    // Worker pipelining mode detected from @paramfile flags.
    // Set when --pipelining-metadata or --pipelining-full is found.
    // None when running outside of worker pipelining.
    pub(crate) pipelining_mode: Option<SubprocessPipeliningMode>,
    // The expected .rlib output path, passed via --pipelining-rlib-path=<path>
    // in the @paramfile. Used by the local-mode no-op optimization: if this
    // file already exists (produced as a side-effect by the metadata action's
    // rustc invocation), the full action can skip running rustc entirely.
    pub(crate) pipelining_rlib_path: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct ParsedPwArgs {
    pub(crate) subst: Vec<(String, String)>,
    pub(crate) env_files: Vec<String>,
    pub(crate) arg_files: Vec<String>,
    pub(crate) stable_status_file: Option<String>,
    pub(crate) volatile_status_file: Option<String>,
    pub(crate) output_file: Option<String>,
    pub(crate) rustc_output_format: Option<String>,
    pub(crate) require_explicit_unstable_features: bool,
}

#[derive(Default)]
struct TemporaryExpandedParamFiles {
    paths: Vec<PathBuf>,
}

impl TemporaryExpandedParamFiles {
    fn track(&mut self, path: PathBuf) {
        self.paths.push(path);
    }

    fn into_inner(mut self) -> Vec<PathBuf> {
        std::mem::take(&mut self.paths)
    }
}

impl Drop for TemporaryExpandedParamFiles {
    fn drop(&mut self) {
        for path in self.paths.drain(..) {
            let _ = fs::remove_file(path);
        }
    }
}

pub(crate) fn options() -> Result<Options, OptionError> {
    options_from_args(env::args().collect())
}

pub(crate) fn options_from_args(raw_args: Vec<String>) -> Result<Options, OptionError> {
    // Process argument list until -- is encountered.
    // Everything after is sent to the child process.
    let mut subst_mapping_raw = None;
    let mut stable_status_file_raw = None;
    let mut volatile_status_file_raw = None;
    let mut env_file_raw = None;
    let mut arg_file_raw = None;
    let mut touch_file = None;
    let mut copy_output_raw = None;
    let mut stdout_file = None;
    let mut stderr_file = None;
    let mut output_file = None;
    let mut rustc_output_format_raw = None;
    let mut flags = Flags::new();
    let mut require_explicit_unstable_features = None;
    flags.define_repeated_flag("--subst", "", &mut subst_mapping_raw);
    flags.define_flag("--stable-status-file", "", &mut stable_status_file_raw);
    flags.define_flag("--volatile-status-file", "", &mut volatile_status_file_raw);
    flags.define_repeated_flag(
        "--env-file",
        "File(s) containing environment variables to pass to the child process.",
        &mut env_file_raw,
    );
    flags.define_repeated_flag(
        "--arg-file",
        "File(s) containing command line arguments to pass to the child process.",
        &mut arg_file_raw,
    );
    flags.define_flag(
        "--touch-file",
        "Create this file after the child process runs successfully.",
        &mut touch_file,
    );
    flags.define_repeated_flag("--copy-output", "", &mut copy_output_raw);
    flags.define_flag(
        "--stdout-file",
        "Redirect subprocess stdout in this file.",
        &mut stdout_file,
    );
    flags.define_flag(
        "--stderr-file",
        "Redirect subprocess stderr in this file.",
        &mut stderr_file,
    );
    flags.define_flag(
        "--output-file",
        "Log all unprocessed subprocess stderr in this file.",
        &mut output_file,
    );
    flags.define_flag(
        "--rustc-output-format",
        "The expected rustc output format. Valid values: json, rendered.",
        &mut rustc_output_format_raw,
    );
    flags.define_flag(
        "--require-explicit-unstable-features",
        "If set, an empty -Zallow-features= will be added to the rustc command line whenever no \
         other -Zallow-features= is present in the rustc flags.",
        &mut require_explicit_unstable_features,
    );

    let mut child_args = match flags.parse(raw_args).map_err(OptionError::FlagError)? {
        ParseOutcome::Help(help) => {
            eprintln!("{help}");
            exit(0);
        }
        ParseOutcome::Parsed(p) => p,
    };
    let current_dir = std::env::current_dir()
        .map_err(|e| OptionError::Generic(format!("failed to get current directory: {e}")))?
        .to_str()
        .ok_or_else(|| OptionError::Generic("current directory not utf-8".to_owned()))?
        .to_owned();
    let subst_mappings = subst_mapping_raw
        .unwrap_or_default()
        .into_iter()
        .map(|arg| {
            let (key, val) = arg.split_once('=').ok_or_else(|| {
                OptionError::Generic(format!("empty key for substitution '{arg}'"))
            })?;
            let v = if val == "${pwd}" {
                current_dir.as_str()
            } else {
                val
            }
            .to_owned();
            Ok((key.to_owned(), v))
        })
        .collect::<Result<Vec<(String, String)>, OptionError>>()?;
    // Process --copy-output
    let copy_output = copy_output_raw
        .map(|co| {
            if co.len() != 2 {
                return Err(OptionError::Generic(format!(
                    "\"--copy-output\" needs exactly 2 parameters, {} provided",
                    co.len()
                )));
            }
            let copy_source = &co[0];
            let copy_dest = &co[1];
            if copy_source == copy_dest {
                return Err(OptionError::Generic(format!(
                    "\"--copy-output\" source ({copy_source}) and dest ({copy_dest}) need to be different.",
                )));
            }
            Ok((copy_source.to_owned(), copy_dest.to_owned()))
        })
        .transpose()?;

    let require_explicit_unstable_features =
        require_explicit_unstable_features.is_some_and(|s| s == "true");

    // Expand @paramfiles and collect any relocated PW flags found inside them.
    // This must happen before environment_block() so that relocated --env-file
    // and --stable/volatile-status-file values are incorporated.
    let mut file_arguments = args_from_file(arg_file_raw.unwrap_or_default())?;
    child_args.append(&mut file_arguments);
    let mut temporary_expanded_paramfiles = TemporaryExpandedParamFiles::default();
    let (child_args, relocated) = prepare_args_internal(
        child_args,
        &subst_mappings,
        require_explicit_unstable_features,
        None,
        None,
        &mut temporary_expanded_paramfiles,
    )?;

    // Merge relocated env-files from @paramfile with those from startup args.
    let mut env_files = env_file_raw.unwrap_or_default();
    env_files.extend(relocated.env_files);

    // Merge relocated arg-files: append their contents to child_args,
    // applying ${pwd} and other substitutions to each line.
    let mut child_args = child_args;
    if !relocated.arg_files.is_empty() {
        for arg in args_from_file(relocated.arg_files)? {
            let mut arg = arg;
            crate::util::apply_substitutions(&mut arg, &subst_mappings);
            child_args.push(arg);
        }
    }

    // Merge relocated stamp files with startup stamp files.
    let stable_status_file = relocated.stable_status_file.or(stable_status_file_raw);
    let volatile_status_file = relocated.volatile_status_file.or(volatile_status_file_raw);

    // Override output_file and rustc_output_format if relocated versions found.
    let output_file = relocated.output_file.or(output_file);
    let rustc_output_format_raw = relocated.rustc_output_format.or(rustc_output_format_raw);

    let rustc_output_format = rustc_output_format_raw
        .map(|v| match v.as_str() {
            "json" => Ok(rustc::ErrorFormat::Json),
            "rendered" => Ok(rustc::ErrorFormat::Rendered),
            _ => Err(OptionError::Generic(format!(
                "invalid --rustc-output-format '{v}'",
            ))),
        })
        .transpose()?;

    // Prepare the environment variables, unifying those read from files with the ones
    // of the current process.
    let vars = build_child_environment(
        &env_files,
        stable_status_file.as_deref(),
        volatile_status_file.as_deref(),
        &subst_mappings,
    )
    .map_err(OptionError::Generic)?;

    // Split the executable path from the rest of the arguments.
    let (exec_path, args) = child_args.split_first().ok_or_else(|| {
        OptionError::Generic(
            "at least one argument after -- is required (the child process path)".to_owned(),
        )
    })?;

    Ok(Options {
        executable: exec_path.to_owned(),
        child_arguments: args.to_vec(),
        temporary_expanded_paramfiles: temporary_expanded_paramfiles.into_inner(),
        child_environment: vars,
        touch_file,
        copy_output,
        stdout_file,
        stderr_file,
        output_file,
        rustc_output_format,
        pipelining_mode: relocated.pipelining_mode,
        pipelining_rlib_path: relocated.pipelining_rlib_path,
    })
}

fn args_from_file(paths: Vec<String>) -> Result<Vec<String>, OptionError> {
    let mut args = vec![];
    for path in paths.iter() {
        let mut lines = read_file_to_array(path).map_err(|err| {
            OptionError::Generic(format!(
                "{} while processing args from file paths: {:?}",
                err, &paths
            ))
        })?;
        args.append(&mut lines);
    }
    Ok(args)
}

fn env_from_files(paths: &[String]) -> Result<HashMap<String, String>, String> {
    let mut env_vars = HashMap::new();
    for path in paths {
        let lines = read_file_to_array(path)
            .map_err(|err| format!("failed to read env-file '{}': {}", path, err))?;
        for line in lines.into_iter() {
            let (k, v) = line
                .split_once('=')
                .ok_or_else(|| format!("env-file '{}': invalid line (no '='): {}", path, line))?;
            env_vars.insert(k.to_owned(), v.to_owned());
        }
    }
    Ok(env_vars)
}

fn is_allow_features_flag(arg: &str) -> bool {
    arg.starts_with("-Zallow-features=") || arg.starts_with("allow-features=")
}

/// Returns true for worker-pipelining protocol flags that should never be
/// forwarded to rustc. These flags live in the @paramfile (rustc_flags) so
/// both RustcMetadata and Rustc actions share identical startup args (same
/// worker key). They must be stripped before the args reach rustc.
pub(crate) fn is_pipelining_flag(arg: &str) -> bool {
    arg == "--pipelining-metadata"
        || arg == "--pipelining-full"
        || arg.starts_with("--pipelining-key=")
        || arg.starts_with("--pipelining-rlib-path=")
}

/// Returns true if `arg` is a process_wrapper flag that may appear in the
/// @paramfile when worker pipelining is active.  These flags are placed in
/// the paramfile (per-request args) instead of startup args so that all
/// worker actions share the same WorkerKey.  They must be stripped before the
/// expanded paramfile reaches rustc.
///
/// Unlike pipelining flags (which are standalone), these flags consume the
/// *next* argument as their value, so the caller must skip it too.
pub(crate) fn is_relocated_pw_flag(arg: &str) -> bool {
    arg == "--output-file"
        || arg == "--rustc-output-format"
        || arg == "--env-file"
        || arg == "--arg-file"
        || arg == "--stable-status-file"
        || arg == "--volatile-status-file"
}

#[derive(Default, Debug, Clone, PartialEq, Eq)]
pub(crate) struct RelocatedPwFlags {
    pub(crate) env_files: Vec<String>,
    pub(crate) arg_files: Vec<String>,
    pub(crate) output_file: Option<String>,
    pub(crate) rustc_output_format: Option<String>,
    pub(crate) stable_status_file: Option<String>,
    pub(crate) volatile_status_file: Option<String>,
    pub(crate) pipelining_mode: Option<SubprocessPipeliningMode>,
    pub(crate) pipelining_rlib_path: Option<String>,
}

impl RelocatedPwFlags {
    pub(crate) fn merge_from(&mut self, other: Self) {
        self.env_files.extend(other.env_files);
        self.arg_files.extend(other.arg_files);
        if other.output_file.is_some() {
            self.output_file = other.output_file;
        }
        if other.rustc_output_format.is_some() {
            self.rustc_output_format = other.rustc_output_format;
        }
        if other.stable_status_file.is_some() {
            self.stable_status_file = other.stable_status_file;
        }
        if other.volatile_status_file.is_some() {
            self.volatile_status_file = other.volatile_status_file;
        }
        if other.pipelining_mode.is_some() {
            self.pipelining_mode = other.pipelining_mode;
        }
        if other.pipelining_rlib_path.is_some() {
            self.pipelining_rlib_path = other.pipelining_rlib_path;
        }
    }
}

#[derive(Default, Debug, Clone, PartialEq, Eq)]
pub(crate) struct NormalizedRustcMetadata {
    pub(crate) has_allow_features: bool,
    pub(crate) relocated: RelocatedPwFlags,
    pub(crate) pipelining_key: Option<String>,
}

#[derive(Clone, Copy)]
enum ParamFileReadErrorMode {
    Error,
    PreserveArg,
}

/// On Windows, resolve `.rs` source file paths that pass through junctions
/// containing relative symlinks.  Windows cannot resolve chained reparse
/// points (junction -> relative symlink -> symlink) in a single traversal,
/// causing rustc to fail with ERROR_PATH_NOT_FOUND.
///
/// Only resolves paths ending in `.rs` to avoid changing crate identity
/// for `--extern` and `-L` paths (which would cause crate version mismatches).
#[cfg(windows)]
pub(crate) fn resolve_external_path(arg: &str) -> std::borrow::Cow<'_, str> {
    use std::borrow::Cow;
    use std::path::Path;
    if !arg.ends_with(".rs") {
        return Cow::Borrowed(arg);
    }
    if !arg.starts_with("external/") && !arg.starts_with("external\\") {
        return Cow::Borrowed(arg);
    }
    let path = Path::new(arg);
    let mut components = path.components();
    let Some(_external) = components.next() else {
        return Cow::Borrowed(arg);
    };
    let Some(repo_name) = components.next() else {
        return Cow::Borrowed(arg);
    };
    let junction = Path::new("external").join(repo_name);
    let Ok(resolved) = std::fs::read_link(&junction) else {
        return Cow::Borrowed(arg);
    };
    let remainder: std::path::PathBuf = components.collect();
    if remainder.as_os_str().is_empty() {
        return Cow::Borrowed(arg);
    }
    Cow::Owned(resolved.join(remainder).to_string_lossy().into_owned())
}

/// No-op on non-Windows: returns the argument unchanged without allocating.
#[cfg(not(windows))]
#[inline]
pub(crate) fn resolve_external_path(arg: &str) -> std::borrow::Cow<'_, str> {
    std::borrow::Cow::Borrowed(arg)
}

pub(crate) fn parse_pw_args(pw_args: &[String], pwd: &std::path::Path) -> ParsedPwArgs {
    let current_dir = pwd.to_string_lossy().into_owned();
    let mut parsed = ParsedPwArgs {
        subst: Vec::new(),
        env_files: Vec::new(),
        arg_files: Vec::new(),
        stable_status_file: None,
        volatile_status_file: None,
        output_file: None,
        rustc_output_format: None,
        require_explicit_unstable_features: false,
    };
    let mut i = 0;
    while i < pw_args.len() {
        match pw_args[i].as_str() {
            "--subst" => {
                if let Some(kv) = pw_args.get(i + 1) {
                    if let Some((k, v)) = kv.split_once('=') {
                        let resolved = if v == "${pwd}" { &current_dir } else { v };
                        parsed.subst.push((k.to_owned(), resolved.to_owned()));
                    }
                    i += 1;
                }
            }
            "--env-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.env_files.push(path.clone());
                    i += 1;
                }
            }
            "--arg-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.arg_files.push(path.clone());
                    i += 1;
                }
            }
            "--output-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.output_file = Some(path.clone());
                    i += 1;
                }
            }
            "--stable-status-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.stable_status_file = Some(path.clone());
                    i += 1;
                }
            }
            "--volatile-status-file" => {
                if let Some(path) = pw_args.get(i + 1) {
                    parsed.volatile_status_file = Some(path.clone());
                    i += 1;
                }
            }
            "--rustc-output-format" => {
                if let Some(val) = pw_args.get(i + 1) {
                    parsed.rustc_output_format = Some(val.clone());
                    i += 1;
                }
            }
            "--require-explicit-unstable-features" => {
                if let Some(val) = pw_args.get(i + 1) {
                    parsed.require_explicit_unstable_features = val == "true";
                    i += 1;
                }
            }
            _ => {}
        }
        i += 1;
    }
    parsed
}

impl ParsedPwArgs {
    pub(crate) fn merge_relocated(&mut self, relocated: RelocatedPwFlags) {
        self.env_files.extend(relocated.env_files);
        self.arg_files.extend(relocated.arg_files);
        if relocated.output_file.is_some() {
            self.output_file = relocated.output_file;
        }
        if relocated.rustc_output_format.is_some() {
            self.rustc_output_format = relocated.rustc_output_format;
        }
        if relocated.stable_status_file.is_some() {
            self.stable_status_file = relocated.stable_status_file;
        }
        if relocated.volatile_status_file.is_some() {
            self.volatile_status_file = relocated.volatile_status_file;
        }
    }
}

fn record_pipelining_flag(arg: &str, metadata: &mut NormalizedRustcMetadata) -> bool {
    if !is_pipelining_flag(arg) {
        return false;
    }
    if arg == "--pipelining-metadata" {
        metadata.relocated.pipelining_mode = Some(SubprocessPipeliningMode::Metadata);
    } else if arg == "--pipelining-full" {
        metadata.relocated.pipelining_mode = Some(SubprocessPipeliningMode::Full);
    } else if let Some(key) = arg.strip_prefix("--pipelining-key=") {
        metadata.pipelining_key = Some(key.to_owned());
    } else if let Some(path) = arg.strip_prefix("--pipelining-rlib-path=") {
        metadata.relocated.pipelining_rlib_path = Some(path.to_owned());
    }
    true
}

fn apply_relocated_value(flag: &str, value: String, relocated: &mut RelocatedPwFlags) {
    match flag {
        "--env-file" => relocated.env_files.push(value),
        "--arg-file" => relocated.arg_files.push(value),
        "--output-file" => relocated.output_file = Some(value),
        "--rustc-output-format" => relocated.rustc_output_format = Some(value),
        "--stable-status-file" => relocated.stable_status_file = Some(value),
        "--volatile-status-file" => relocated.volatile_status_file = Some(value),
        _ => {}
    }
}

fn normalize_args_recursive(
    args: Vec<String>,
    subst_mappings: &[(String, String)],
    read_file: &mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>,
    read_error_mode: ParamFileReadErrorMode,
    write_arg: &mut dyn FnMut(String) -> Result<(), OptionError>,
    metadata: &mut NormalizedRustcMetadata,
) -> Result<(), OptionError> {
    let mut pending_flag: Option<String> = None;
    for mut arg in args {
        crate::util::apply_substitutions(&mut arg, subst_mappings);
        if let Some(flag) = pending_flag.take() {
            apply_relocated_value(&flag, arg, &mut metadata.relocated);
            continue;
        }
        if record_pipelining_flag(&arg, metadata) {
            continue;
        }
        if is_relocated_pw_flag(&arg) {
            pending_flag = Some(arg);
            continue;
        }
        if let Some(arg_file) = arg.strip_prefix('@') {
            let nested_args = match read_file(arg_file) {
                Ok(args) => args,
                Err(err) => match read_error_mode {
                    ParamFileReadErrorMode::Error => return Err(err),
                    ParamFileReadErrorMode::PreserveArg => {
                        write_arg(arg)?;
                        continue;
                    }
                },
            };
            normalize_args_recursive(
                nested_args,
                subst_mappings,
                read_file,
                read_error_mode,
                write_arg,
                metadata,
            )?;
            continue;
        }
        metadata.has_allow_features |= is_allow_features_flag(&arg);
        let resolved = resolve_external_path(&arg);
        write_arg(match resolved {
            std::borrow::Cow::Borrowed(_) => arg,
            std::borrow::Cow::Owned(s) => s,
        })?;
    }
    Ok(())
}

pub(crate) fn expand_args_inline(
    args: &[String],
    subst_mappings: &[(String, String)],
    require_explicit_unstable_features: bool,
    read_file: Option<&mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>>,
    preserve_unreadable_paramfiles: bool,
) -> Result<(Vec<String>, NormalizedRustcMetadata), OptionError> {
    let mut metadata = NormalizedRustcMetadata::default();
    let mut expanded = Vec::new();
    let mut read_file_wrapper = |s: &str| read_file_to_array(s).map_err(OptionError::Generic);
    let mut read_file = read_file.unwrap_or(&mut read_file_wrapper);
    let read_error_mode = if preserve_unreadable_paramfiles {
        ParamFileReadErrorMode::PreserveArg
    } else {
        ParamFileReadErrorMode::Error
    };
    let mut write_arg = |arg: String| {
        expanded.push(arg);
        Ok(())
    };
    normalize_args_recursive(
        args.to_vec(),
        subst_mappings,
        &mut read_file,
        read_error_mode,
        &mut write_arg,
        &mut metadata,
    )?;
    if !metadata.has_allow_features && require_explicit_unstable_features {
        expanded.push("-Zallow-features=".to_string());
    }
    Ok((expanded, metadata))
}

pub(crate) fn build_child_environment(
    env_files: &[String],
    stable_status_file: Option<&str>,
    volatile_status_file: Option<&str>,
    subst_mappings: &[(String, String)],
) -> Result<HashMap<String, String>, String> {
    let environment_file_block = env_from_files(env_files)?;
    let stable_stamp_mappings = match stable_status_file {
        Some(path) => read_stamp_status_with_context(path, "stable-status")?,
        None => Vec::new(),
    };
    let volatile_stamp_mappings = match volatile_status_file {
        Some(path) => read_stamp_status_with_context(path, "volatile-status")?,
        None => Vec::new(),
    };
    Ok(environment_block(
        environment_file_block,
        &stable_stamp_mappings,
        &volatile_stamp_mappings,
        subst_mappings,
    ))
}

/// Apply substitutions to the given param file.
/// Returns `(has_allow_features, relocated_pw_flags)`.
/// Relocated PW flags (--env-file, --output-file, etc.) are collected into
/// `RelocatedPwFlags` so the caller can apply them, rather than being silently
/// discarded.
fn prepare_param_file(
    filename: &str,
    subst_mappings: &[(String, String)],
    read_file: &mut impl FnMut(&str) -> Result<Vec<String>, OptionError>,
    write_to_file: &mut impl FnMut(&str) -> Result<(), OptionError>,
) -> Result<(bool, RelocatedPwFlags), OptionError> {
    let mut metadata = NormalizedRustcMetadata::default();
    let mut write_arg = |arg: String| write_to_file(&arg);
    normalize_args_recursive(
        read_file(filename)?,
        subst_mappings,
        read_file,
        ParamFileReadErrorMode::Error,
        &mut write_arg,
        &mut metadata,
    )?;
    Ok((metadata.has_allow_features, metadata.relocated))
}

/// Apply substitutions to the provided arguments, recursing into param files.
/// Returns `(processed_args, relocated_pw_flags)` — any process_wrapper flags
/// found inside `@paramfile`s are collected rather than discarded so the caller
/// can apply them.
#[cfg(test)]
#[allow(clippy::type_complexity)]
fn prepare_args(
    args: Vec<String>,
    subst_mappings: &[(String, String)],
    require_explicit_unstable_features: bool,
    read_file: Option<&mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>>,
    write_file: Option<&mut dyn FnMut(&str, &str) -> Result<(), OptionError>>,
) -> Result<(Vec<String>, RelocatedPwFlags), OptionError> {
    let mut temporary_expanded_paramfiles = TemporaryExpandedParamFiles::default();
    let prepared = prepare_args_internal(
        args,
        subst_mappings,
        require_explicit_unstable_features,
        read_file,
        write_file,
        &mut temporary_expanded_paramfiles,
    )?;
    let _ = temporary_expanded_paramfiles.into_inner();
    Ok(prepared)
}

#[allow(clippy::type_complexity)]
fn prepare_args_internal(
    args: Vec<String>,
    subst_mappings: &[(String, String)],
    require_explicit_unstable_features: bool,
    read_file: Option<&mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>>,
    mut write_file: Option<&mut dyn FnMut(&str, &str) -> Result<(), OptionError>>,
    temporary_expanded_paramfiles: &mut TemporaryExpandedParamFiles,
) -> Result<(Vec<String>, RelocatedPwFlags), OptionError> {
    let mut allowed_features = false;
    let mut processed_args = Vec::<String>::new();
    let mut relocated = RelocatedPwFlags::default();

    let mut read_file_wrapper = |s: &str| read_file_to_array(s).map_err(OptionError::Generic);
    let mut read_file = read_file.unwrap_or(&mut read_file_wrapper);

    for arg in args.into_iter() {
        let mut arg = arg;
        crate::util::apply_substitutions(&mut arg, subst_mappings);
        if let Some(param_file) = arg.strip_prefix('@') {
            // Write the expanded paramfile to a temp directory to avoid issues
            // with sandbox filesystems where bazel-out symlinks may prevent the
            // expanded file from being visible to the child process.
            let expanded_file = match write_file {
                Some(_) => format!("{param_file}.expanded"),
                None => {
                    let basename = std::path::Path::new(param_file)
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("params");
                    format!(
                        "{}/pw_expanded_{}_{}",
                        std::env::temp_dir().display(),
                        std::process::id(),
                        basename,
                    )
                }
            };

            enum Writer<'f, F: FnMut(&str, &str) -> Result<(), OptionError>> {
                Function(&'f mut F),
                BufWriter(io::BufWriter<File>),
            }
            let format_err = |err: io::Error| {
                OptionError::Generic(format!(
                    "{} writing path: {:?}, current directory: {:?}",
                    err,
                    expanded_file,
                    std::env::current_dir()
                ))
            };
            let mut out = match write_file {
                Some(ref mut f) => Writer::Function(f),
                None => {
                    let file = File::create(&expanded_file).map_err(format_err)?;
                    temporary_expanded_paramfiles.track(PathBuf::from(&expanded_file));
                    Writer::BufWriter(io::BufWriter::new(file))
                }
            };
            let mut write_to_file = |s: &str| -> Result<(), OptionError> {
                let s = resolve_external_path(s);
                match out {
                    Writer::Function(ref mut f) => f(&expanded_file, &s),
                    Writer::BufWriter(ref mut bw) => writeln!(bw, "{s}").map_err(format_err),
                }
            };

            // Note that substitutions may also apply to the param file path!
            let (file, (allowed, pf_relocated)) = prepare_param_file(
                param_file,
                subst_mappings,
                &mut read_file,
                &mut write_to_file,
            )
            .map(|(af, rel)| (format!("@{expanded_file}"), (af, rel)))?;
            allowed_features |= allowed;
            relocated.merge_from(pf_relocated);
            processed_args.push(file);
        } else {
            allowed_features |= is_allow_features_flag(&arg);
            let resolved = resolve_external_path(&arg);
            processed_args.push(match resolved {
                std::borrow::Cow::Borrowed(_) => arg,
                std::borrow::Cow::Owned(s) => s,
            });
        }
    }
    if !allowed_features && require_explicit_unstable_features {
        processed_args.push("-Zallow-features=".to_string());
    }
    Ok((processed_args, relocated))
}

fn environment_block(
    environment_file_block: HashMap<String, String>,
    stable_stamp_mappings: &[(String, String)],
    volatile_stamp_mappings: &[(String, String)],
    subst_mappings: &[(String, String)],
) -> HashMap<String, String> {
    // Taking all environment variables from the current process
    // and sending them down to the child process
    let mut environment_variables: HashMap<String, String> = std::env::vars().collect();
    // Have the last values added take precedence over the first.
    // This is simpler than needing to track duplicates and explicitly override
    // them.
    environment_variables.extend(environment_file_block);
    for (f, replace_with) in &[stable_stamp_mappings, volatile_stamp_mappings].concat() {
        for value in environment_variables.values_mut() {
            let from = format!("{{{f}}}");
            let new = value.replace(from.as_str(), replace_with);
            *value = new;
        }
    }
    for value in environment_variables.values_mut() {
        crate::util::apply_substitutions(value, subst_mappings);
    }
    environment_variables
}

#[cfg(test)]
#[path = "test/options.rs"]
mod test;
