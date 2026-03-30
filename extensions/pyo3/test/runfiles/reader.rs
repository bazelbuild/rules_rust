//! A module for loading runfiles data.

use pyo3::exceptions::PyFileNotFoundError;
use pyo3::prelude::*;
use reader_helper::read_helper_data;
use runfiles::{rlocation, Runfiles};

/// A Python module implemented in Rust. The name of this function must match
/// the `lib.name` setting in the `Cargo.toml`, else Python will not be able to
/// import the module.
#[pymodule]
mod reader {

    use super::*;

    /// Formats the sum of two numbers as string.
    #[pyfunction]
    fn read_data() -> PyResult<String> {
        let r = Runfiles::create().unwrap();
        let path = rlocation!(r, "rules_rust_pyo3/test/runfiles/data.txt").unwrap();

        std::fs::read_to_string(path).map_err(PyFileNotFoundError::new_err)
    }

    #[pyfunction]
    fn read_transitive_data() -> PyResult<String> {
        read_helper_data().map_err(PyFileNotFoundError::new_err)
    }
}
