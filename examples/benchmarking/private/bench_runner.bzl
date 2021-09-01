"""A helper module for ensuring the benchmark rules produce working binaries"""

load("@rules_rust//rust:defs.bzl", "rust_test")

def bench_runner_test(name, benchmark, tags = []):
    rust_test(
        name = name,
        data = [benchmark],
        srcs = ["//benchmarking/private:bench_runner.rs"],
        rustc_env = {
            "BENCH_FILES": "$(rootpaths {})".format(benchmark),
        },
        use_libtest_harness = False,
        tags = tags,
    )
