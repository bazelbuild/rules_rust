fn main() {
    let arg = std::env::args().nth(1).unwrap_or_default();
    println!("{arg}");

    let exit_code = std::env::var("BOOTSTRAP_PROCESS_WRAPPER_PROBE_EXIT_CODE")
        .ok()
        .and_then(|v| v.parse::<i32>().ok())
        .unwrap_or(0);
    std::process::exit(exit_code);
}
