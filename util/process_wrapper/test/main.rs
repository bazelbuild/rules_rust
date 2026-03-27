use super::*;
use tinyjson::JsonValue;

fn parse_json(json_str: &str) -> Result<JsonValue, String> {
    json_str.parse::<JsonValue>().map_err(|e| e.to_string())
}

#[test]
fn test_process_line_diagnostic_json() -> Result<(), String> {
    let LineOutput::Message(msg) = process_line(
        r#"
            {
                "$message_type": "diagnostic",
                "rendered": "Diagnostic message"
            }
        "#
        .to_string(),
        ErrorFormat::Json,
    )?
    else {
        return Err("Expected a LineOutput::Message".to_string());
    };
    assert_eq!(
        parse_json(&msg)?,
        parse_json(
            r#"
            {
                "$message_type": "diagnostic",
                "rendered": "Diagnostic message"
            }
        "#
        )?
    );
    Ok(())
}

#[test]
fn test_process_line_diagnostic_rendered() -> Result<(), String> {
    let LineOutput::Message(msg) = process_line(
        r#"
            {
                "$message_type": "diagnostic",
                "rendered": "Diagnostic message"
            }
        "#
        .to_string(),
        ErrorFormat::Rendered,
    )?
    else {
        return Err("Expected a LineOutput::Message".to_string());
    };
    assert_eq!(msg, "Diagnostic message");
    Ok(())
}

#[test]
fn test_process_line_noise() -> Result<(), String> {
    for text in [
        "'+zaamo' is not a recognized feature for this target (ignoring feature)",
        " WARN rustc_errors::emitter Invalid span...",
    ] {
        let LineOutput::Message(msg) = process_line(text.to_string(), ErrorFormat::Json)? else {
            return Err("Expected a LineOutput::Message".to_string());
        };
        assert_eq!(
            parse_json(&msg)?,
            parse_json(&format!(
                r#"{{
                    "$message_type": "diagnostic",
                    "message": "{0}",
                    "code": null,
                    "level": "warning",
                    "spans": [],
                    "children": [],
                    "rendered": "{0}"
                }}"#,
                text
            ))?
        );
    }
    Ok(())
}

#[test]
fn test_process_line_emit_link() -> Result<(), String> {
    assert!(matches!(
        process_line(
            r#"
            {
                "$message_type": "artifact",
                "emit": "link"
            }
        "#
            .to_string(),
            ErrorFormat::Rendered,
        )?,
        LineOutput::Skip
    ));
    Ok(())
}

#[test]
fn test_process_line_emit_metadata() -> Result<(), String> {
    assert!(matches!(
        process_line(
            r#"
            {
                "$message_type": "artifact",
                "emit": "metadata"
            }
        "#
            .to_string(),
            ErrorFormat::Rendered,
        )?,
        LineOutput::Skip
    ));
    Ok(())
}

#[test]
#[cfg(unix)]
fn test_seed_cache_root_for_current_dir() -> Result<(), String> {
    let tmp = std::env::temp_dir().join("pw_test_seed_cache_root_for_current_dir");
    let sandbox_dir = tmp.join("sandbox");
    let cache_repo = tmp.join("cache/repos/v1/contents/hash/repo");
    fs::create_dir_all(&sandbox_dir).map_err(|e| e.to_string())?;
    fs::create_dir_all(cache_repo.join("tool/src")).map_err(|e| e.to_string())?;
    symlink_dir(&cache_repo, &sandbox_dir.join("external_repo")).map_err(|e| e.to_string())?;

    let old_cwd = std::env::current_dir().map_err(|e| e.to_string())?;
    std::env::set_current_dir(&sandbox_dir).map_err(|e| e.to_string())?;
    let result = seed_cache_root_for_current_dir().map_err(|e| e.to_string());
    let restore = std::env::set_current_dir(old_cwd).map_err(|e| e.to_string());
    let seeded_target = sandbox_dir
        .join("cache")
        .canonicalize()
        .map_err(|e| e.to_string());

    let _ = fs::remove_dir_all(&tmp);

    result?;
    restore?;
    assert_eq!(seeded_target?, tmp.join("cache"));
    Ok(())
}

#[test]
#[cfg(unix)]
fn test_seed_cache_root_from_execroot_ancestor() -> Result<(), String> {
    let tmp = std::env::temp_dir().join("pw_test_seed_cache_root_from_execroot_ancestor");
    let cwd = tmp.join("output-base/execroot/_main");
    fs::create_dir_all(tmp.join("output-base/cache/repos")).map_err(|e| e.to_string())?;
    fs::create_dir_all(&cwd).map_err(|e| e.to_string())?;

    let old_cwd = std::env::current_dir().map_err(|e| e.to_string())?;
    std::env::set_current_dir(&cwd).map_err(|e| e.to_string())?;
    let result = seed_cache_root_for_current_dir().map_err(|e| e.to_string());
    let restore = std::env::set_current_dir(old_cwd).map_err(|e| e.to_string());
    let seeded_target = cwd.join("cache").canonicalize().map_err(|e| e.to_string());

    let _ = fs::remove_dir_all(&tmp);

    result?;
    restore?;
    assert_eq!(seeded_target?, tmp.join("output-base/cache"));
    Ok(())
}

#[test]
#[cfg(unix)]
fn test_ensure_cache_loopback_from_args() -> Result<(), String> {
    let tmp = std::env::temp_dir().join("pw_test_ensure_cache_loopback_from_args");
    let cwd = tmp.join("output-base/execroot/_main");
    let cache_root = tmp.join("output-base/cache");
    let source = cache_root.join("repos/v1/contents/hash/repo/.tmp_git_root/tool/src/lib.rs");
    fs::create_dir_all(source.parent().unwrap()).map_err(|e| e.to_string())?;
    fs::create_dir_all(&cwd).map_err(|e| e.to_string())?;
    fs::write(&source, "").map_err(|e| e.to_string())?;
    symlink_dir(
        &cache_root.join("repos/v1/contents/hash/repo"),
        &cwd.join("external_repo"),
    )
    .map_err(|e| e.to_string())?;

    let loopback = ensure_cache_loopback_from_args(
        &cwd,
        &[String::from("external_repo/.tmp_git_root/tool/src/lib.rs")],
        &cache_root,
    )
    .map_err(|e| e.to_string())?;
    let loopback_target = cache_root
        .join("repos/v1/cache")
        .canonicalize()
        .map_err(|e| e.to_string())?;

    let _ = fs::remove_dir_all(&tmp);

    assert_eq!(loopback, Some(cache_root.join("repos/v1/cache")));
    assert_eq!(loopback_target, cache_root);
    Ok(())
}

#[test]
fn test_run_standalone_cleans_up_expanded_paramfiles() -> Result<(), String> {
    let crate_dir = setup_test_crate("cleanup_expanded_paramfiles");
    let out_dir = crate_dir.join("out");
    let paramfile = crate_dir.join("cleanup_expanded_paramfiles.params");
    fs::create_dir_all(&out_dir).map_err(|e| e.to_string())?;
    fs::write(
        &paramfile,
        format!(
            "--crate-type=lib\n--edition=2021\n--crate-name=cleanup_test\n--emit=metadata\n--out-dir={}\n{}\n",
            out_dir.display(),
            crate_dir.join("lib.rs").display(),
        ),
    )
    .map_err(|e| e.to_string())?;

    let expanded_paramfile = std::env::temp_dir().join(format!(
        "pw_expanded_{}_{}",
        std::process::id(),
        paramfile
            .file_name()
            .and_then(|name| name.to_str())
            .ok_or_else(|| "paramfile basename was not utf-8".to_string())?,
    ));
    let _ = fs::remove_file(&expanded_paramfile);

    let opts = crate::options::options_from_args(vec![
        "process_wrapper".to_string(),
        "--".to_string(),
        resolve_rustc().display().to_string(),
        format!("@{}", paramfile.display()),
    ])
    .map_err(|e| e.to_string())?;

    assert_eq!(
        opts.temporary_expanded_paramfiles,
        vec![expanded_paramfile.clone()]
    );
    assert!(
        expanded_paramfile.exists(),
        "expected expanded paramfile at {}",
        expanded_paramfile.display()
    );

    let code = run_standalone(&opts).map_err(|e| e.to_string())?;
    let compiled_metadata = fs::read_dir(&out_dir)
        .map_err(|e| e.to_string())?
        .filter_map(|entry| entry.ok())
        .any(|entry| entry.path().extension().is_some_and(|ext| ext == "rmeta"));

    let _ = fs::remove_dir_all(&crate_dir);

    assert_eq!(code, 0);
    assert!(compiled_metadata, "expected rustc to emit an .rmeta file");
    assert!(
        !expanded_paramfile.exists(),
        "expected expanded paramfile cleanup for {}",
        expanded_paramfile.display()
    );
    Ok(())
}

/// Resolves the real rustc binary from the runfiles tree.
fn resolve_rustc() -> std::path::PathBuf {
    let r = runfiles::Runfiles::create().unwrap();
    runfiles::rlocation!(r, env!("RUSTC_RLOCATIONPATH"))
        .expect("could not resolve RUSTC_RLOCATIONPATH via runfiles")
}

/// Creates a temp directory with a trivial Rust library source file.
fn setup_test_crate(name: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!("pw_determinism_{name}_{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    fs::write(
        dir.join("lib.rs"),
        "pub fn hello() -> u32 { 42 }\npub fn world() -> &'static str { \"hello\" }\n",
    )
    .unwrap();
    dir
}

/// Compiles lib.rs by invoking rustc directly into `out_dir`.
/// Uses --error-format=json --json=artifacts to match the pipelined invocation
/// (these flags affect the crate hash / SVH embedded in metadata).
fn compile_standalone(
    rustc: &std::path::Path,
    src_dir: &std::path::Path,
    out_dir: &std::path::Path,
) {
    let env_map: std::collections::HashMap<String, String> = std::env::vars().collect();
    let status = std::process::Command::new(rustc)
        .args(&[
            "--crate-type=lib",
            "--edition=2021",
            "--crate-name=testcrate",
            "--emit=dep-info,metadata,link",
            "-Cembed-bitcode=no",
            "--error-format=json",
            "--json=artifacts",
        ])
        .arg(&format!("--out-dir={}", out_dir.display()))
        .arg(src_dir.join("lib.rs"))
        .env_clear()
        .envs(&env_map)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .current_dir(src_dir)
        .status()
        .expect("failed to spawn rustc");
    assert!(status.success(), "standalone rustc compilation failed");
}

/// Reads the first file with the given extension from a directory.
fn find_artifact(dir: &std::path::Path, ext: &str) -> Vec<u8> {
    let entry = fs::read_dir(dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .find(|e| e.path().extension().map_or(false, |x| x == ext))
        .unwrap_or_else(|| panic!("no .{ext} found in {}", dir.display()));
    fs::read(entry.path()).unwrap()
}

#[test]
fn test_pipelined_matches_standalone() {
    use crate::worker::pipeline::{
        handle_pipelining_full, handle_pipelining_metadata, PipelineState, WorkerStateRoots,
    };
    use crate::worker::protocol::WorkRequestContext;
    use std::sync::{Arc, Mutex};

    let rustc = resolve_rustc();
    let dir = setup_test_crate("pipelined_vs_standalone");
    let out_dir_standalone = dir.join("out_standalone");
    let out_dir_pipelined = dir.join("out_pipelined");
    fs::create_dir_all(&out_dir_standalone).unwrap();
    fs::create_dir_all(&out_dir_pipelined).unwrap();

    // 1a. Compile via direct rustc invocation (baseline).
    compile_standalone(&rustc, &dir, &out_dir_standalone);

    // 1b. Compile standalone a second time — determinism precondition.
    // If rustc itself is non-deterministic with these flags, the pipelined
    // comparison below is meaningless.
    let out_dir_standalone2 = dir.join("out_standalone2");
    fs::create_dir_all(&out_dir_standalone2).unwrap();
    compile_standalone(&rustc, &dir, &out_dir_standalone2);
    assert_eq!(
        find_artifact(&out_dir_standalone, "rlib"),
        find_artifact(&out_dir_standalone2, "rlib"),
        "rustc is non-deterministic with these flags — pipelined comparison is not viable"
    );
    assert_eq!(
        find_artifact(&out_dir_standalone, "rmeta"),
        find_artifact(&out_dir_standalone2, "rmeta"),
        "rustc .rmeta is non-deterministic — pipelined comparison is not viable"
    );

    // 2. Compile via pipelined worker handlers.
    // Save CWD, chdir to temp dir (pipeline handlers use CWD for _pw_state/).
    let original_cwd = std::env::current_dir().unwrap();
    std::env::set_current_dir(&dir).unwrap();

    let state_roots = WorkerStateRoots::ensure().unwrap();
    let pipeline_state = Arc::new(Mutex::new(PipelineState::new()));

    let pipeline_key = worker::types::PipelineKey("test_determinism".to_string());

    // Pre-register the metadata request.
    {
        let mut state = pipeline_state.lock().unwrap();
        state.register_metadata(worker::types::RequestId(1), pipeline_key.clone());
    }

    let rustc_str = rustc.display().to_string();
    let src_path = dir.join("lib.rs").display().to_string();
    let out_dir_str = out_dir_pipelined.display().to_string();

    // Build args in the format handle_pipelining_metadata expects:
    // [pw_flags...] -- rustc [rustc_args...] --pipelining-metadata --pipelining-key=<key>
    //
    // The handler splits on "--", parses pw args before it, and rustc args after.
    // --json=artifacts is required so rustc emits the .rmeta notification JSON.
    let metadata_args: Vec<String> = vec![
        "--".to_string(),
        rustc_str.clone(),
        "--crate-type=lib".to_string(),
        "--edition=2021".to_string(),
        "--crate-name=testcrate".to_string(),
        format!("--out-dir={out_dir_str}"),
        "--emit=dep-info,metadata,link".to_string(),
        "-Cembed-bitcode=no".to_string(),
        "--error-format=json".to_string(),
        "--json=artifacts".to_string(),
        src_path.clone(),
        "--pipelining-metadata".to_string(),
        format!("--pipelining-key={pipeline_key}"),
    ];

    let metadata_request = WorkRequestContext {
        request_id: worker::types::RequestId(1),
        arguments: metadata_args.clone(),
        sandbox_dir: None,
        inputs: vec![],
        cancel: false,
    };

    let (exit_code, diagnostics) = handle_pipelining_metadata(
        &metadata_request,
        metadata_args,
        pipeline_key.clone(),
        &state_roots,
        &pipeline_state,
    );
    assert_eq!(
        exit_code, 0,
        "pipelining metadata handler failed: {diagnostics}"
    );

    // Pre-register the full request.
    {
        let mut state = pipeline_state.lock().unwrap();
        state.register_full(worker::types::RequestId(2), pipeline_key.clone());
    }

    let full_args: Vec<String> = vec![
        "--".to_string(),
        rustc_str.clone(),
        "--crate-type=lib".to_string(),
        "--edition=2021".to_string(),
        "--crate-name=testcrate".to_string(),
        format!("--out-dir={out_dir_str}"),
        "--emit=dep-info,metadata,link".to_string(),
        "-Cembed-bitcode=no".to_string(),
        "--error-format=json".to_string(),
        "--json=artifacts".to_string(),
        src_path,
        "--pipelining-full".to_string(),
        format!("--pipelining-key={pipeline_key}"),
    ];

    // handle_pipelining_full needs self_path for fallback.
    // We won't hit the fallback path since metadata stored the bg process.
    let self_path = std::path::Path::new("/dev/null");

    let full_request = WorkRequestContext {
        request_id: worker::types::RequestId(2),
        arguments: full_args.clone(),
        sandbox_dir: None,
        inputs: vec![],
        cancel: false,
    };

    let (exit_code, diagnostics) = handle_pipelining_full(
        &full_request,
        full_args,
        pipeline_key,
        &pipeline_state,
        self_path,
    );

    // Restore CWD before assertions (so cleanup works even if test fails).
    std::env::set_current_dir(&original_cwd).unwrap();

    assert_eq!(
        exit_code, 0,
        "pipelining full handler failed: {diagnostics}"
    );

    // 3. Read artifacts from both output dirs.
    let standalone_rlib = find_artifact(&out_dir_standalone, "rlib");
    let pipelined_rlib = find_artifact(&out_dir_pipelined, "rlib");
    let standalone_rmeta = find_artifact(&out_dir_standalone, "rmeta");
    let pipelined_rmeta = find_artifact(&out_dir_pipelined, "rmeta");

    let _ = fs::remove_dir_all(&dir);

    // 4. Compare .rlib artifacts.
    assert_eq!(
        standalone_rlib.len(),
        pipelined_rlib.len(),
        "rlib size differs: standalone={} pipelined={}",
        standalone_rlib.len(),
        pipelined_rlib.len()
    );
    assert_eq!(
        standalone_rlib, pipelined_rlib,
        "pipelined .rlib differs from standalone .rlib — \
         worker pipelining does not preserve output determinism"
    );

    // 5. Compare .rmeta artifacts.
    // The .rmeta is what downstream crates compile against. If it differs
    // between pipelined and standalone, downstream builds could see
    // different type information or SVH values.
    assert_eq!(
        standalone_rmeta.len(),
        pipelined_rmeta.len(),
        "rmeta size differs: standalone={} pipelined={}",
        standalone_rmeta.len(),
        pipelined_rmeta.len()
    );
    assert_eq!(
        standalone_rmeta, pipelined_rmeta,
        "pipelined .rmeta differs from standalone .rmeta — \
         worker pipelining does not preserve metadata determinism"
    );
}
