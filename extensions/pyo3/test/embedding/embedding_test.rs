use pyo3::prelude::*;
use pyo3::types::PyString;
use runfiles::{rlocation, Runfiles};
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::Path;

fn check_loaded_libpython(python_home: &Path) {
    let expected = python_home.join(format!("lib/libpython{}.so.1.0", env!("PYTHON_VERSION")));
    let expected_metadata = fs::metadata(&expected).unwrap();
    let maps = fs::read_to_string("/proc/self/maps").unwrap();
    let mut found = false;

    for path in maps
        .lines()
        .filter_map(|line| line.find('/').map(|offset| Path::new(&line[offset..])))
    {
        if !path
            .file_name()
            .and_then(|name| name.to_str())
            .is_some_and(|name| name.starts_with("libpython") && name.contains(".so"))
        {
            continue;
        }
        let loaded = fs::metadata(path).unwrap();
        assert_eq!(
            (loaded.dev(), loaded.ino()),
            (expected_metadata.dev(), expected_metadata.ino()),
            "loaded {} instead of {}",
            path.display(),
            expected.display(),
        );
        found = true;
    }
    assert!(
        found,
        "{} is missing from /proc/self/maps",
        expected.display()
    );
}

#[test]
fn embeds_target_cpython() {
    let runfiles = Runfiles::create().unwrap();
    let interpreter =
        rlocation!(runfiles, env!("PYTHON_RUNFILE").trim_start_matches("../")).unwrap();
    let python_home = interpreter.parent().unwrap().parent().unwrap();
    let extension = rlocation!(runfiles, env!("EXTENSION_RUNFILE")).unwrap();

    check_loaded_libpython(python_home);
    let extension_bytes = fs::read(&extension).unwrap();
    let elf = goblin::elf::Elf::parse(&extension_bytes).unwrap();
    assert!(
        !elf.libraries
            .iter()
            .any(|name| name.starts_with("libpython")),
        "unexpected libpython dependency: {:?}",
        elf.libraries,
    );

    std::env::set_var("PYTHONHOME", python_home);
    std::env::remove_var("PYTHONPATH");

    Python::initialize();
    Python::attach(|py| {
        let greeting = "Bazel ♥ Python 🐍";
        let string = PyString::new(py, greeting);
        #[cfg(target_endian = "little")]
        {
            // Read the Unicode layout directly. It differs across CPython minor versions.
            // SAFETY: This target uses little-endian CPython bitfields.
            let data = unsafe { string.data() }.unwrap();
            assert_eq!(data.to_string(py).unwrap(), greeting);
        }
        #[cfg(target_endian = "big")]
        assert_eq!(string.to_str().unwrap(), greeting);

        let json = py.import("json").unwrap();
        let module_file: String = json.getattr("__file__").unwrap().extract().unwrap();
        assert!(Path::new(&module_file).starts_with(python_home));
    });
}
