use std::path::{Path, PathBuf};
use std::{env, error::Error, fs};

fn is_msvc_linker(ld: &Path) -> bool {
    ld.file_stem()
        .and_then(|s| s.to_str())
        .is_some_and(|name| name.eq_ignore_ascii_case("link"))
}

fn main() -> Result<(), Box<dyn Error>> {
    let out = &PathBuf::from(env::var("OUT_DIR")?);

    // Write an empty static archive into OUT_DIR. The downstream
    // `bin_link` target links against it via `-l`, forcing the linker to
    // locate the file through the transitive link search path. If the
    // path resolves incorrectly, linking fails with "library not found".
    let ld = env::var("LD").unwrap_or_default();
    if is_msvc_linker(Path::new(&ld)) {
        // MSVC's link.exe requires a first-linker-member (symbol
        // directory) after the ar magic.
        let mut ar = Vec::new();
        ar.extend_from_slice(b"!<arch>\n");
        ar.extend_from_slice(b"/               "); // name  (16 bytes)
        ar.extend_from_slice(b"0           "); // mtime (12 bytes)
        ar.extend_from_slice(b"0     "); // uid   ( 6 bytes)
        ar.extend_from_slice(b"0     "); // gid   ( 6 bytes)
        ar.extend_from_slice(b"100644  "); // mode  ( 8 bytes)
        ar.extend_from_slice(b"4         "); // size  (10 bytes)
        ar.extend_from_slice(b"`\n"); // end   ( 2 bytes)
        ar.extend_from_slice(&[0, 0, 0, 0]); // 0 symbols (big-endian u32)
        fs::write(out.join("libcross_crate_lib.a"), &ar)?;
    } else {
        // GNU ld / gold / lld / Apple ld all accept bare ar magic.
        fs::write(out.join("libcross_crate_lib.a"), b"!<arch>\n")?;
    }

    println!("cargo:rustc-link-search={}", out.display());
    Ok(())
}
