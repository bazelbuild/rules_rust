use std::process;
fn main() {
    // `rust_benchmark` targets produce two rust binaries. We want
    // to get the benchmark runner executable
    let bin = env!("BENCH_FILES")
        .split(' ')
        .find(|b| b.ends_with(".runner") || b.ends_with(".runner.exe"))
        .unwrap();

    // Run the benchmark as Cargo would
    let status = process::Command::new(bin)
        .status()
        .expect("Failed to run benchmark");

    // Ensure this binary exits with the same results
    process::exit(
        status
            .code()
            .expect("The process was terminated unexpectedly"),
    );
}
