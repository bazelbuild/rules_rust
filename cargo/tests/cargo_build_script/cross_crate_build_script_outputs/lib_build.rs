use std::{env, error::Error, fs, path::PathBuf};

fn main() -> Result<(), Box<dyn Error>> {
    let out = &PathBuf::from(env::var("OUT_DIR")?);
    fs::write(out.join("script_from_lib.x"), "/* hello */")?;
    println!("cargo:rustc-link-search={}", out.display());
    Ok(())
}
