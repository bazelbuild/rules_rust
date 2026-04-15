use rust_test_sharding_lib::{
    empty_shard_filter, empty_test_filter, exec_test_binary, filter_tests_by_name, has_exact_flag,
    inferred_test_filters, list_tests, parse_args, resolve_test_binary, select_shard_tests,
    shard_config_from_env, touch_shard_status_file,
};
use std::env;
use std::ffi::OsString;
use std::process;

fn main() {
    if let Err(err) = run() {
        eprintln!("{err}");
        process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let test_binary = resolve_test_binary()?;
    let parsed_args = parse_args(env::args_os().skip(1));
    let test_filters = inferred_test_filters(&parsed_args.explicit_filters)?;
    let shard_config = shard_config_from_env()?;

    if shard_config.is_some() {
        touch_shard_status_file()
            .map_err(|err| format!("failed to touch TEST_SHARD_STATUS_FILE: {err}"))?;
    }

    if parsed_args.passthrough {
        let mut passthrough_args = parsed_args.execution_args.clone();
        passthrough_args.extend(test_filters);
        return exec_test_binary(&test_binary, &passthrough_args);
    }

    let active_shard = match shard_config {
        Some(shard) if shard.total > 1 => Some(shard),
        _ => None,
    };

    if active_shard.is_none() && test_filters.is_empty() {
        return exec_test_binary(&test_binary, &parsed_args.execution_args);
    }

    let test_names = list_tests(&test_binary, &parsed_args.listing_args)?;
    let selected_tests = match active_shard {
        Some(shard) => select_shard_tests(&test_names, shard),
        None => test_names,
    };
    let mut execution_args = parsed_args.execution_args;
    let has_exact = has_exact_flag(&execution_args);
    let selected_tests = filter_tests_by_name(&selected_tests, &test_filters, has_exact);
    if !has_exact {
        execution_args.push(OsString::from("--exact"));
    }
    if selected_tests.is_empty() {
        execution_args.push(match active_shard {
            Some(shard) => empty_shard_filter(shard),
            None => empty_test_filter(),
        });
    } else {
        execution_args.extend(selected_tests.into_iter().map(OsString::from));
    }
    exec_test_binary(&test_binary, &execution_args)
}
