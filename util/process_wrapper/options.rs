use std::collections::HashMap;
use std::env;
use std::fmt;
use std::fs::File;
use std::io::{self, Write};
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

pub(crate) fn options() -> Result<Options, OptionError> {
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

    let mut child_args = match flags
        .parse(env::args().collect())
        .map_err(OptionError::FlagError)?
    {
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
    let (child_args, relocated) = prepare_args(
        child_args,
        &subst_mappings,
        require_explicit_unstable_features,
        None,
        None,
    )?;

    // Merge relocated env-files from @paramfile with those from startup args.
    let mut env_files = env_file_raw.unwrap_or_default();
    env_files.extend(relocated.env_files);
    let environment_file_block = env_from_files(env_files)?;

    // Merge relocated arg-files: append their contents to child_args,
    // applying ${pwd} and other substitutions to each line (matching the
    // worker path which calls apply_substs on every arg-file line).
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
    let stable_stamp_mappings =
        stable_status_file.map_or_else(Vec::new, |s| read_stamp_status_to_array(s).unwrap());
    let volatile_stamp_mappings =
        volatile_status_file.map_or_else(Vec::new, |s| read_stamp_status_to_array(s).unwrap());

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
    let vars = environment_block(
        environment_file_block,
        &stable_stamp_mappings,
        &volatile_stamp_mappings,
        &subst_mappings,
    );

    // Split the executable path from the rest of the arguments.
    let (exec_path, args) = child_args.split_first().ok_or_else(|| {
        OptionError::Generic(
            "at least one argument after -- is required (the child process path)".to_owned(),
        )
    })?;

    Ok(Options {
        executable: exec_path.to_owned(),
        child_arguments: args.to_vec(),
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

fn env_from_files(paths: Vec<String>) -> Result<HashMap<String, String>, OptionError> {
    let mut env_vars = HashMap::new();
    for path in paths.into_iter() {
        let lines = read_file_to_array(&path).map_err(OptionError::Generic)?;
        for line in lines.into_iter() {
            let (k, v) = line
                .split_once('=')
                .ok_or_else(|| OptionError::Generic("environment file invalid".to_owned()))?;
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

#[derive(Default, Debug)]
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
    fn process_file(
        filename: &str,
        subst_mappings: &[(String, String)],
        read_file: &mut impl FnMut(&str) -> Result<Vec<String>, OptionError>,
        write_to_file: &mut impl FnMut(&str) -> Result<(), OptionError>,
        relocated: &mut RelocatedPwFlags,
    ) -> Result<bool, OptionError> {
        let mut has_allow_features_flag = false;
        // When set, the next arg is the value of this relocated pw flag.
        let mut pending_flag: Option<String> = None;
        for arg in read_file(filename)? {
            if let Some(flag) = pending_flag.take() {
                let mut value = arg;
                crate::util::apply_substitutions(&mut value, subst_mappings);
                match flag.as_str() {
                    "--env-file" => relocated.env_files.push(value),
                    "--arg-file" => relocated.arg_files.push(value),
                    "--output-file" => relocated.output_file = Some(value),
                    "--rustc-output-format" => relocated.rustc_output_format = Some(value),
                    "--stable-status-file" => relocated.stable_status_file = Some(value),
                    "--volatile-status-file" => relocated.volatile_status_file = Some(value),
                    _ => {}
                }
                continue;
            }
            let mut arg = arg;
            crate::util::apply_substitutions(&mut arg, subst_mappings);
            // Strip worker-pipelining protocol flags; they must not reach rustc.
            // Collect mode and rlib-path so the local-mode no-op optimization
            // can detect when the full action's .rlib already exists.
            if is_pipelining_flag(&arg) {
                if arg == "--pipelining-metadata" {
                    relocated.pipelining_mode = Some(SubprocessPipeliningMode::Metadata);
                } else if arg == "--pipelining-full" {
                    relocated.pipelining_mode = Some(SubprocessPipeliningMode::Full);
                } else if let Some(path) = arg.strip_prefix("--pipelining-rlib-path=") {
                    relocated.pipelining_rlib_path = Some(path.to_string());
                }
                continue;
            }
            // Collect relocated process_wrapper flags (--output-file, etc.) that
            // were placed in the paramfile for worker key stability.  These are
            // two-part flags: the flag name on one line, its value on the next.
            if is_relocated_pw_flag(&arg) {
                pending_flag = Some(arg);
                continue;
            }
            has_allow_features_flag |= is_allow_features_flag(&arg);
            if let Some(arg_file) = arg.strip_prefix('@') {
                has_allow_features_flag |= process_file(
                    arg_file,
                    subst_mappings,
                    read_file,
                    write_to_file,
                    relocated,
                )?;
            } else {
                write_to_file(&arg)?;
            }
        }
        Ok(has_allow_features_flag)
    }
    let mut relocated = RelocatedPwFlags::default();
    let has_allow_features_flag = process_file(
        filename,
        subst_mappings,
        read_file,
        write_to_file,
        &mut relocated,
    )?;
    Ok((has_allow_features_flag, relocated))
}

/// Apply substitutions to the provided arguments, recursing into param files.
/// Returns `(processed_args, relocated_pw_flags)` — any process_wrapper flags
/// found inside `@paramfile`s are collected rather than discarded so the caller
/// can apply them.
#[allow(clippy::type_complexity)]
fn prepare_args(
    args: Vec<String>,
    subst_mappings: &[(String, String)],
    require_explicit_unstable_features: bool,
    read_file: Option<&mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>>,
    mut write_file: Option<&mut dyn FnMut(&str, &str) -> Result<(), OptionError>>,
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
                None => Writer::BufWriter(io::BufWriter::new(
                    File::create(&expanded_file).map_err(format_err)?,
                )),
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
            // Merge relocated flags from this paramfile.
            relocated.env_files.extend(pf_relocated.env_files);
            relocated.arg_files.extend(pf_relocated.arg_files);
            if pf_relocated.output_file.is_some() {
                relocated.output_file = pf_relocated.output_file;
            }
            if pf_relocated.rustc_output_format.is_some() {
                relocated.rustc_output_format = pf_relocated.rustc_output_format;
            }
            if pf_relocated.stable_status_file.is_some() {
                relocated.stable_status_file = pf_relocated.stable_status_file;
            }
            if pf_relocated.volatile_status_file.is_some() {
                relocated.volatile_status_file = pf_relocated.volatile_status_file;
            }
            if pf_relocated.pipelining_mode.is_some() {
                relocated.pipelining_mode = pf_relocated.pipelining_mode;
            }
            if pf_relocated.pipelining_rlib_path.is_some() {
                relocated.pipelining_rlib_path = pf_relocated.pipelining_rlib_path;
            }
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
mod test {
    use super::*;

    #[test]
    fn test_enforce_allow_features_flag_user_didnt_say() {
        let args = vec!["rustc".to_string()];
        let subst_mappings: Vec<(String, String)> = vec![];
        let (args, _) = prepare_args(args, &subst_mappings, true, None, None).unwrap();
        assert_eq!(
            args,
            vec!["rustc".to_string(), "-Zallow-features=".to_string(),]
        );
    }

    #[test]
    fn test_enforce_allow_features_flag_user_requested_something() {
        let args = vec![
            "rustc".to_string(),
            "-Zallow-features=whitespace_instead_of_curly_braces".to_string(),
        ];
        let subst_mappings: Vec<(String, String)> = vec![];
        let (args, _) = prepare_args(args, &subst_mappings, true, None, None).unwrap();
        assert_eq!(
            args,
            vec![
                "rustc".to_string(),
                "-Zallow-features=whitespace_instead_of_curly_braces".to_string(),
            ]
        );
    }

    #[test]
    fn test_enforce_allow_features_flag_user_requested_something_in_param_file() {
        let mut written_files = HashMap::<String, String>::new();
        let mut read_files = HashMap::<String, Vec<String>>::new();
        read_files.insert(
            "rustc_params".to_string(),
            vec!["-Zallow-features=whitespace_instead_of_curly_braces".to_string()],
        );

        let mut read_file = |filename: &str| -> Result<Vec<String>, OptionError> {
            read_files
                .get(filename)
                .cloned()
                .ok_or_else(|| OptionError::Generic(format!("file not found: {}", filename)))
        };
        let mut write_file = |filename: &str, content: &str| -> Result<(), OptionError> {
            if let Some(v) = written_files.get_mut(filename) {
                v.push_str(content);
            } else {
                written_files.insert(filename.to_owned(), content.to_owned());
            }
            Ok(())
        };

        let args = vec!["rustc".to_string(), "@rustc_params".to_string()];
        let subst_mappings: Vec<(String, String)> = vec![];

        let (args, _) = prepare_args(
            args,
            &subst_mappings,
            true,
            Some(&mut read_file),
            Some(&mut write_file),
        )
        .unwrap();

        assert_eq!(
            args,
            vec!["rustc".to_string(), "@rustc_params.expanded".to_string(),]
        );

        assert_eq!(
            written_files,
            HashMap::<String, String>::from([(
                "rustc_params.expanded".to_string(),
                "-Zallow-features=whitespace_instead_of_curly_braces".to_string()
            )])
        );
    }

    #[test]
    fn test_prepare_param_file_strips_and_collects_relocated_pw_flags() {
        let mut written = String::new();
        let mut read_file = |_filename: &str| -> Result<Vec<String>, OptionError> {
            Ok(vec![
                "--output-file".to_string(),
                "bazel-out/foo/libbar.rmeta".to_string(),
                "--env-file".to_string(),
                "bazel-out/foo/build_script.env".to_string(),
                "src/lib.rs".to_string(),
                "--crate-name=foo".to_string(),
                "--arg-file".to_string(),
                "bazel-out/foo/build_script.linksearchpaths".to_string(),
                "--rustc-output-format".to_string(),
                "rendered".to_string(),
                "--stable-status-file".to_string(),
                "bazel-out/stable-status.txt".to_string(),
                "--volatile-status-file".to_string(),
                "bazel-out/volatile-status.txt".to_string(),
                "--crate-type=rlib".to_string(),
            ])
        };
        let mut write_to_file = |s: &str| -> Result<(), OptionError> {
            if !written.is_empty() {
                written.push('\n');
            }
            written.push_str(s);
            Ok(())
        };

        let (_, relocated) =
            prepare_param_file("test.params", &[], &mut read_file, &mut write_to_file).unwrap();

        // All relocated pw flags + values should be stripped from output.
        // Only the rustc flags should remain.
        assert_eq!(written, "src/lib.rs\n--crate-name=foo\n--crate-type=rlib");

        // Verify collected relocated flags.
        assert_eq!(
            relocated.output_file.as_deref(),
            Some("bazel-out/foo/libbar.rmeta")
        );
        assert_eq!(relocated.env_files, vec!["bazel-out/foo/build_script.env"]);
        assert_eq!(
            relocated.arg_files,
            vec!["bazel-out/foo/build_script.linksearchpaths"]
        );
        assert_eq!(relocated.rustc_output_format.as_deref(), Some("rendered"));
        assert_eq!(
            relocated.stable_status_file.as_deref(),
            Some("bazel-out/stable-status.txt")
        );
        assert_eq!(
            relocated.volatile_status_file.as_deref(),
            Some("bazel-out/volatile-status.txt")
        );
    }

    #[test]
    fn resolve_external_path_non_rs_unchanged() {
        let arg = "external/some_repo/src/lib.txt";
        let result = resolve_external_path(arg);
        assert_eq!(&*result, arg);
    }

    #[test]
    fn resolve_external_path_non_external_unchanged() {
        let arg = "src/main.rs";
        let result = resolve_external_path(arg);
        assert_eq!(&*result, arg);
    }

    #[test]
    fn resolve_external_path_no_junction_unchanged() {
        // When the junction doesn't exist (read_link fails), returns unchanged.
        let arg = "external/nonexistent_repo_12345/src/lib.rs";
        let result = resolve_external_path(arg);
        assert_eq!(&*result, arg);
    }
}
