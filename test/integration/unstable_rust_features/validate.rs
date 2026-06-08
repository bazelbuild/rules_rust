#[test]
fn test_genquery_file_empty() {
    let profile_base_path = std::path::PathBuf::from(std::env::var_os("PROFILE_PATH").unwrap());
    let profile_path = profile_base_path.parent().unwrap().join("sample_binary_self-profile");
    let profile_path = std::path::Path::new(&profile_path);
    assert!(profile_path.is_dir());

    let files_count = match std::fs::read_dir(profile_path) {
        Ok(entries) => {
            entries.filter_map(Result::ok).count()
        }
        Err(_) => 0,
    };
    assert!(files_count > 0);
}
