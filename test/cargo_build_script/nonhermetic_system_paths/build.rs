use std::process::Command;

fn pkg_config(args: &[&str]) -> String {
    let candidates = ["/opt/homebrew/bin/pkg-config", "pkg-config"];
    for candidate in candidates {
        if let Ok(output) = Command::new(candidate).args(args).output() {
            if output.status.success() {
                return String::from_utf8(output.stdout)
                    .expect("pkg-config output was not UTF-8")
                    .trim()
                    .to_owned();
            }
        }
    }
    panic!("no pkg-config installation could find system zlib")
}

fn main() {
    let libdir = pkg_config(&["--variable=libdir", "zlib"]);
    assert!(
        std::path::Path::new(&libdir).is_absolute(),
        "expected pkg-config to return an absolute zlib libdir, got {libdir:?}"
    );

    println!("cargo::rustc-link-search=native={libdir}");
    println!("cargo::rustc-env=SYSTEM_ZLIB_LIBDIR={libdir}");
    for flag in pkg_config(&["--libs-only-l", "zlib"]).split_whitespace() {
        if let Some(library) = flag.strip_prefix("-l") {
            println!("cargo::rustc-link-lib={library}");
        }
    }
}
