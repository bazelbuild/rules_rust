//! This binary mocks the output of rustc when run with `--error-format=json` and `--json=artifacts`.

fn main() {
    eprintln!(r#"{{"rendered": "should be\nin output"}}"#);
    eprintln!(r#"{{"emit": "metadata"}}"#);
    std::thread::sleep(std::time::Duration::from_secs(1));
    eprintln!(r#"{{"rendered": "should not be in output"}}"#);
}
