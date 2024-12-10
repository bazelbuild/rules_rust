//! Tests to verify bazel-central-registry CI is configured for the current
//! version of rules_rust.

use runfiles::Runfiles;

/// If this test fails, it means the vendoring of the core rules is not in
/// sync with the current version of rules_rust and the urls need to be updated.
#[test]
fn vendered_core_rules_version_in_sync() {
    let r = Runfiles::create().unwrap();
    let rlocationpaths = env!("PRESUBMIT_RLOCATIONPATHS")
        .split(" ")
        .collect::<Vec<_>>();

    let core_cmd_unix = format!("\"mkdir -p .bcr/core && curl -L https://github.com/bazelbuild/rules_rust/releases/download/{0}/rules_rust-{0}.tar.gz | tar -xz -C .bcr/core && echo 'common --override_module=rules_rust=.bcr/core' > user.bazelrc\"", env!("RULES_RUST_VERSION"));
    let core_cmd_windows = format!("\"(if not exist .bcr\\\\core mkdir .bcr\\\\core) && curl -L https://github.com/bazelbuild/rules_rust/releases/download/{0}/rules_rust-{0}.tar.gz | tar -xz -C .bcr\\\\core && echo common --override_module=rules_rust=.bcr/core > user.bazelrc\"", env!("RULES_RUST_VERSION"));

    let cmds = [core_cmd_unix, core_cmd_windows];

    for rlocationpath in rlocationpaths {
        let path = runfiles::rlocation!(r, rlocationpath).unwrap();
        let content = std::fs::read_to_string(path).unwrap();
        for cmd in &cmds {
            assert!(
                content.contains(cmd),
                "{} did not contain the expected vendor command:\n{}",
                rlocationpath,
                cmd
            );
        }
    }
}
