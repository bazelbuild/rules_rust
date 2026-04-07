use std::env;
use std::thread;
use std::time::Duration;

#[cfg(unix)]
type SignalHandler = usize;
#[cfg(unix)]
const SIGTERM_SIGNAL: i32 = 15;
#[cfg(unix)]
const SIGNAL_IGNORE: SignalHandler = 1;

#[cfg(unix)]
unsafe extern "C" {
    fn signal(signal: i32, handler: SignalHandler) -> SignalHandler;
}

fn assert_expected_shard(test_ordinal: usize) {
    let total = match env::var("TEST_TOTAL_SHARDS") {
        Ok(value) => value
            .parse::<usize>()
            .expect("TEST_TOTAL_SHARDS should be a valid integer"),
        Err(_) => return,
    };

    let index = env::var("TEST_SHARD_INDEX")
        .expect("TEST_SHARD_INDEX should be set when TEST_TOTAL_SHARDS is set")
        .parse::<usize>()
        .expect("TEST_SHARD_INDEX should be a valid integer");

    assert_eq!(
        test_ordinal % total,
        index,
        "test ordinal {} should run on shard {} of {}",
        test_ordinal,
        test_ordinal % total,
        total,
    );
}

#[test]
fn test_0() {
    assert_expected_shard(0);
}

#[test]
fn test_1() {
    assert_expected_shard(1);
}

#[test]
fn test_2() {
    assert_expected_shard(2);
}

#[test]
fn test_3() {
    assert_expected_shard(3);
}

#[test]
fn test_4() {
    assert_expected_shard(4);
}

#[test]
fn test_5() {
    assert_expected_shard(5);
}

#[test]
fn test_6() {
    assert_expected_shard(6);
}

#[test]
fn test_7() {
    assert_expected_shard(7);
}

#[test]
fn test_8() {
    assert_expected_shard(8);
}

#[test]
fn test_9_current_exe_uses_public_binary_name() {
    assert_expected_shard(9);

    let exe_name = env::current_exe()
        .expect("current_exe should be available")
        .file_name()
        .expect("current_exe should have a file name")
        .to_string_lossy()
        .into_owned();

    assert!(
        !exe_name.contains("__test_sharding_bin"),
        "expected current_exe to preserve the public test binary name, got {}",
        exe_name,
    );
}

#[test]
fn zz_timeout_probe_preserves_public_binary_name() {
    // This probe stays fast in normal test runs, but lets us force a timeout in
    // manual regression checks for Bazel's timeout XML path.
    if env::var_os("RULES_RUST_SHARDING_TIMEOUT_PROBE").is_some() {
        #[cfg(unix)]
        if env::var_os("RULES_RUST_SHARDING_IGNORE_SIGTERM").is_some() {
            // Reproduce the review scenario where the child keeps running after
            // Bazel's timeout SIGTERM unless the launcher records timeout state
            // and force-terminates it on its own.
            let rc = unsafe { signal(SIGTERM_SIGNAL, SIGNAL_IGNORE) };
            assert_ne!(rc, usize::MAX, "failed to ignore SIGTERM for timeout probe");
        }

        thread::sleep(Duration::from_secs(5));
    }
}
