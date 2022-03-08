use std::io::{stdout, BufWriter};
use std::path::Path;
use std::process::Command;

fn execute_texture_synthesis() -> Vec<u8> {
    let texture_synthesis_path = Path::new(env!("TEXTURE_SYNTHESIS_CLI"));

    let output = Command::new(texture_synthesis_path)
        .arg("--help")
        .output()
        .unwrap();

    if !output.status.success() {
        panic!("Execution of texter-synthesis-cli failed")
    }

    output.stdout
}

fn main() {
    // Run the command
    let output = execute_texture_synthesis();

    // Print the results
    let mut writer = BufWriter::new(stdout());
    ferris_says::say(&output, 120, &mut writer).unwrap();
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_output() {
        let stdout = execute_texture_synthesis();
        let text = String::from_utf8(stdout).unwrap();
        assert!(text.contains("Synthesizes images based on example images"));
    }
}
