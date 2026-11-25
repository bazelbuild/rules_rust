use pyo3::prelude::*;

#[pymodule]
fn embedding_probe(_module: &Bound<'_, PyModule>) -> PyResult<()> {
    Ok(())
}
