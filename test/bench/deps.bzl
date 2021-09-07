"""A module for loading benchmark example dependencies"""

load("//test/bench/criterion/raze:crates.bzl", "rules_rust_test_bench_criterion_fetch_remote_crates")

def benchmarking_deps():
    rules_rust_test_bench_criterion_fetch_remote_crates()
