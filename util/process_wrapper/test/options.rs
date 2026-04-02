use super::*;

#[allow(clippy::type_complexity)]
fn prepare_args(
    args: Vec<String>,
    subst_mappings: &[(String, String)],
    require_explicit_unstable_features: bool,
    read_file: Option<&mut dyn FnMut(&str) -> Result<Vec<String>, OptionError>>,
    write_file: Option<&mut dyn FnMut(&str, &str) -> Result<(), OptionError>>,
) -> Result<(Vec<String>, RelocatedPwFlags), OptionError> {
    let mut tmp = TemporaryExpandedParamFiles::default();
    let prepared = prepare_args_internal(
        args,
        subst_mappings,
        require_explicit_unstable_features,
        read_file,
        write_file,
        &mut tmp,
    )?;
    let _ = tmp.into_inner();
    Ok(prepared)
}

fn unique_test_dir(prefix: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "{}_{}_{}",
        prefix,
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

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
fn test_expand_args_inline_matches_standalone_prepare_args_for_nested_paramfiles() {
    let read_files = HashMap::<String, Vec<String>>::from([
        (
            "root.params".to_string(),
            vec![
                "--crate-name=foo".to_string(),
                "@nested.params".to_string(),
                "src/lib.rs".to_string(),
            ],
        ),
        (
            "nested.params".to_string(),
            vec![
                "--env-file".to_string(),
                "build.env".to_string(),
                "--arg-file".to_string(),
                "build.args".to_string(),
                "--output-file".to_string(),
                "diag.txt".to_string(),
                "--rustc-output-format".to_string(),
                "json".to_string(),
                "--stable-status-file".to_string(),
                "stable.txt".to_string(),
                "--volatile-status-file".to_string(),
                "volatile.txt".to_string(),
                "--pipelining-metadata".to_string(),
                "--pipelining-rlib-path=${pwd}/out/libfoo.rlib".to_string(),
                "@leaf.params".to_string(),
            ],
        ),
        (
            "leaf.params".to_string(),
            vec![
                "--out-dir=${pwd}/out".to_string(),
                "--cfg=leaf_cfg".to_string(),
            ],
        ),
    ]);
    let mut written_files = HashMap::<String, String>::new();
    let mut standalone_read = |filename: &str| -> Result<Vec<String>, OptionError> {
        read_files
            .get(filename)
            .cloned()
            .ok_or_else(|| OptionError::Generic(format!("file not found: {}", filename)))
    };
    let mut write_file = |filename: &str, content: &str| -> Result<(), OptionError> {
        match written_files.get_mut(filename) {
            Some(existing) => {
                existing.push('\n');
                existing.push_str(content);
            }
            None => {
                written_files.insert(filename.to_owned(), content.to_owned());
            }
        }
        Ok(())
    };
    let args = vec!["rustc".to_string(), "@root.params".to_string()];
    let subst_mappings = vec![("pwd".to_string(), "/work".to_string())];

    let (standalone_args, standalone_relocated) = prepare_args(
        args.clone(),
        &subst_mappings,
        true,
        Some(&mut standalone_read),
        Some(&mut write_file),
    )
    .unwrap();

    let mut worker_read = |filename: &str| -> Result<Vec<String>, OptionError> {
        read_files
            .get(filename)
            .cloned()
            .ok_or_else(|| OptionError::Generic(format!("file not found: {}", filename)))
    };
    let (worker_args, worker_meta) =
        crate::pw_args::expand_args_inline(&args, &subst_mappings, true, Some(&mut worker_read), false).unwrap();

    assert_eq!(
        standalone_args,
        vec![
            "rustc".to_string(),
            "@root.params.expanded".to_string(),
            "-Zallow-features=".to_string(),
        ]
    );
    let mut reconstructed = vec!["rustc".to_string()];
    reconstructed.extend(
        written_files["root.params.expanded"]
            .lines()
            .map(str::to_owned),
    );
    reconstructed.push("-Zallow-features=".to_string());
    assert_eq!(worker_args, reconstructed);
    assert_eq!(worker_meta.relocated, standalone_relocated);
    assert_eq!(standalone_relocated.env_files, vec!["build.env"]);
    assert_eq!(standalone_relocated.arg_files, vec!["build.args"]);
    assert_eq!(
        standalone_relocated.output_file.as_deref(),
        Some("diag.txt")
    );
    assert_eq!(
        standalone_relocated.rustc_output_format.as_deref(),
        Some("json")
    );
    assert_eq!(
        standalone_relocated.stable_status_file.as_deref(),
        Some("stable.txt")
    );
    assert_eq!(
        standalone_relocated.volatile_status_file.as_deref(),
        Some("volatile.txt")
    );
    assert_eq!(
        standalone_relocated.pipelining_mode,
        Some(SubprocessPipeliningMode::Metadata)
    );
    assert_eq!(
        standalone_relocated.pipelining_rlib_path.as_deref(),
        Some("/work/out/libfoo.rlib")
    );
}

#[test]
#[cfg(not(windows))]
fn resolve_external_path_unchanged_on_non_windows() {
    // On non-Windows, resolve_external_path is a no-op passthrough.
    for arg in [
        "external/some_repo/src/lib.txt",
        "src/main.rs",
        "external/nonexistent_repo_12345/src/lib.rs",
    ] {
        assert_eq!(&*resolve_external_path(arg), arg, "input: {arg}");
    }
}

#[test]
fn test_options_missing_stable_status_returns_error() {
    let tmp = unique_test_dir("pw_test_missing_stable_status");
    let missing = tmp.join("stable-status.txt");

    let err = options_from_args(vec![
        "process_wrapper".to_string(),
        "--stable-status-file".to_string(),
        missing.display().to_string(),
        "--".to_string(),
        "rustc".to_string(),
    ])
    .unwrap_err();

    match err {
        OptionError::Generic(message) => {
            assert!(message.contains("failed to read stable-status"));
            assert!(message.contains(&missing.display().to_string()));
        }
        other => panic!("expected generic error, got {:?}", other),
    }

    let _ = std::fs::remove_dir_all(&tmp);
}

#[test]
fn test_options_malformed_volatile_status_returns_error() {
    let tmp = unique_test_dir("pw_test_malformed_volatile_status");
    let volatile_status = tmp.join("volatile-status.txt");
    std::fs::write(&volatile_status, "BUILD_USER\n").unwrap();

    let err = options_from_args(vec![
        "process_wrapper".to_string(),
        "--volatile-status-file".to_string(),
        volatile_status.display().to_string(),
        "--".to_string(),
        "rustc".to_string(),
    ])
    .unwrap_err();

    match err {
        OptionError::Generic(message) => {
            assert!(message.contains("failed to read volatile-status"));
            assert!(message.contains(&volatile_status.display().to_string()));
            assert!(message.contains("wrong workspace status file format"));
        }
        other => panic!("expected generic error, got {:?}", other),
    }

    let _ = std::fs::remove_dir_all(&tmp);
}
