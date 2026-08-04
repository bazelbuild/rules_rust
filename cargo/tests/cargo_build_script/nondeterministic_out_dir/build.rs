use std::path::PathBuf;

fn main() {
    let out_dir = PathBuf::from(std::env::var("OUT_DIR").unwrap());

    // Simulate files written by autoconf/cmake/mklove that embed sandbox-specific
    // paths and must be stripped by the build script runner before Bazel captures
    // OUT_DIR as a TreeArtifact.
    std::fs::write(
        out_dir.join("config.log"),
        "configure log with /sandbox/path",
    )
    .unwrap();
    std::fs::write(out_dir.join("config.status"), "configure status").unwrap();
    std::fs::write(out_dir.join("Makefile"), "all:\n\t@echo sandbox path here").unwrap();
    std::fs::write(out_dir.join("Makefile.config"), "CFLAGS=-I/sandbox/include").unwrap();
    std::fs::write(
        out_dir.join("config.cache"),
        "# generated at Mon Jan  1 00:00:00 UTC 2024",
    )
    .unwrap();
    std::fs::write(out_dir.join("foo.d"), "foo.o: foo.c /sandbox/include/bar.h").unwrap();
    std::fs::write(out_dir.join("baz.d"), "baz.o: baz.c /sandbox/include/qux.h").unwrap();
    std::fs::write(
        out_dir.join("foo.pc"),
        "prefix=/sandbox/out\nexec_prefix=${prefix}",
    )
    .unwrap();

    // Write a legitimate output that downstream consumers must be able to read.
    std::fs::write(out_dir.join("output.txt"), "legitimate output").unwrap();

    println!("cargo:rerun-if-changed=build.rs");
}
