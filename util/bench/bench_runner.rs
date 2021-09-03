use std::process;

fn main() {
    let mut cmd = process::Command::new(env!("BENCH_BINARY"));

    // Get args but skip the binary
    let args: Vec<_> = std::env::args_os().skip(1).collect();

    // If there are arguments passed to the binary, use those
    // otherwise, use that the binary was compiled with.
    if !args.is_empty() {
        cmd.args(args);
    } else {
        cmd.args(env!("BENCH_ARGS").split(" "));
    }

    // Run the benchmark
    let status = cmd.status().expect("Failed to run benchmark");

    // Ensure this binary exits with the same results
    process::exit(
        status
            .code()
            .expect("The process was terminated unexpectedly"),
    );
}
