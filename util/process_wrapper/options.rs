use std::collections::HashMap;
use std::env;
use std::fs::{self, File};
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::exit;

use crate::flags::{Flags, ParseOutcome};
use crate::rustc;
use crate::util::*;

// Re-export shared types and functions from pw_args so that existing
// `crate::options::Foo` imports continue to work throughout the codebase.
pub(crate) use crate::pw_args::{
    build_child_environment, expand_args_inline, is_allow_features_flag, is_pipelining_flag,
    is_relocated_pw_flag, normalize_args_recursive, parse_pw_args, resolve_external_path,
    NormalizedRustcMetadata, OptionError, ParamFileReadErrorMode, ParsedPwArgs, RelocatedPwFlags,
    SubprocessPipeliningMode,
};

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

#[cfg(test)]
#[path = "test/options.rs"]
mod test;
