use super::pipeline::{
    apply_substs, build_rustc_env, detect_pipelining_mode, expand_rustc_args, extract_rmeta_path,
    find_out_dir_in_expanded, parse_pw_args, prepare_expanded_rustc_outputs, prepare_rustc_args,
    rewrite_out_dir_in_expanded, scan_pipelining_flags, strip_pipelining_flags, BackgroundRustc,
    CancelledEntry, FullRequestAction, PipelineState, RequestKind, StoreBackgroundResult,
};
use super::protocol::{
    extract_arguments, extract_cancel, extract_inputs, extract_request_id, extract_sandbox_dir,
    WorkRequestInput,
};
use super::sandbox::resolve_request_relative_path;
#[cfg(unix)]
use super::sandbox::{
    copy_all_outputs_to_sandbox, copy_output_to_sandbox, seed_sandbox_cache_root, symlink_path,
};
use super::invocation::{InvocationDirs, RustcInvocation};
use super::types::{OutputDir, PipelineKey, RequestId};
use super::*;
use crate::options::is_pipelining_flag;
use std::path::PathBuf;
use tinyjson::JsonValue;

fn parse_json(s: &str) -> JsonValue {
    s.parse().unwrap()
}

#[test]
fn test_extract_request_id_present() {
    let req = parse_json(r#"{"requestId": 42, "arguments": []}"#);
    assert_eq!(extract_request_id(&req), RequestId(42));
}

#[test]
fn test_extract_request_id_missing() {
    let req = parse_json(r#"{"arguments": []}"#);
    assert_eq!(extract_request_id(&req), RequestId(0));
}

#[test]
fn test_extract_arguments() {
    let req =
        parse_json(r#"{"requestId": 0, "arguments": ["--subst", "pwd=/work", "--", "rustc"]}"#);
    assert_eq!(
        extract_arguments(&req),
        vec!["--subst", "pwd=/work", "--", "rustc"]
    );
}

#[test]
fn test_extract_arguments_empty() {
    let req = parse_json(r#"{"requestId": 0, "arguments": []}"#);
    assert_eq!(extract_arguments(&req), Vec::<String>::new());
}

#[test]
fn test_build_response_sanitizes_control_characters() {
    let response = build_response(1, "hello\u{0}world\u{7}", RequestId(9));
    let parsed = parse_json(&response);
    let JsonValue::Object(map) = parsed else {
        panic!("expected object response");
    };
    let Some(JsonValue::String(output)) = map.get("output") else {
        panic!("expected string output");
    };
    assert_eq!(output, "hello world ");
}

#[test]
#[cfg(unix)]
fn test_prepare_outputs_inline_out_dir() {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    let dir = std::env::temp_dir().join("pw_test_prepare_inline");
    fs::create_dir_all(&dir).unwrap();
    let file_path = dir.join("libfoo.rmeta");
    fs::write(&file_path, b"content").unwrap();

    let mut perms = fs::metadata(&file_path).unwrap().permissions();
    perms.set_mode(0o444);
    fs::set_permissions(&file_path, perms).unwrap();
    assert!(fs::metadata(&file_path).unwrap().permissions().readonly());

    let args = vec![format!("--out-dir={}", dir.display())];
    prepare_outputs(&args);

    assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
    let _ = fs::remove_dir_all(&dir);
}

#[test]
#[cfg(unix)]
fn test_prepare_outputs_arg_file() {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    let tmp = std::env::temp_dir().join("pw_test_prepare_argfile");
    fs::create_dir_all(&tmp).unwrap();

    // Create the output dir and a read-only file in it.
    let out_dir = tmp.join("out");
    fs::create_dir_all(&out_dir).unwrap();
    let file_path = out_dir.join("libfoo.rmeta");
    fs::write(&file_path, b"content").unwrap();
    let mut perms = fs::metadata(&file_path).unwrap().permissions();
    perms.set_mode(0o444);
    fs::set_permissions(&file_path, perms).unwrap();
    assert!(fs::metadata(&file_path).unwrap().permissions().readonly());

    // Write an --arg-file containing --out-dir.
    let arg_file = tmp.join("rustc.params");
    fs::write(
        &arg_file,
        format!("--out-dir={}\n--crate-name=foo\n", out_dir.display()),
    )
    .unwrap();

    let args = vec!["--arg-file".to_string(), arg_file.display().to_string()];
    prepare_outputs(&args);

    assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
    let _ = fs::remove_dir_all(&tmp);
}

#[test]
#[cfg(unix)]
fn test_prepare_outputs_sandboxed_relative_paramfile() {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    let tmp = std::env::temp_dir().join("pw_test_prepare_sandboxed_relative_paramfile");
    let sandbox_dir = tmp.join("sandbox");
    let _ = fs::remove_dir_all(&tmp);
    fs::create_dir_all(&sandbox_dir).unwrap();

    let out_dir = sandbox_dir.join("out");
    fs::create_dir_all(&out_dir).unwrap();
    let file_path = out_dir.join("libfoo.rmeta");
    fs::write(&file_path, b"content").unwrap();
    let mut perms = fs::metadata(&file_path).unwrap().permissions();
    perms.set_mode(0o444);
    fs::set_permissions(&file_path, perms).unwrap();
    assert!(fs::metadata(&file_path).unwrap().permissions().readonly());

    let paramfile = sandbox_dir.join("rustc.params");
    fs::write(&paramfile, "--out-dir=out\n--crate-name=foo\n").unwrap();

    let args = vec!["@rustc.params".to_string()];
    prepare_outputs_in_dir(&args, &sandbox_dir);

    assert!(!fs::metadata(&file_path).unwrap().permissions().readonly());
    let _ = fs::remove_dir_all(&tmp);
}

#[test]
#[cfg(unix)]
fn test_prepare_expanded_rustc_outputs_emit_path() {
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    let tmp = std::env::temp_dir().join("pw_test_prepare_emit_path");
    fs::create_dir_all(&tmp).unwrap();

    let emit_path = tmp.join("libfoo.rmeta");
    fs::write(&emit_path, b"content").unwrap();
    let mut perms = fs::metadata(&emit_path).unwrap().permissions();
    perms.set_mode(0o555);
    fs::set_permissions(&emit_path, perms).unwrap();
    assert!(fs::metadata(&emit_path).unwrap().permissions().readonly());

    let args = vec![format!("--emit=metadata={}", emit_path.display())];
    prepare_expanded_rustc_outputs(&args);

    assert!(!fs::metadata(&emit_path).unwrap().permissions().readonly());
    let _ = fs::remove_dir_all(&tmp);
}

#[test]
fn test_build_response_success() {
    let response = build_response(0, "", RequestId(0));
    assert_eq!(response, r#"{"exitCode":0,"output":"","requestId":0}"#);
    let parsed = parse_json(&response);
    if let JsonValue::Object(map) = parsed {
        assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 0.0));
        assert!(matches!(map.get("requestId"), Some(JsonValue::Number(n)) if *n == 0.0));
    } else {
        panic!("expected object");
    }
}

#[test]
fn test_build_response_failure() {
    let response = build_response(1, "error: type mismatch", RequestId(0));
    let parsed = parse_json(&response);
    if let JsonValue::Object(map) = parsed {
        assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 1.0));
        assert!(
            matches!(map.get("output"), Some(JsonValue::String(s)) if s == "error: type mismatch")
        );
    } else {
        panic!("expected object");
    }
}

#[test]
fn test_detect_pipelining_mode_none() {
    let args = vec!["--subst".to_string(), "pwd=/work".to_string()];
    assert!(matches!(
        detect_pipelining_mode(&args),
        RequestKind::NonPipelined
    ));
}

#[test]
fn test_detect_pipelining_mode_metadata() {
    let args = vec![
        "--pipelining-metadata".to_string(),
        "--pipelining-key=my_crate_abc123".to_string(),
    ];
    match detect_pipelining_mode(&args) {
        RequestKind::Metadata { key } => assert_eq!(key.as_str(), "my_crate_abc123"),
        other => panic!(
            "expected Metadata, got {:?}",
            std::mem::discriminant(&other)
        ),
    }
}

#[test]
fn test_detect_pipelining_mode_full() {
    let args = vec![
        "--pipelining-full".to_string(),
        "--pipelining-key=my_crate_abc123".to_string(),
    ];
    match detect_pipelining_mode(&args) {
        RequestKind::Full { key } => assert_eq!(key.as_str(), "my_crate_abc123"),
        other => panic!("expected Full, got {:?}", std::mem::discriminant(&other)),
    }
}

#[test]
fn test_detect_pipelining_mode_no_key() {
    // If pipelining flag present but no key, fall back to None.
    let args = vec!["--pipelining-metadata".to_string()];
    assert!(matches!(
        detect_pipelining_mode(&args),
        RequestKind::NonPipelined
    ));
}

#[test]
fn test_strip_pipelining_flags() {
    let args = vec![
        "--pipelining-metadata".to_string(),
        "--pipelining-key=my_crate_abc123".to_string(),
        "--arg-file".to_string(),
        "rustc.params".to_string(),
    ];
    let filtered = strip_pipelining_flags(&args);
    assert_eq!(filtered, vec!["--arg-file", "rustc.params"]);
}

#[test]
fn test_pipeline_state_take_for_full_empty() {
    let mut state = PipelineState::new();
    let key = PipelineKey("nonexistent".to_string());
    let _flag = state.register_full(RequestId(1), key.clone());
    assert!(matches!(
        state.claim_for_full(&key, RequestId(1)),
        FullRequestAction::Fallback
    ));
}

#[test]
fn test_request_kind_parse_in_dir_reads_relative_paramfile() {
    use std::fs;

    let dir = std::env::temp_dir().join("pw_request_kind_relative_paramfile");
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    let paramfile = dir.join("rustc.params");
    fs::write(
        &paramfile,
        "--crate-name=foo\n--pipelining-full\n--pipelining-key=foo_key\n",
    )
    .unwrap();

    let args = vec![
        "--".to_string(),
        "rustc".to_string(),
        "@rustc.params".to_string(),
    ];
    match RequestKind::parse_in_dir(&args, &dir) {
        RequestKind::Full { key } => assert_eq!(key.as_str(), "foo_key"),
        other => panic!("expected full request, got {:?}", other),
    }

    let _ = fs::remove_dir_all(&dir);
}

// --- Tests for new helpers added in the worker-key fix ---

#[test]
fn test_is_pipelining_flag() {
    assert!(is_pipelining_flag("--pipelining-metadata"));
    assert!(is_pipelining_flag("--pipelining-full"));
    assert!(is_pipelining_flag("--pipelining-key=foo_abc"));
    assert!(!is_pipelining_flag("--crate-name=foo"));
    assert!(!is_pipelining_flag("--emit=dep-info,metadata,link"));
    assert!(!is_pipelining_flag("-Zno-codegen"));
}

#[test]
fn test_apply_substs() {
    let subst = vec![
        ("pwd".to_string(), "/work".to_string()),
        ("out".to_string(), "bazel-out/k8/bin".to_string()),
    ];
    assert_eq!(apply_substs("${pwd}/src", &subst), "/work/src");
    assert_eq!(
        apply_substs("${out}/foo.rlib", &subst),
        "bazel-out/k8/bin/foo.rlib"
    );
    assert_eq!(apply_substs("--crate-name=foo", &subst), "--crate-name=foo");
}

#[test]
fn test_scan_pipelining_flags_metadata() {
    let (is_metadata, is_full, key) = scan_pipelining_flags(
        ["--pipelining-metadata", "--pipelining-key=foo_abc"]
            .iter()
            .copied(),
    );
    assert!(is_metadata);
    assert!(!is_full);
    assert_eq!(key, Some("foo_abc".to_string()));
}

#[test]
fn test_scan_pipelining_flags_full() {
    let (is_metadata, is_full, key) = scan_pipelining_flags(
        ["--pipelining-full", "--pipelining-key=bar_xyz"]
            .iter()
            .copied(),
    );
    assert!(!is_metadata);
    assert!(is_full);
    assert_eq!(key, Some("bar_xyz".to_string()));
}

#[test]
fn test_scan_pipelining_flags_none() {
    let (is_metadata, is_full, key) =
        scan_pipelining_flags(["--emit=link", "--crate-name=foo"].iter().copied());
    assert!(!is_metadata);
    assert!(!is_full);
    assert_eq!(key, None);
}

#[test]
fn test_detect_pipelining_mode_from_paramfile() {
    use std::io::Write;
    // Write a temporary paramfile with pipelining flags.
    let tmp = std::env::temp_dir().join("pw_test_detect_paramfile");
    let param_path = tmp.join("rustc.params");
    std::fs::create_dir_all(&tmp).unwrap();
    let mut f = std::fs::File::create(&param_path).unwrap();
    writeln!(f, "--emit=dep-info,metadata,link").unwrap();
    writeln!(f, "--crate-name=foo").unwrap();
    writeln!(f, "--pipelining-metadata").unwrap();
    writeln!(f, "--pipelining-key=foo_abc123").unwrap();
    drop(f);

    // Full args: startup args before "--", then rustc + @paramfile.
    let args = vec![
        "--subst".to_string(),
        "pwd=/work".to_string(),
        "--".to_string(),
        "/path/to/rustc".to_string(),
        format!("@{}", param_path.display()),
    ];

    match detect_pipelining_mode(&args) {
        RequestKind::Metadata { key } => assert_eq!(key.as_str(), "foo_abc123"),
        other => panic!(
            "expected Metadata, got {:?}",
            std::mem::discriminant(&other)
        ),
    }

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn test_detect_pipelining_mode_from_nested_paramfile() {
    let tmp = std::env::temp_dir().join("pw_test_detect_nested_paramfile");
    let outer = tmp.join("outer.params");
    let nested = tmp.join("nested.params");
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp).unwrap();
    std::fs::write(&outer, "--crate-name=foo\n@nested.params\n").unwrap();
    std::fs::write(
        &nested,
        "--pipelining-full\n--pipelining-key=foo_nested_key\n",
    )
    .unwrap();

    let args = vec![
        "--".to_string(),
        "/path/to/rustc".to_string(),
        "@outer.params".to_string(),
    ];

    match RequestKind::parse_in_dir(&args, &tmp) {
        RequestKind::Full { key } => assert_eq!(key.as_str(), "foo_nested_key"),
        other => panic!("expected Full, got {:?}", std::mem::discriminant(&other)),
    }

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn test_expand_rustc_args_strips_pipelining_flags() {
    use std::io::Write;
    let tmp = std::env::temp_dir().join("pw_test_expand_rustc");
    let param_path = tmp.join("rustc.params");
    std::fs::create_dir_all(&tmp).unwrap();
    let mut f = std::fs::File::create(&param_path).unwrap();
    writeln!(f, "--emit=dep-info,metadata,link").unwrap();
    writeln!(f, "--crate-name=foo").unwrap();
    writeln!(f, "--pipelining-metadata").unwrap();
    writeln!(f, "--pipelining-key=foo_abc123").unwrap();
    drop(f);

    let rustc_and_after = vec![
        "/path/to/rustc".to_string(),
        format!("@{}", param_path.display()),
    ];
    let subst: Vec<(String, String)> = vec![];
    let expanded = expand_rustc_args(&rustc_and_after, &subst, std::path::Path::new("."));

    assert_eq!(expanded[0], "/path/to/rustc");
    assert!(expanded.contains(&"--emit=dep-info,metadata,link".to_string()));
    assert!(expanded.contains(&"--crate-name=foo".to_string()));
    // Pipelining flags must be stripped.
    assert!(!expanded.contains(&"--pipelining-metadata".to_string()));
    assert!(!expanded.iter().any(|a| a.starts_with("--pipelining-key=")));

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn test_prepare_rustc_args_collects_nested_relocated_flags() {
    let tmp = std::env::temp_dir().join("pw_test_prepare_rustc_args_nested");
    let outer = tmp.join("outer.params");
    let nested = tmp.join("nested.params");
    let arg_file = tmp.join("build.args");
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp).unwrap();
    std::fs::write(&outer, "@nested.params\n--crate-name=foo\n").unwrap();
    std::fs::write(
        &nested,
        "\
--env-file
build.env
--arg-file
build.args
--output-file
diag.txt
--rustc-output-format
rendered
--stable-status-file
stable.txt
--volatile-status-file
volatile.txt
--out-dir=${pwd}/out
",
    )
    .unwrap();
    std::fs::write(&arg_file, "--cfg=nested_arg\n").unwrap();

    let pw_args = parse_pw_args(
        &[
            "--subst".to_string(),
            "pwd=/work".to_string(),
            "--require-explicit-unstable-features".to_string(),
            "true".to_string(),
        ],
        &tmp,
    );
    let rustc_and_after = vec!["rustc".to_string(), "@outer.params".to_string()];
    let (rustc_args, out_dir, relocated) =
        prepare_rustc_args(&rustc_and_after, &pw_args, &tmp).unwrap();

    assert_eq!(
        rustc_args,
        vec![
            "rustc".to_string(),
            "--out-dir=/work/out".to_string(),
            "--crate-name=foo".to_string(),
            "-Zallow-features=".to_string(),
            "--cfg=nested_arg".to_string(),
        ]
    );
    assert_eq!(out_dir.as_str(), "/work/out");
    assert_eq!(relocated.env_files, vec!["build.env"]);
    assert_eq!(relocated.arg_files, vec!["build.args"]);
    assert_eq!(relocated.output_file.as_deref(), Some("diag.txt"));
    assert_eq!(relocated.rustc_output_format.as_deref(), Some("rendered"));
    assert_eq!(relocated.stable_status_file.as_deref(), Some("stable.txt"));
    assert_eq!(
        relocated.volatile_status_file.as_deref(),
        Some("volatile.txt")
    );

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn test_expand_rustc_args_applies_substs() {
    use std::io::Write;
    let tmp = std::env::temp_dir().join("pw_test_expand_subst");
    let param_path = tmp.join("rustc.params");
    std::fs::create_dir_all(&tmp).unwrap();
    let mut f = std::fs::File::create(&param_path).unwrap();
    writeln!(f, "--out-dir=${{pwd}}/out").unwrap();
    drop(f);

    let rustc_and_after = vec![
        "/path/to/rustc".to_string(),
        format!("@{}", param_path.display()),
    ];
    let subst = vec![("pwd".to_string(), "/work".to_string())];
    let expanded = expand_rustc_args(&rustc_and_after, &subst, std::path::Path::new("."));

    assert!(
        expanded.contains(&"--out-dir=/work/out".to_string()),
        "expected substituted arg, got: {:?}",
        expanded
    );

    let _ = std::fs::remove_dir_all(&tmp);
}

// --- Tests for Phase 4 sandbox helpers ---

#[test]
fn test_extract_sandbox_dir_absent() {
    let req = parse_json(r#"{"requestId": 1}"#);
    assert_eq!(extract_sandbox_dir(&req), Ok(None));
}

#[test]
fn test_extract_sandbox_dir_empty_string_returns_none() {
    let req = parse_json(r#"{"requestId": 1, "sandboxDir": ""}"#);
    assert_eq!(extract_sandbox_dir(&req), Ok(None));
}

/// A nonexistent sandbox directory is an error — it means the platform
/// doesn't support sandboxing and the user should remove the flag.
#[test]
fn test_extract_sandbox_dir_nonexistent_is_err() {
    let req = parse_json(r#"{"requestId": 1, "sandboxDir": "/no/such/sandbox/dir"}"#);
    let result = extract_sandbox_dir(&req);
    assert!(result.is_err(), "expected Err for nonexistent sandbox dir");
    let msg = result.unwrap_err();
    assert!(
        msg.contains("--experimental_worker_multiplex_sandboxing"),
        "error should mention the flag: {}",
        msg
    );
}

/// An existing but empty sandbox directory is an error. On Windows, Bazel
/// creates the directory without populating it with symlinks because there
/// is no real sandbox implementation.
#[test]
#[cfg(unix)]
fn test_extract_sandbox_dir_empty_dir_is_err_unix() {
    let dir = std::env::temp_dir().join("pw_test_sandbox_empty_unix");
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let dir_str = dir.to_string_lossy().into_owned();
    let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, dir_str);
    let req = parse_json(&json);
    let result = extract_sandbox_dir(&req);
    assert!(result.is_err(), "expected Err for empty sandbox dir");
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
#[cfg(windows)]
fn test_extract_sandbox_dir_empty_dir_is_err_windows() {
    let dir = std::env::temp_dir().join("pw_test_sandbox_empty_win");
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    let dir_str = dir.to_string_lossy().into_owned();
    let escaped = dir_str.replace('\\', "\\\\");
    let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, escaped);
    let req = parse_json(&json);
    let result = extract_sandbox_dir(&req);
    assert!(result.is_err(), "expected Err for empty sandbox dir");
    let _ = std::fs::remove_dir_all(&dir);
}

/// On Unix, a populated sandbox directory is accepted.
#[test]
#[cfg(unix)]
fn test_extract_sandbox_dir_populated_unix() {
    let dir = std::env::temp_dir().join("pw_test_sandbox_pop_unix");
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("marker"), b"").unwrap();
    let dir_str = dir.to_string_lossy().into_owned();
    let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, dir_str);
    let req = parse_json(&json);
    let result = extract_sandbox_dir(&req).unwrap();
    assert_eq!(
        result.as_ref().map(|sd| sd.as_str()),
        Some(dir_str.as_str())
    );
    let _ = std::fs::remove_dir_all(&dir);
}

/// On Windows, a populated sandbox directory is accepted.
/// Backslashes in the path must be escaped in JSON.
#[test]
#[cfg(windows)]
fn test_extract_sandbox_dir_populated_windows() {
    let dir = std::env::temp_dir().join("pw_test_sandbox_pop_win");
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("marker"), b"").unwrap();
    let dir_str = dir.to_string_lossy().into_owned();
    let escaped = dir_str.replace('\\', "\\\\");
    let json = format!(r#"{{"requestId": 1, "sandboxDir": "{}"}}"#, escaped);
    let req = parse_json(&json);
    let result = extract_sandbox_dir(&req).unwrap();
    assert_eq!(
        result.as_ref().map(|sd| sd.as_str()),
        Some(dir_str.as_str())
    );
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn test_extract_inputs() {
    let req = parse_json(
        r#"{
            "requestId": 1,
            "inputs": [
                {"path": "foo/bar.rs", "digest": "abc"},
                {"path": "flagfile.params"}
            ]
        }"#,
    );
    assert_eq!(
        extract_inputs(&req),
        vec![
            WorkRequestInput {
                path: "foo/bar.rs".to_string(),
                digest: Some("abc".to_string()),
            },
            WorkRequestInput {
                path: "flagfile.params".to_string(),
                digest: None,
            },
        ]
    );
}

#[test]
fn test_extract_cancel_true() {
    let req = parse_json(r#"{"requestId": 1, "cancel": true}"#);
    assert!(extract_cancel(&req));
}

#[test]
fn test_extract_cancel_false() {
    let req = parse_json(r#"{"requestId": 1, "cancel": false}"#);
    assert!(!extract_cancel(&req));
}

#[test]
fn test_extract_cancel_absent() {
    let req = parse_json(r#"{"requestId": 1}"#);
    assert!(!extract_cancel(&req));
}

#[test]
fn test_build_cancel_response() {
    let response = build_cancel_response(RequestId(7));
    assert_eq!(
        response,
        r#"{"exitCode":0,"output":"","requestId":7,"wasCancelled":true}"#
    );
    let parsed = parse_json(&response);
    if let JsonValue::Object(map) = parsed {
        assert!(matches!(map.get("requestId"), Some(JsonValue::Number(n)) if *n == 7.0));
        assert!(matches!(map.get("exitCode"), Some(JsonValue::Number(n)) if *n == 0.0));
        assert!(matches!(
            map.get("wasCancelled"),
            Some(JsonValue::Boolean(true))
        ));
    } else {
        panic!("expected object");
    }
}

#[test]
#[cfg(unix)]
fn test_resolve_sandbox_path_relative_unix() {
    let result = resolve_request_relative_path(
        "bazel-out/k8/bin/pkg",
        Some(std::path::Path::new("/sandbox/42")),
    );
    assert_eq!(
        result,
        std::path::PathBuf::from("/sandbox/42/bazel-out/k8/bin/pkg")
    );
}

#[test]
#[cfg(windows)]
fn test_resolve_sandbox_path_relative_windows() {
    // On Windows, Path::join produces backslash separators.
    let result = resolve_request_relative_path(
        "bazel-out/k8/bin/pkg",
        Some(std::path::Path::new("/sandbox/42")),
    );
    assert_eq!(
        result,
        std::path::PathBuf::from("/sandbox/42").join("bazel-out/k8/bin/pkg")
    );
}

#[test]
fn test_resolve_sandbox_path_absolute() {
    let result = resolve_request_relative_path(
        "/absolute/path/out",
        Some(std::path::Path::new("/sandbox/42")),
    );
    assert_eq!(result, std::path::PathBuf::from("/absolute/path/out"));
}

#[test]
fn test_find_out_dir_in_expanded() {
    let args = vec![
        "--crate-name=foo".to_string(),
        "--out-dir=/work/bazel-out/k8/bin/pkg".to_string(),
        "--emit=link".to_string(),
    ];
    assert_eq!(
        find_out_dir_in_expanded(&args),
        Some("/work/bazel-out/k8/bin/pkg".to_string())
    );
}

#[test]
fn test_find_out_dir_in_expanded_missing() {
    let args = vec!["--crate-name=foo".to_string(), "--emit=link".to_string()];
    assert_eq!(find_out_dir_in_expanded(&args), None);
}

#[test]
fn test_rewrite_out_dir_in_expanded() {
    let args = vec![
        "--crate-name=foo".to_string(),
        "--out-dir=/old/path".to_string(),
        "--emit=link".to_string(),
    ];
    let new_dir = std::path::Path::new("/_pw_pipeline/foo_abc");
    let result = rewrite_out_dir_in_expanded(args, new_dir);
    assert_eq!(
        result,
        vec![
            "--crate-name=foo",
            "--out-dir=/_pw_pipeline/foo_abc",
            "--emit=link",
        ]
    );
}

#[test]
fn test_parse_pw_args_substitutes_pwd_from_real_execroot() {
    let parsed = parse_pw_args(
        &[
            "--subst".to_string(),
            "pwd=${pwd}".to_string(),
            "--output-file".to_string(),
            "diag.txt".to_string(),
        ],
        std::path::Path::new("/real/execroot"),
    );

    assert_eq!(
        parsed.subst,
        vec![("pwd".to_string(), "/real/execroot".to_string())]
    );
    assert_eq!(parsed.output_file, Some("diag.txt".to_string()));
    assert_eq!(parsed.stable_status_file, None);
    assert_eq!(parsed.volatile_status_file, None);
}

#[test]
fn test_build_rustc_env_applies_stamp_and_subst_mappings() {
    let tmp = std::env::temp_dir().join(format!("pw_test_build_rustc_env_{}", std::process::id()));
    std::fs::create_dir_all(&tmp).unwrap();

    let env_file = tmp.join("env.txt");
    let stable_status = tmp.join("stable-status.txt");
    let volatile_status = tmp.join("volatile-status.txt");

    std::fs::write(
        &env_file,
        "STAMPED={BUILD_USER}:{BUILD_SCM_REVISION}:${pwd}\nUNCHANGED=value\n",
    )
    .unwrap();
    std::fs::write(&stable_status, "BUILD_USER alice\n").unwrap();
    std::fs::write(&volatile_status, "BUILD_SCM_REVISION deadbeef\n").unwrap();

    let env = build_rustc_env(
        &[env_file.display().to_string()],
        Some(stable_status.to_str().unwrap()),
        Some(volatile_status.to_str().unwrap()),
        &[("pwd".to_string(), "/real/execroot".to_string())],
    )
    .unwrap();

    assert_eq!(
        env.get("STAMPED"),
        Some(&"alice:deadbeef:/real/execroot".to_string())
    );
    assert_eq!(env.get("UNCHANGED"), Some(&"value".to_string()));

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn test_build_shutdown_response() {
    let response = build_shutdown_response(RequestId(11));
    assert_eq!(
        response,
        r#"{"exitCode":1,"output":"worker shutting down","requestId":11}"#
    );
}

#[test]
fn test_begin_worker_shutdown_sets_flag() {
    WORKER_SHUTTING_DOWN.store(false, Ordering::SeqCst);
    begin_worker_shutdown("test");
    assert!(worker_is_shutting_down());
    WORKER_SHUTTING_DOWN.store(false, Ordering::SeqCst);
}

#[test]
fn test_extract_rmeta_path_valid() {
    let line = r#"{"artifact":"/work/out/libfoo.rmeta","emit":"metadata"}"#;
    assert_eq!(
        extract_rmeta_path(line),
        Some("/work/out/libfoo.rmeta".to_string())
    );
}

#[test]
fn test_extract_rmeta_path_rlib() {
    // rlib artifact should not match (only rmeta)
    let line = r#"{"artifact":"/work/out/libfoo.rlib","emit":"link"}"#;
    assert_eq!(extract_rmeta_path(line), None);
}

#[test]
#[cfg(unix)]
fn test_copy_output_to_sandbox() {
    use std::fs;

    let tmp = std::env::temp_dir().join("pw_test_copy_to_sandbox");
    let pipeline_dir = tmp.join("pipeline");
    let sandbox_dir = tmp.join("sandbox");
    let out_rel = "bazel-out/k8/bin/pkg";

    fs::create_dir_all(&pipeline_dir).unwrap();
    fs::create_dir_all(&sandbox_dir).unwrap();

    // Write a fake rmeta into the pipeline dir.
    let rmeta_path = pipeline_dir.join("libfoo.rmeta");
    fs::write(&rmeta_path, b"fake rmeta content").unwrap();

    copy_output_to_sandbox(
        &rmeta_path.display().to_string(),
        &sandbox_dir.display().to_string(),
        out_rel,
        "_pipeline",
    )
    .unwrap();

    let dest = sandbox_dir
        .join(out_rel)
        .join("_pipeline")
        .join("libfoo.rmeta");
    assert!(dest.exists(), "expected rmeta copied to sandbox/_pipeline/");
    assert_eq!(fs::read(&dest).unwrap(), b"fake rmeta content");

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
#[cfg(unix)]
fn test_copy_all_outputs_to_sandbox() {
    use std::fs;

    let tmp = std::env::temp_dir().join("pw_test_copy_all_to_sandbox");
    let pipeline_dir = tmp.join("pipeline");
    let sandbox_dir = tmp.join("sandbox");
    let out_rel = "bazel-out/k8/bin/pkg";

    fs::create_dir_all(&pipeline_dir).unwrap();
    fs::create_dir_all(&sandbox_dir).unwrap();

    fs::write(pipeline_dir.join("libfoo.rlib"), b"fake rlib").unwrap();
    fs::write(pipeline_dir.join("libfoo.rmeta"), b"fake rmeta").unwrap();
    fs::write(pipeline_dir.join("libfoo.d"), b"fake dep-info").unwrap();

    copy_all_outputs_to_sandbox(&pipeline_dir, &sandbox_dir.display().to_string(), out_rel)
        .unwrap();

    let dest = sandbox_dir.join(out_rel);
    assert!(dest.join("libfoo.rlib").exists());
    assert!(dest.join("libfoo.rmeta").exists());
    assert!(dest.join("libfoo.d").exists());

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
#[cfg(unix)]
fn test_copy_all_outputs_to_sandbox_prefers_hardlinks() {
    use std::fs;
    use std::os::unix::fs::MetadataExt;

    let tmp = std::env::temp_dir().join("pw_test_copy_all_outputs_to_sandbox_prefers_hardlinks");
    let pipeline_dir = tmp.join("pipeline");
    let sandbox_dir = tmp.join("sandbox");
    let out_rel = "bazel-out/k8/bin/pkg";

    fs::create_dir_all(&pipeline_dir).unwrap();
    fs::create_dir_all(&sandbox_dir).unwrap();

    let src = pipeline_dir.join("libfoo.rlib");
    fs::write(&src, b"fake rlib").unwrap();

    copy_all_outputs_to_sandbox(&pipeline_dir, &sandbox_dir.display().to_string(), out_rel)
        .unwrap();

    let dest = sandbox_dir.join(out_rel).join("libfoo.rlib");
    assert!(dest.exists());
    assert_eq!(
        fs::metadata(&src).unwrap().ino(),
        fs::metadata(&dest).unwrap().ino()
    );

    let _ = fs::remove_dir_all(&tmp);
}

#[test]
#[cfg(unix)]
fn test_seed_sandbox_cache_root() {
    use std::fs;

    let tmp = std::env::temp_dir().join("pw_test_seed_sandbox_cache_root");
    let sandbox_dir = tmp.join("sandbox");
    let cache_repo = tmp.join("cache/repos/v1/contents/hash/repo");
    fs::create_dir_all(&sandbox_dir).unwrap();
    fs::create_dir_all(cache_repo.join("tool/src")).unwrap();
    symlink_path(&cache_repo, &sandbox_dir.join("external_repo"), true).unwrap();

    seed_sandbox_cache_root(&sandbox_dir).unwrap();

    let cache_link = sandbox_dir.join("cache");
    assert!(cache_link.exists());
    assert_eq!(cache_link.canonicalize().unwrap(), tmp.join("cache"));

    let _ = fs::remove_dir_all(&tmp);
}

// --- relocate_pw_flags tests ---

#[test]
fn test_relocate_pw_flags_moves_output_file_before_separator() {
    let mut args = vec![
        "--subst".into(),
        "pwd=${pwd}".into(),
        "--".into(),
        "/path/to/rustc".into(),
        "--output-file".into(),
        "bazel-out/foo/libbar.rmeta".into(),
        "src/lib.rs".into(),
        "--crate-name=foo".into(),
    ];
    relocate_pw_flags(&mut args);
    assert_eq!(
        args,
        vec![
            "--subst",
            "pwd=${pwd}",
            "--output-file",
            "bazel-out/foo/libbar.rmeta",
            "--",
            "/path/to/rustc",
            "src/lib.rs",
            "--crate-name=foo",
        ]
    );
}

#[test]
fn test_relocate_pw_flags_moves_multiple_flags() {
    let mut args = vec![
        "--subst".into(),
        "pwd=${pwd}".into(),
        "--".into(),
        "/path/to/rustc".into(),
        "--output-file".into(),
        "out.rmeta".into(),
        "--rustc-output-format".into(),
        "rendered".into(),
        "--env-file".into(),
        "build_script.env".into(),
        "--arg-file".into(),
        "build_script.linksearchpaths".into(),
        "--stable-status-file".into(),
        "stable.status".into(),
        "--volatile-status-file".into(),
        "volatile.status".into(),
        "src/lib.rs".into(),
    ];
    relocate_pw_flags(&mut args);
    let sep = args.iter().position(|a| a == "--").unwrap();
    // All pw flags should be before --
    assert!(args[..sep].contains(&"--output-file".to_string()));
    assert!(args[..sep].contains(&"--rustc-output-format".to_string()));
    assert!(args[..sep].contains(&"--env-file".to_string()));
    assert!(args[..sep].contains(&"--arg-file".to_string()));
    assert!(args[..sep].contains(&"--stable-status-file".to_string()));
    assert!(args[..sep].contains(&"--volatile-status-file".to_string()));
    // Rustc args should be after --
    assert!(args[sep + 1..].contains(&"/path/to/rustc".to_string()));
    assert!(args[sep + 1..].contains(&"src/lib.rs".to_string()));
}

#[test]
fn test_relocate_pw_flags_noop_when_no_flags() {
    let mut args = vec![
        "--subst".into(),
        "pwd=${pwd}".into(),
        "--".into(),
        "/path/to/rustc".into(),
        "src/lib.rs".into(),
    ];
    let expected = args.clone();
    relocate_pw_flags(&mut args);
    assert_eq!(args, expected);
}

#[test]
fn test_relocate_pw_flags_noop_when_no_separator() {
    let mut args = vec!["--output-file".into(), "foo".into()];
    let expected = args.clone();
    relocate_pw_flags(&mut args);
    assert_eq!(args, expected);
}

// -------------------------------------------------------------------------
// PipelineState cancel-tracking unit tests
// -------------------------------------------------------------------------

fn make_test_bg() -> BackgroundRustc {
    use std::process::Command;
    BackgroundRustc {
        child: Command::new("sleep").arg("60").spawn().unwrap(),
        diagnostics_before: String::new(),
        stderr_drain: std::thread::spawn(|| String::new()),
        pipeline_root_dir: std::path::PathBuf::from("/tmp"),
        pipeline_output_dir: std::path::PathBuf::from("/tmp"),
        original_out_dir: OutputDir("/tmp".to_string()),
    }
}

#[test]
fn test_pipeline_state_store_and_cancel_metadata_phase() {
    let mut state = PipelineState::new();
    let key = PipelineKey("key1".to_string());
    let _flag = state.register_metadata(RequestId(42), key.clone());
    let bg = make_test_bg();
    assert!(matches!(
        state.store_metadata(&key, RequestId(42), bg),
        StoreBackgroundResult::Stored
    ));
    assert!(state.has_entry("key1"));
    assert!(state.has_request(42));

    let cancelled = state.cancel_by_request_id(RequestId(42));
    assert!(cancelled.kill(), "cancel should kill the child");
    assert!(state.is_empty(), "state should be empty after cancel");
}

#[test]
fn test_pipeline_state_take_for_full_then_cancel() {
    let mut state = PipelineState::new();
    let key = PipelineKey("key1".to_string());
    let _meta_flag = state.register_metadata(RequestId(42), key.clone());
    let bg = make_test_bg();
    assert!(matches!(
        state.store_metadata(&key, RequestId(42), bg),
        StoreBackgroundResult::Stored
    ));

    let _full_flag = state.register_full(RequestId(99), key.clone());
    let (mut taken, child_reaped) = match state.claim_for_full(&key, RequestId(99)) {
        FullRequestAction::Background(bg, child_reaped) => (bg, child_reaped),
        other => panic!(
            "expected background handoff, got {:?}",
            std::mem::discriminant(&other)
        ),
    };

    assert!(state.has_entry("key1"));
    assert!(state.has_request(99));
    assert!(!state.has_request(42));

    #[cfg(unix)]
    {
        let cancelled = state.cancel_by_request_id(RequestId(99));
        assert!(
            cancelled.kill(),
            "cancel should kill via PID for full phase"
        );
        assert!(state.is_empty(), "state should be empty after cancel");
    }

    // Verify child_reaped flag is initially false.
    assert!(!child_reaped.load(Ordering::SeqCst));

    // Reap the child to prevent zombies.
    let _ = taken.child.kill();
    let _ = taken.child.wait();
    let _ = taken.stderr_drain.join();
}

#[test]
fn test_pipeline_state_cancel_nonexistent_request() {
    let mut state = PipelineState::new();
    let cancelled = state.cancel_by_request_id(RequestId(999));
    assert!(
        !cancelled.kill(),
        "cancel should return false for unknown request_id"
    );
}

#[test]
fn test_pipeline_state_pre_register_and_cancel() {
    let mut state = PipelineState::new();
    let _flag = state.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
    assert!(state.has_request(42));
    assert!(state.has_entry("key1"));
    assert!(state.has_claim(42));

    // No process stored yet — cancel should not kill (no child).
    let cancelled = state.cancel_by_request_id(RequestId(42));
    assert!(
        !cancelled.kill(),
        "cancel should return false when no process was stored"
    );
    // Entry is cleaned up.
    assert!(!state.has_entry("key1"));
    assert!(!state.has_request(42));
}

#[test]
fn test_pipeline_state_cleanup_removes_all_entries() {
    let mut state = PipelineState::new();
    let _flag = state.register_metadata(RequestId(42), PipelineKey("key1".to_string()));
    assert!(state.has_request(42));
    assert!(state.has_claim(42));
    state.cleanup(&PipelineKey("key1".to_string()), RequestId(42));
    assert!(state.is_empty(), "state should be empty after cleanup");
    assert!(
        !state.has_claim(42),
        "claim should be removed after cleanup"
    );
}

#[test]
fn test_pipeline_state_register_claim_non_pipelined() {
    let mut state = PipelineState::new();
    let flag = state.register_non_pipelined(RequestId(42));
    assert!(state.has_claim(42));
    assert!(!state.has_entry("any_key"));
    assert!(!flag.load(Ordering::SeqCst));
    state.remove_claim(RequestId(42));
    assert!(!state.has_claim(42));
}

#[test]
fn test_pipeline_state_get_claim_flag() {
    let mut state = PipelineState::new();
    assert!(state.get_claim_flag(RequestId(42)).is_none());
    let flag = state.register_non_pipelined(RequestId(42));
    let retrieved = state
        .get_claim_flag(RequestId(42))
        .expect("should find claim flag");
    assert!(Arc::ptr_eq(&flag, &retrieved));
}

#[test]
fn test_fallback_claim_rejects_late_metadata_store() {
    let mut state = PipelineState::new();
    let key = PipelineKey("key1".to_string());
    let _full_flag = state.register_full(RequestId(99), key.clone());
    assert!(matches!(
        state.claim_for_full(&key, RequestId(99)),
        FullRequestAction::Fallback
    ));

    let _late_flag = state.register_metadata(RequestId(42), key.clone());
    let late_bg = make_test_bg();
    let rejected = match state.store_metadata(&key, RequestId(42), late_bg) {
        StoreBackgroundResult::Rejected(bg) => bg,
        _ => panic!("late metadata store should be rejected after fallback claim"),
    };

    assert!(state.has_entry("key1"));
    assert!(state.has_request(99));
    assert!(state.has_request(42));

    state.discard_request(RequestId(42));
    assert!(state.has_entry("key1"));
    assert!(!state.has_request(42));

    let mut rejected = rejected;
    let _ = rejected.child.kill();
    let _ = rejected.child.wait();
    let _ = rejected.stderr_drain.join();

    let cancelled = state.cancel_by_request_id(RequestId(99));
    assert!(!cancelled.kill());
    assert!(state.is_empty());
}

#[test]
fn test_cleanup_key_fully_removes_late_metadata_mappings() {
    let mut state = PipelineState::new();
    let key = PipelineKey("key1".to_string());
    let _flag = state.register_full(RequestId(99), key.clone());
    let _late_flag = state.register_metadata(RequestId(42), key.clone());
    assert!(matches!(
        state.claim_for_full(&key, RequestId(99)),
        FullRequestAction::Fallback
    ));
    let _ = state.cleanup_key_fully(&key);
    assert!(!state.has_entry("key1"));
    assert!(!state.has_request(42));
    assert!(!state.has_request(99));
}

/// Regression: CancelledEntry::PidOnly used raw kill(pid, SIGKILL) without
/// checking whether the child had already been reaped. If the full handler
/// already called child.wait(), the PID could be recycled and the kill
/// would hit an unrelated process.
#[test]
#[cfg(unix)]
fn test_pid_only_cancel_respects_child_reaped_flag() {
    use std::process::Command;

    // Spawn a real child so we can observe kill behavior.
    let mut child = Command::new("sleep").arg("60").spawn().unwrap();
    let pid = child.id();

    // Case 1: child_reaped=false → kill should send SIGKILL (child dies).
    let reaped = Arc::new(AtomicBool::new(false));
    let cancelled = CancelledEntry::PidOnly(pid, reaped);
    assert!(cancelled.kill());
    // Child should now be dead. Reap to confirm.
    let status = child.wait().unwrap();
    assert!(!status.success(), "child should have been killed");

    // Case 2: child_reaped=true → kill must NOT send SIGKILL.
    // Use our own PID — if SIGKILL were sent, this test process would die.
    let self_pid = std::process::id();
    let reaped = Arc::new(AtomicBool::new(true));
    let cancelled = CancelledEntry::PidOnly(self_pid, reaped);
    assert!(cancelled.kill());
    // If we're still running, the guard worked.
}

/// Regression: build_response blanked output for exit_code==0, silently
/// discarding rustc warnings from successful compilations.
#[test]
fn test_build_response_preserves_warnings_on_success() {
    let warning = "warning: unused variable `x`";
    let response = build_response(0, warning, RequestId(42));
    let parsed = parse_json(&response);
    let JsonValue::Object(map) = parsed else {
        panic!("expected object response");
    };
    let Some(JsonValue::String(output)) = map.get("output") else {
        panic!("expected string output");
    };
    assert_eq!(
        output, warning,
        "build_response should preserve warnings on success (exit_code=0)"
    );
}

// ---------------------------------------------------------------------------
// RustcInvocation tests
// ---------------------------------------------------------------------------

#[test]
fn test_invocation_pending_to_running() {
    let inv = RustcInvocation::new();
    assert!(inv.is_pending());
}

#[test]
fn test_invocation_completed_via_transition() {
    let inv = RustcInvocation::new();
    inv.transition_to_completed(
        0,
        "all good".to_string(),
        InvocationDirs {
            pipeline_output_dir: PathBuf::from("/tmp/out"),
            pipeline_root_dir: PathBuf::from("/tmp/root"),
            original_out_dir: OutputDir::default(),
        },
    );
    let result = inv.wait_for_completion();
    assert!(result.is_ok());
    let completion = result.unwrap();
    assert_eq!(completion.exit_code, 0);
    assert_eq!(completion.diagnostics, "all good");
}

#[test]
fn test_invocation_shutdown_from_pending() {
    let inv = RustcInvocation::new();
    inv.request_shutdown();
    assert!(inv.is_shutting_down_or_terminal());
}
