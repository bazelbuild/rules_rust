use protobuf::ProtobufResult;
mod lib;

fn main() -> ProtobufResult<()> {
    let mut args = std::env::args_os().peekable();
    // Always discard the executable name.
    args.next().unwrap();

    let program = std::fs::canonicalize(args.next().expect("program name"))?;
    let rustc_path = std::fs::canonicalize(args.next().expect("rustc path"))?;
    let compilation_mode = args
        .next()
        .expect("compilation mode")
        .into_string()
        .expect("compilation mode must be valid utf-8");
    // TODO: program and rustc_path will combine when this is merged into rules_rust.
    let worker = lib::Worker::new(program, rustc_path, compilation_mode)?;

    // If started as a persistent worker.
    if let Some(arg) = args.peek() {
        if arg == "--persistent_worker" {
            let stdin = std::io::stdin();
            let stdout = std::io::stdout();
            let mut stdin_locked = stdin.lock();
            let mut stdout_locked = stdout.lock();
            return worker.main_loop(&mut stdin_locked, &mut stdout_locked);
        }
    }

    // Spawn process as normal.
    // The process wrapper does not support response files.
    let response_file_arg = args
        .next()
        .unwrap()
        .into_string()
        .expect("response file path is valid utf-8");
    // The response file has to be the last (and only) argument left.
    assert!(args.peek().is_none(), "iterator should be consumed!");
    assert!(response_file_arg.starts_with("@"));
    let response_file_path = &response_file_arg[1..];
    let status = worker.once_with_response_file(response_file_path)?;
    std::process::exit(status.code().unwrap());
}
