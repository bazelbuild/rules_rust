use std::process::Command;

#[test]
fn test_stamp_is_resolved() {
    let output = Command::new(env!("PRINTER"))
        .output()
        .expect("Failed to start printer binary");

    let stdout = String::from_utf8(output.stdout).unwrap();

    assert!(stdout.starts_with("Built at"));
    assert!(!stdout.contains(&"BUILD_TIMESTAMP".to_owned()));
}

#[test]
fn test_template() {
    let template = include_str!(env!("TEMPLATE"));

    assert_eq!(template.trim(), "BUILD_TIMESTAMP={BUILD_TIMESTAMP}");
}
