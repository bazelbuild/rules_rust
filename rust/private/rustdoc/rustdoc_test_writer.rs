//! A utility for writing scripts for use as test executables intended to match the
//! subcommands of Bazel build actions so `rustdoc --test`, which builds and tests
//! code in a single call, can be run as a test target in a hermetic manner.

use std::cmp::Reverse;
use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fs;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};

#[derive(Debug)]
struct Options {
    /// A list of environment variable keys to parse from the build action env.
    env_keys: BTreeSet<String>,

    /// A list of substrings to strip from [Options::action_argv].
    strip_substrings: Vec<String>,

    /// The path where the script should be written.
    output: PathBuf,

    /// If Bazel generated a params file, we may need to strip roots from it.
    /// This is the path where we will output our stripped params file.
    optional_output_params_file: PathBuf,

    /// The `argv` of the configured rustdoc build action.
    action_argv: Vec<String>,
}

/// Parse command line arguments
fn parse_args() -> Options {
    let args: Vec<String> = env::args().collect();
    let (writer_args, action_args) = {
        let split = args
            .iter()
            .position(|arg| arg == "--")
            .expect("Unable to find split identifier `--`");

        // Converting each set into a vector makes them easier to parse in
        // the absence of nightly features
        let (writer, action) = args.split_at(split);
        (writer.to_vec(), action.to_vec())
    };

    // Remove the leading `--` which is expected to be the first
    // item in `action_args`
    debug_assert_eq!(action_args[0], "--");
    let action_argv = action_args[1..].to_vec();

    let output = writer_args
        .iter()
        .find(|arg| arg.starts_with("--output="))
        .and_then(|arg| arg.splitn(2, '=').last())
        .map(PathBuf::from)
        .expect("Missing `--output` argument");

    let optional_output_params_file = writer_args
        .iter()
        .find(|arg| arg.starts_with("--optional_test_params="))
        .and_then(|arg| arg.splitn(2, '=').last())
        .map(PathBuf::from)
        .expect("Missing `--optional_test_params` argument");

    let (strip_substring_args, writer_args): (Vec<String>, Vec<String>) = writer_args
        .into_iter()
        .partition(|arg| arg.starts_with("--strip_substring="));

    let mut strip_substrings: Vec<String> = strip_substring_args
        .into_iter()
        .map(|arg| {
            arg.splitn(2, '=')
                .last()
                .expect("--strip_substring arguments must have assignments using `=`")
                .to_owned()
        })
        .collect();

    // Strip substrings should always be in reverse order of the length of each
    // string so when filtering we know that the longer strings are checked
    // first in order to avoid cases where shorter strings might match longer ones.
    strip_substrings.sort_by_key(|b| Reverse(b.len()));
    strip_substrings.dedup();

    let env_keys = writer_args
        .into_iter()
        .filter(|arg| arg.starts_with("--action_env="))
        .map(|arg| {
            arg.splitn(2, '=')
                .last()
                .expect("--env arguments must have assignments using `=`")
                .to_owned()
        })
        .collect();

    Options {
        env_keys,
        strip_substrings,
        output,
        optional_output_params_file,
        action_argv,
    }
}

/// Expand the Bazel Arg file and write it into our manually defined params file
fn expand_params_file(mut options: Options) -> Options {
    let params_extension = if cfg!(target_family = "windows") {
        ".rustdoc_test.bat-0.params"
    } else {
        ".rustdoc_test.sh-0.params"
    };

    // We always need to produce the params file, we might overwrite this later though
    fs::write(&options.optional_output_params_file, b"unused")
        .expect("Failed to write params file");

    // extract the path for the params file, if it exists
    let params_path = match options.action_argv.pop() {
        // Found the params file!
        Some(arg) if arg.starts_with('@') && arg.ends_with(params_extension) => {
            let path_str = arg
                .strip_prefix('@')
                .expect("Checked that there is an @ prefix");
            PathBuf::from(path_str)
        }
        // No params file present, exit early
        Some(arg) => {
            options.action_argv.push(arg);
            return options;
        }
        None => return options,
    };

    // read the params file
    let params_file = fs::File::open(params_path).expect("Failed to read the rustdoc params file");
    let content: Vec<_> = BufReader::new(params_file)
        .lines()
        .map(|line| line.expect("failed to parse param as String"))
        // Remove any substrings found in the argument
        .map(|arg| {
            let mut stripped_arg = arg;
            options
                .strip_substrings
                .iter()
                .for_each(|substring| stripped_arg = stripped_arg.replace(substring, ""));
            stripped_arg
        })
        .collect();

    // add all arguments
    fs::write(&options.optional_output_params_file, content.join("\n"))
        .expect("Failed to write test runner");

    // append the path of our new params file
    let formatted_params_path = format!(
        "@{}",
        options
            .optional_output_params_file
            .to_str()
            .expect("invalid UTF-8")
    );
    options.action_argv.push(formatted_params_path);

    options
}

/// Write a unix compatible test runner
fn write_test_runner_unix(
    path: &Path,
    env: &BTreeMap<String, String>,
    argv: &[String],
    strip_substrings: &[String],
) {
    let mut content = vec![
        "#!/usr/bin/env bash".to_owned(),
        "".to_owned(),
        // TODO: Instead of creating a symlink to mimic the behavior of
        // --legacy_external_runfiles, this rule should be able to correctly
        // sanitize the action args to run in a runfiles without this link.
        "if [[ ! -e 'external' ]]; then ln -s ../ external ; fi".to_owned(),
        "".to_owned(),
        // Preserve the test invocation's paths before clearing the action env.
        // Arrays keep values with spaces and shell characters intact.
        "test_environment=()".to_owned(),
        "for name in \"${!TEST_@}\" \"${!RUNFILES_@}\"; do".to_owned(),
        "  test_environment+=(\"$name=${!name}\")".to_owned(),
        "done".to_owned(),
        "if [[ -n \"${TEST_TMPDIR:-}\" ]]; then test_environment+=(\"TMPDIR=$TEST_TMPDIR\" \"TMP=$TEST_TMPDIR\" \"TEMP=$TEST_TMPDIR\"); fi".to_owned(),
        "exec env - \\".to_owned(),
    ];

    content.extend(env.iter().map(|(key, val)| format!("{key}='{val}' \\")));
    content.push("\"${test_environment[@]}\" \\".to_owned());

    let argv_str = argv
        .iter()
        // Remove any substrings found in the argument
        .map(|arg| {
            let mut stripped_arg = arg.to_owned();
            strip_substrings
                .iter()
                .for_each(|substring| stripped_arg = stripped_arg.replace(substring, ""));
            stripped_arg
        })
        .map(|arg| format!("'{arg}'"))
        .collect::<Vec<String>>()
        .join(" ");

    content.extend(vec![argv_str, "".to_owned()]);

    fs::write(path, content.join("\n")).expect("Failed to write test runner");
}

/// Write a windows compatible test runner
fn write_test_runner_windows(
    path: &Path,
    env: &BTreeMap<String, String>,
    argv: &[String],
    strip_substrings: &[String],
) {
    // Capture invocation values before the action environment overwrites any.
    let capture = "$testEnvironment = @{}; Get-ChildItem Env: | Where-Object { $_.Name -like 'TEST_*' -or $_.Name -like 'RUNFILES_*' } | ForEach-Object { $testEnvironment[$_.Name] = $_.Value }";
    let restore = "$testEnvironment.GetEnumerator() | ForEach-Object { [Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'Process') }; if ($testEnvironment['TEST_TMPDIR']) { foreach ($name in @('TMPDIR', 'TMP', 'TEMP')) { [Environment]::SetEnvironmentVariable($name, $testEnvironment['TEST_TMPDIR'], 'Process') } }";

    let env_str = env
        .iter()
        .map(|(key, val)| format!("$env:{key}='{val}'"))
        .collect::<Vec<String>>()
        .join(" ; ");

    let argv_str = argv
        .iter()
        // Remove any substrings found in the argument
        .map(|arg| {
            let mut stripped_arg = arg.to_owned();
            strip_substrings
                .iter()
                .for_each(|substring| stripped_arg = stripped_arg.replace(substring, ""));
            stripped_arg
        })
        .map(|arg| format!("'{arg}'"))
        .collect::<Vec<String>>()
        .join(" ");

    let content = [
        "@ECHO OFF".to_owned(),
        "".to_owned(),
        // TODO: Instead of creating a symlink to mimic the behavior of
        // --legacy_external_runfiles, this rule should be able to correctly
        // sanitize the action args to run in a runfiles without this link.
        "powershell.exe -c \"if (!(Test-Path .\\external)) { New-Item -Path .\\external -ItemType SymbolicLink -Value ..\\ }\""
            .to_owned(),
        "".to_owned(),
        format!("powershell.exe -c \"{capture}; {env_str}; {restore}; & {argv_str}\""),
        "".to_owned(),
    ];

    fs::write(path, content.join("\n")).expect("Failed to write test runner");
}

#[cfg(target_family = "unix")]
fn set_executable(path: &Path) {
    use std::os::unix::prelude::PermissionsExt;

    let mut perm = fs::metadata(path)
        .expect("Failed to get test runner metadata")
        .permissions();

    perm.set_mode(0o755);
    fs::set_permissions(path, perm).expect("Failed to set permissions on test runner");
}

#[cfg(target_family = "windows")]
fn set_executable(_path: &Path) {
    // Windows determines whether or not a file is executable via the PATHEXT
    // environment variable. This function is a no-op for this platform.
}

fn write_test_runner(
    path: &Path,
    env: &BTreeMap<String, String>,
    argv: &[String],
    strip_substrings: &[String],
) {
    if cfg!(target_family = "unix") {
        write_test_runner_unix(path, env, argv, strip_substrings);
    } else if cfg!(target_family = "windows") {
        write_test_runner_windows(path, env, argv, strip_substrings);
    }

    set_executable(path);
}

fn main() {
    let opt = parse_args();
    let opt = expand_params_file(opt);

    let env: BTreeMap<String, String> = env::vars()
        .filter(|(key, _)| opt.env_keys.iter().any(|k| k == key))
        .collect();

    write_test_runner(&opt.output, &env, &opt.action_argv, &opt.strip_substrings);
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct TestDir(PathBuf);

    impl TestDir {
        fn new(name: &str) -> Self {
            static NEXT_ID: AtomicUsize = AtomicUsize::new(0);
            let temp_root = env::var_os("TEST_TMPDIR")
                .map(PathBuf::from)
                .unwrap_or_else(env::temp_dir);
            let dir = temp_root.join(format!(
                "rustdoc_writer_{}_{}_{}",
                std::process::id(),
                name,
                NEXT_ID.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&dir).unwrap();
            Self(dir)
        }

        fn path(&self) -> &Path {
            &self.0
        }
    }

    impl Drop for TestDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[cfg(target_family = "unix")] // A Unix shell executes the generated launcher.
    #[test]
    fn unix_runner_preserves_invocation_test_paths() {
        use std::process::Command;

        let dir = TestDir::new("unix");
        let path = dir.path().join("test.sh");
        let action_env = BTreeMap::from([
            ("TEST_TMPDIR".to_owned(), "action tmp".to_owned()),
            ("RUNFILES_DIR".to_owned(), "action runfiles".to_owned()),
            ("ACTION_ONLY".to_owned(), "action".to_owned()),
        ]);
        write_test_runner_unix(&path, &action_env, &["/usr/bin/env".to_owned()], &[]);

        let output = Command::new("bash")
            .arg(&path)
            .current_dir(dir.path())
            .env_clear()
            .env("PATH", "/usr/bin:/bin")
            .env("TEST_TMPDIR", "invocation tmp")
            .env("TEST_CUSTOM", "test value")
            .env("RUNFILES_DIR", "invocation runfiles")
            .env("RUNFILES_MANIFEST_FILE", "invocation manifest")
            .env("RUNFILES_MANIFEST_ONLY", "1")
            .env("UNRELATED", "discard")
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );

        let stdout = String::from_utf8(output.stdout).unwrap();
        let values: BTreeMap<_, _> = stdout
            .lines()
            .filter_map(|line| line.split_once('='))
            .collect();
        assert_eq!(values.get("TEST_TMPDIR"), Some(&"invocation tmp"));
        assert_eq!(values.get("TEST_CUSTOM"), Some(&"test value"));
        assert_eq!(values.get("RUNFILES_DIR"), Some(&"invocation runfiles"));
        assert_eq!(
            values.get("RUNFILES_MANIFEST_FILE"),
            Some(&"invocation manifest")
        );
        assert_eq!(values.get("RUNFILES_MANIFEST_ONLY"), Some(&"1"));
        assert_eq!(values.get("TMPDIR"), Some(&"invocation tmp"));
        assert_eq!(values.get("TMP"), Some(&"invocation tmp"));
        assert_eq!(values.get("TEMP"), Some(&"invocation tmp"));
        assert_eq!(values.get("ACTION_ONLY"), Some(&"action"));
        assert!(!values.contains_key("UNRELATED"));
    }

    #[test]
    fn windows_runner_restores_invocation_variables_after_action_environment() {
        let dir = TestDir::new("windows_text");
        let path = dir.path().join("test.bat");
        let action_env = BTreeMap::from([("TEST_TMPDIR".to_owned(), "action tmp".to_owned())]);
        write_test_runner_windows(&path, &action_env, &["rustdoc".to_owned()], &[]);

        let content = fs::read_to_string(&path).unwrap();
        let capture = content.find("$testEnvironment = @{}").unwrap();
        let action = content.find("$env:TEST_TMPDIR='action tmp'").unwrap();
        let restore = content.find("$testEnvironment.GetEnumerator()").unwrap();
        assert!(capture < action && action < restore);
        assert!(content.contains("'RUNFILES_*'"));
        assert!(content.contains("'TEST_*'"));
        assert!(content.contains("'TMPDIR', 'TMP', 'TEMP'"));
    }

    #[cfg(target_family = "windows")] // The generated batch file requires cmd.exe and PowerShell.
    #[test]
    fn windows_runner_preserves_invocation_test_paths() {
        use std::process::Command;

        let dir = TestDir::new("windows_runtime");
        let path = dir.path().join("test.bat");
        fs::create_dir(dir.path().join("external")).unwrap();
        let action_env = BTreeMap::from([
            ("TEST_TMPDIR".to_owned(), "action tmp".to_owned()),
            ("RUNFILES_DIR".to_owned(), "action runfiles".to_owned()),
            ("ACTION_ONLY".to_owned(), "action".to_owned()),
        ]);
        write_test_runner_windows(
            &path,
            &action_env,
            &["cmd.exe".to_owned(), "/C".to_owned(), "set".to_owned()],
            &[],
        );

        let output = Command::new("cmd.exe")
            .arg("/C")
            .arg(&path)
            .current_dir(dir.path())
            .env("TEST_TMPDIR", "invocation tmp")
            .env("TEST_CUSTOM", "test value")
            .env("RUNFILES_DIR", "invocation runfiles")
            .env("RUNFILES_MANIFEST_FILE", "invocation manifest")
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stderr)
        );

        let stdout = String::from_utf8(output.stdout).unwrap();
        let values: BTreeMap<_, _> = stdout
            .lines()
            .filter_map(|line| line.split_once('='))
            .map(|(key, value)| (key.to_ascii_uppercase(), value))
            .collect();
        assert_eq!(values.get("TEST_TMPDIR"), Some(&"invocation tmp"));
        assert_eq!(values.get("TEST_CUSTOM"), Some(&"test value"));
        assert_eq!(values.get("RUNFILES_DIR"), Some(&"invocation runfiles"));
        assert_eq!(
            values.get("RUNFILES_MANIFEST_FILE"),
            Some(&"invocation manifest")
        );
        assert_eq!(values.get("TMPDIR"), Some(&"invocation tmp"));
        assert_eq!(values.get("TMP"), Some(&"invocation tmp"));
        assert_eq!(values.get("TEMP"), Some(&"invocation tmp"));
        assert_eq!(values.get("ACTION_ONLY"), Some(&"action"));
    }
}
