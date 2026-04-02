use super::*;

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
