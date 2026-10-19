//! Calls into a C library supplied via `link_deps`.

use pyo3::prelude::*;

extern "C" {
    fn pyo3_link_deps_answer() -> i32;
}

#[pymodule]
mod link_deps {
    use super::*;

    #[pyfunction]
    fn answer() -> i32 {
        unsafe { pyo3_link_deps_answer() }
    }
}
