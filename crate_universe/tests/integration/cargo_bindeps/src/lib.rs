use std::process::Command;

pub fn version() -> String {
    let output = Command::new(env!("HYPERFINE"))
        .arg("--version")
        .output()
        .expect("failed to execute process");

    String::from_utf8(output.stdout).expect("invalid UTF-8 found")
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_version() {
        assert_eq!(version(), "hyperfine 1.17.0\n");
    }
}
