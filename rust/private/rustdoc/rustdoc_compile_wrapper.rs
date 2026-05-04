use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::io::{self, BufRead, Read, Write};
use std::process::{exit, Command, Stdio};
use std::thread;

struct WrapperArgs {
    test_metadata_path: Option<String>,
    child_args: Vec<String>,
}

fn parse_wrapper_args() -> WrapperArgs {
    let mut test_metadata_path: Option<String> = None;
    let mut child_args: Vec<String> = Vec::new();
    let mut past_separator = false;

    let mut args_iter = env::args().skip(1);
    while let Some(arg) = args_iter.next() {
        if past_separator {
            child_args.push(arg);
        } else if arg == "--" {
            past_separator = true;
        } else if arg == "--test-metadata" {
            test_metadata_path = args_iter.next();
        } else {
            eprintln!("Unknown wrapper flag: {}", arg);
            exit(1);
        }
    }

    WrapperArgs {
        test_metadata_path,
        child_args,
    }
}

fn parse_test_names(stdout: &str) -> Vec<String> {
    stdout
        .lines()
        .filter_map(|line| {
            let rest = line.strip_prefix("test ")?;
            let name = rest.rsplit_once(" ... ")?.0;
            Some(name.to_string())
        })
        .collect()
}

fn mangle_test_name(human_name: &str) -> String {
    if let Some((file_and_item, line_part)) = human_name.rsplit_once(" (line ") {
        if let Some(line_num) = line_part.strip_suffix(')') {
            if let Some((file_path, _)) = file_and_item.split_once(" - ") {
                let mangled: String = file_path
                    .chars()
                    .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
                    .collect();
                return format!("{}_{}_0", mangled, line_num);
            }
        }
    }
    human_name
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '_' })
        .collect()
}

fn write_test_metadata(path: &str, stdout: &str) {
    let names = parse_test_names(stdout);
    let entries: BTreeSet<(String, &str)> = names
        .iter()
        .map(|name| (mangle_test_name(name), name.as_str()))
        .collect();

    let mut content = String::new();
    for (mangled, human) in &entries {
        content.push_str(mangled);
        content.push('=');
        content.push_str(human);
        content.push('\n');
    }
    let _ = fs::write(path, content);
}

fn main() {
    let debug = env::var_os("RULES_RUST_RUSTDOC_DEBUG").is_some();
    let args = parse_wrapper_args();

    if args.child_args.is_empty() {
        eprintln!("Usage: rustdoc_compile_wrapper [--test-metadata FILE] -- <command> [args...]");
        exit(1);
    }

    let mut child = Command::new(&args.child_args[0])
        .args(&args.child_args[1..])
        .stdout(if debug {
            Stdio::inherit()
        } else {
            Stdio::piped()
        })
        .stderr(Stdio::piped())
        .spawn()
        .unwrap_or_else(|e| {
            eprintln!("Failed to spawn {}: {}", args.child_args[0], e);
            exit(1);
        });

    let child_stdout = child.stdout.take();
    let child_stderr = child.stderr.take().unwrap();

    let stdout_handle = thread::spawn(move || {
        let mut buf = Vec::new();
        if let Some(mut reader) = child_stdout {
            let _ = reader.read_to_end(&mut buf);
        }
        buf
    });

    let stderr_handle = thread::spawn(move || {
        let reader = io::BufReader::new(child_stderr);
        let mut stderr = io::stderr().lock();
        let mut has_warning = false;
        for line in reader.split(b'\n') {
            let line = match line {
                Ok(l) => l,
                Err(_) => break,
            };
            if !has_warning && line_has_warning(&line) {
                has_warning = true;
            }
            let _ = stderr.write_all(&line);
            let _ = stderr.write_all(b"\n");
        }
        has_warning
    });

    let stdout_buf = stdout_handle.join().unwrap_or_default();
    let has_warning = stderr_handle.join().unwrap_or(false);

    let status = child.wait().unwrap_or_else(|e| {
        eprintln!("Failed to wait for child process: {}", e);
        exit(1);
    });

    if let Some(ref path) = args.test_metadata_path {
        let stdout_str = String::from_utf8_lossy(&stdout_buf);
        write_test_metadata(path, &stdout_str);
    }

    let code = status.code().unwrap_or(1);
    if !debug && (code != 0 || has_warning) && !stdout_buf.is_empty() {
        let _ = io::stderr().write_all(&stdout_buf);
    }

    exit(code);
}

fn line_has_warning(line: &[u8]) -> bool {
    contains_subslice(line, b"warning:")
}

fn contains_subslice(haystack: &[u8], needle: &[u8]) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}
