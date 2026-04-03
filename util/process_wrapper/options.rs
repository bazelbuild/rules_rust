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
    // If set, it configures rustc to emit an rmeta file and then
    // quit.
    pub(crate) rustc_quit_on_rmeta: bool,
    // This controls the output format of rustc messages.
    pub(crate) rustc_output_format: Option<rustc::ErrorFormat>,
    // If set to (seed_dir, dest_dir), copies the seed directory contents into
    // dest_dir before spawning the child process.  Used to seed the incremental
    // compilation tree artifact from the previous build's state.
    pub(crate) copy_seed: Option<(String, String)>,
    // If set to (file_path, input_path), writes input_path to file_path after
    // the child process completes successfully.  Used to populate the
    // unused_inputs_list file so Bazel excludes the seed from cache keys.
    pub(crate) write_unused_inputs: Option<(String, String)>,
    // If set to (prev_dir, dest_dir), reads directly from prev_dir (which is
    // outside the sandbox) and hardlinks/copies into dest_dir.
    pub(crate) seed_prev_dir: Option<(String, String)>,
    // Minimum incremental cache size (in MiB) to seed from the previous build.
    pub(crate) seed_min_mb: u64,
    // If true, exit with 0 after pre-exec operations without spawning a child.
    pub(crate) exit_early: bool,
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
    let mut rustc_quit_on_rmeta_raw = None;
    let mut rustc_output_format_raw = None;
    let mut copy_seed_raw = None;
    let mut write_unused_inputs_raw = None;
    let mut seed_prev_dir_raw = None;
    let mut seed_min_mb_raw = None;
    let mut exit_early_raw = None;
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
        "--rustc-quit-on-rmeta",
        "If enabled, this wrapper will terminate rustc after rmeta has been emitted.",
        &mut rustc_quit_on_rmeta_raw,
    );
    flags.define_flag(
        "--rustc-output-format",
        "Controls the rustc output format if --rustc-quit-on-rmeta is set.\n\
        'json' will cause the json output to be output, \
        'rendered' will extract the rendered message and print that.\n\
        Default: `rendered`",
        &mut rustc_output_format_raw,
    );
    flags.define_flag(
        "--require-explicit-unstable-features",
        "If set, an empty -Zallow-features= will be added to the rustc command line whenever no \
         other -Zallow-features= is present in the rustc flags.",
        &mut require_explicit_unstable_features,
    );
    flags.define_repeated_flag(
        "--copy-seed",
        "Copy a seed directory into the output directory before spawning \
         the child process. Takes two values: <seed_dir> <dest_dir>. Used \
         to seed the incremental compilation tree artifact from the previous build.",
        &mut copy_seed_raw,
    );
    flags.define_repeated_flag(
        "--write-unused-inputs",
        "Write an input path to a file after the child process succeeds. \
         Takes two values: <file_path> <input_path>. Used to populate the \
         unused_inputs_list so Bazel excludes the seed from cache keys.",
        &mut write_unused_inputs_raw,
    );
    flags.define_repeated_flag(
        "--seed-prev-dir",
        "Read incremental cache directly from a previous build's output \
         directory and hardlink/copy into the output directory. \
         Takes two values: <prev_dir> <dest_dir>.",
        &mut seed_prev_dir_raw,
    );
    flags.define_flag(
        "--seed-min-mb",
        "Minimum incremental cache size (in MiB) to seed from. \
         Caches below this threshold are skipped. Default: 20.",
        &mut seed_min_mb_raw,
    );
    flags.define_flag(
        "--exit-early",
        "Exit with 0 after pre-exec operations (seed, etc.) \
         without spawning a child process.",
        &mut exit_early_raw,
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
    let stable_stamp_mappings =
        stable_status_file_raw.map_or_else(Vec::new, |s| read_stamp_status_to_array(s).unwrap());
    let volatile_stamp_mappings =
        volatile_status_file_raw.map_or_else(Vec::new, |s| read_stamp_status_to_array(s).unwrap());
    let environment_file_block = env_from_files(env_file_raw.unwrap_or_default())?;
    let mut file_arguments = args_from_file(arg_file_raw.unwrap_or_default())?;
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

    let rustc_quit_on_rmeta = rustc_quit_on_rmeta_raw.is_some_and(|s| s == "true");
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

    let require_explicit_unstable_features =
        require_explicit_unstable_features.is_some_and(|s| s == "true");

    let seed_min_mb = seed_min_mb_raw
        .map(|s| {
            s.parse::<u64>().map_err(|e| {
                OptionError::Generic(format!("invalid --seed-min-mb value '{s}': {e}"))
            })
        })
        .transpose()?
        .unwrap_or(20);
    let exit_early = exit_early_raw.is_some_and(|s| s == "true");

    // Append all the arguments fetched from files to those provided via command line.
    child_args.append(&mut file_arguments);
    let child_args = prepare_args(
        child_args,
        &subst_mappings,
        require_explicit_unstable_features,
        None,
        None,
    )?;

    // Split the executable path from the rest of the arguments.
    // When --exit-early is set, no child process is needed.
    let (exec_path, args) = if exit_early && child_args.is_empty() {
        (String::new(), Vec::new())
    } else {
        let (e, a) = child_args.split_first().ok_or_else(|| {
            OptionError::Generic(
                "at least one argument after -- is required (the child process path)".to_owned(),
            )
        })?;
        (e.to_owned(), a.to_vec())
    };

    // Process --copy-seed
    let copy_seed = copy_seed_raw
        .map(|cs| {
            if cs.len() != 2 {
                return Err(OptionError::Generic(format!(
                    "\"--copy-seed\" needs exactly 2 parameters, {} provided",
                    cs.len()
                )));
            }
            Ok((cs[0].to_owned(), cs[1].to_owned()))
        })
        .transpose()?;

    // Process --write-unused-inputs
    let write_unused_inputs = write_unused_inputs_raw
        .map(|wu| {
            if wu.len() != 2 {
                return Err(OptionError::Generic(format!(
                    "\"--write-unused-inputs\" needs exactly 2 parameters, {} provided",
                    wu.len()
                )));
            }
            Ok((wu[0].to_owned(), wu[1].to_owned()))
        })
        .transpose()?;

    // Process --seed-prev-dir
    let seed_prev_dir = seed_prev_dir_raw
        .map(|sp| {
            if sp.len() != 2 {
                return Err(OptionError::Generic(format!(
                    "\"--seed-prev-dir\" needs exactly 2 parameters, {} provided",
                    sp.len()
                )));
            }
            Ok((sp[0].to_owned(), sp[1].to_owned()))
        })
        .transpose()?;

    Ok(Options {
        executable: exec_path,
        child_arguments: args,
        child_environment: vars,
        touch_file,
        copy_output,
        stdout_file,
        stderr_file,
        output_file,
        rustc_quit_on_rmeta,
        rustc_output_format,
        copy_seed,
        write_unused_inputs,
        seed_prev_dir,
        seed_min_mb,
        exit_early,
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

fn prepare_arg(mut arg: String, subst_mappings: &[(String, String)]) -> String {
    for (f, replace_with) in subst_mappings {
        let from = format!("${{{f}}}");
        arg = arg.replace(&from, replace_with);
    }
    arg
}

/// Apply substitutions to the given param file. Returns true iff any allow-features flags were found.
fn prepare_param_file(
    filename: &str,
    subst_mappings: &[(String, String)],
    read_file: &mut impl FnMut(&str) -> Result<Vec<String>, OptionError>,
    write_to_file: &mut impl FnMut(&str) -> Result<(), OptionError>,
) -> Result<bool, OptionError> {
    fn process_file(
        filename: &str,
        subst_mappings: &[(String, String)],
        read_file: &mut impl FnMut(&str) -> Result<Vec<String>, OptionError>,
        write_to_file: &mut impl FnMut(&str) -> Result<(), OptionError>,
    ) -> Result<bool, OptionError> {
        let mut has_allow_features_flag = false;
        for arg in read_file(filename)? {
            let arg = prepare_arg(arg, subst_mappings);
            has_allow_features_flag |= is_allow_features_flag(&arg);
            if let Some(arg_file) = arg.strip_prefix('@') {
                has_allow_features_flag |=
                    process_file(arg_file, subst_mappings, read_file, write_to_file)?;
            } else {
                write_to_file(&arg)?;
            }
        }
        Ok(has_allow_features_flag)
    }
    let has_allow_features_flag = process_file(filename, subst_mappings, read_file, write_to_file)?;
    Ok(has_allow_features_flag)
}

/// Apply substitutions to the provided arguments, recursing into param files.
#[allow(clippy::type_complexity)]
fn prepare_args(
    args: Vec<String>,
    subst_mappings: &[(String, String)],
    require_explicit_unstable_features: bool,
    read_file: Option<&mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>>,
    mut write_file: Option<&mut dyn FnMut(&str, &str) -> Result<(), OptionError>>,
) -> Result<Vec<String>, OptionError> {
    let mut allowed_features = false;
    let mut processed_args = Vec::<String>::new();

    let mut read_file_wrapper = |s: &str| read_file_to_array(s).map_err(OptionError::Generic);
    let mut read_file = read_file.unwrap_or(&mut read_file_wrapper);

    for arg in args.into_iter() {
        let arg = prepare_arg(arg, subst_mappings);
        if let Some(param_file) = arg.strip_prefix('@') {
            let expanded_file = format!("{param_file}.expanded");
            let format_err = |err: io::Error| {
                OptionError::Generic(format!(
                    "{} writing path: {:?}, current directory: {:?}",
                    err,
                    expanded_file,
                    std::env::current_dir()
                ))
            };

            enum Writer<'f, F: FnMut(&str, &str) -> Result<(), OptionError>> {
                Function(&'f mut F),
                BufWriter(io::BufWriter<File>),
            }
            let mut out = match write_file {
                Some(ref mut f) => Writer::Function(f),
                None => Writer::BufWriter(io::BufWriter::new(
                    File::create(&expanded_file).map_err(format_err)?,
                )),
            };
            let mut write_to_file = |s: &str| -> Result<(), OptionError> {
                match out {
                    Writer::Function(ref mut f) => f(&expanded_file, s),
                    Writer::BufWriter(ref mut bw) => writeln!(bw, "{s}").map_err(format_err),
                }
            };

            // Note that substitutions may also apply to the param file path!
            let (file, allowed) = prepare_param_file(
                param_file,
                subst_mappings,
                &mut read_file,
                &mut write_to_file,
            )
            .map(|af| (format!("@{expanded_file}"), af))?;
            allowed_features |= allowed;
            processed_args.push(file);
        } else {
            allowed_features |= is_allow_features_flag(&arg);
            processed_args.push(arg);
        }
    }
    if !allowed_features && require_explicit_unstable_features {
        processed_args.push("-Zallow-features=".to_string());
    }
    Ok(processed_args)
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
    for (f, replace_with) in subst_mappings {
        for value in environment_variables.values_mut() {
            let from = format!("${{{f}}}");
            let new = value.replace(from.as_str(), replace_with);
            *value = new;
        }
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
        let args = prepare_args(args, &subst_mappings, true, None, None).unwrap();
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
        let args = prepare_args(args, &subst_mappings, true, None, None).unwrap();
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

        let args = prepare_args(
            args,
            &subst_mappings,
            true,
            Some(&mut read_file),
            Some(&mut write_file),
        );

        assert_eq!(
            args.unwrap(),
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
}
