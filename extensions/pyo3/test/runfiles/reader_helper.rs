//! A helper crate for loading transitive runfile data.

use runfiles::{rlocation, Runfiles};

pub fn read_helper_data() -> std::io::Result<String> {
    let runfiles = Runfiles::create().map_err(std::io::Error::other)?;
    let path = rlocation!(
        runfiles,
        "rules_rust/extensions/pyo3/test/runfiles/helper_data.txt"
    )
    .ok_or_else(|| {
        std::io::Error::new(
            std::io::ErrorKind::NotFound,
            "helper runfile path could not be resolved",
        )
    })?;
    std::fs::read_to_string(path)
}
