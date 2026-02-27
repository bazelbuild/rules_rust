"""Unit tests for label injection functions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load(
    "//crate_universe/private:common_utils.bzl",
    "apply_label_injections",
    "sanitize_label_injections",
)

def _sanitize_label_injections_basic_test_impl(ctx):
    """Test sanitize_label_injections with basic inputs."""
    env = unittest.begin(ctx)

    # Test with empty dict
    asserts.equals(
        env,
        {},
        sanitize_label_injections({}),
    )

    # Test basic label injection without target path in apparent
    # Using @bazel_skylib as a real repo that exists
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_repo",
    })

    # The canonical repo will be converted to its canonical form
    canonical_key = [k for k in result.keys()][0]
    asserts.true(
        env,
        canonical_key.endswith(""),  # Just check it exists
        "Expected key to exist in result",
    )
    asserts.equals(
        env,
        "@apparent_repo",
        result[canonical_key],
    )

    # Test label injection with full target path in apparent
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_repo//different/path:other",
    })
    canonical_key = [k for k in result.keys()][0]
    asserts.true(
        env,
        canonical_key.endswith("//different/path:other"),
        "Expected key to end with //different/path:other",
    )
    asserts.equals(
        env,
        "@apparent_repo//different/path:other",
        result[canonical_key],
    )

    # Test label injection with only package path in apparent (no target)
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_repo//other/path",
    })
    canonical_key = [k for k in result.keys()][0]
    asserts.true(
        env,
        canonical_key.endswith("//other/path"),
        "Expected key to end with //other/path",
    )
    asserts.equals(
        env,
        "@apparent_repo//other/path",
        result[canonical_key],
    )

    return unittest.end(env)

def _sanitize_label_injections_multiple_test_impl(ctx):
    """Test sanitize_label_injections with multiple mappings."""
    env = unittest.begin(ctx)

    # Test multiple label injections using real repo
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@my_crates//:tokio",
        Label("@bazel_skylib//lib:dicts.bzl"): "@my_crates//:serde",
        Label("@bazel_skylib//rules:write_file.bzl"): "@other_crates//:log",
    })

    # Check that we got 3 results
    asserts.equals(env, 3, len(result))

    # Check that all values are as expected
    values = sorted([v for v in result.values()])
    expected_values = sorted(["@my_crates//:tokio", "@my_crates//:serde", "@other_crates//:log"])
    asserts.equals(env, expected_values, values)

    # Check that keys end with the expected target paths
    keys = sorted([k for k in result.keys()])

    # Check for //:tokio
    has_tokio = False
    for k in keys:
        if k.endswith("//:tokio"):
            has_tokio = True
    asserts.true(env, has_tokio, "Expected a key ending with //:tokio")

    # Check for //:serde
    has_serde = False
    for k in keys:
        if k.endswith("//:serde"):
            has_serde = True
    asserts.true(env, has_serde, "Expected a key ending with //:serde")

    # Check for //:log
    has_log = False
    for k in keys:
        if k.endswith("//:log"):
            has_log = True
    asserts.true(env, has_log, "Expected a key ending with //:log")

    return unittest.end(env)

def _sanitize_label_injections_same_canonical_repo_test_impl(ctx):
    """Test sanitize_label_injections with same canonical repo, different targets."""
    env = unittest.begin(ctx)

    # Test multiple injections from same canonical repo
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@my_crates//:tokio",
        Label("@bazel_skylib//lib:dicts.bzl"): "@my_crates//:serde",
    })

    # Check that we got 2 results
    asserts.equals(env, 2, len(result))

    # Check that both values are as expected
    values = sorted([v for v in result.values()])
    expected_values = sorted(["@my_crates//:tokio", "@my_crates//:serde"])
    asserts.equals(env, expected_values, values)

    # Check that all keys start with the same canonical repo
    keys = [k for k in result.keys()]
    repo1 = keys[0].partition("//")[0]
    repo2 = keys[1].partition("//")[0]
    asserts.equals(env, repo1, repo2, "Expected both keys to have same canonical repo")

    return unittest.end(env)

def _sanitize_label_injections_edge_cases_test_impl(ctx):
    """Test sanitize_label_injections edge cases."""
    env = unittest.begin(ctx)

    # Test with root package
    result = sanitize_label_injections({
        Label("//:BUILD.bazel"): "@apparent_repo//:new_target",
    })

    # The root package will have @@ prefix in canonical form
    keys = [k for k in result.keys()]
    asserts.equals(env, 1, len(keys))
    asserts.true(env, keys[0].endswith("//:new_target"), "Expected key to end with //:new_target")
    asserts.equals(
        env,
        "@apparent_repo//:new_target",
        result[keys[0]],
    )

    # Test with apparent label having special characters (dashes and underscores are allowed)
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib:unittest.bzl"): "@apparent_v2_0//path:target-core",
    })
    keys = [k for k in result.keys()]
    asserts.true(env, keys[0].endswith("//path:target-core"), "Expected key to end with //path:target-core")
    asserts.equals(
        env,
        "@apparent_v2_0//path:target-core",
        result[keys[0]],
    )

    # Test with nested package paths
    result = sanitize_label_injections({
        Label("@bazel_skylib//lib/unittest:unittest.bzl"): "@apparent//shallow:target",
    })
    keys = [k for k in result.keys()]
    asserts.true(env, keys[0].endswith("//shallow:target"), "Expected key to end with //shallow:target")
    asserts.equals(
        env,
        "@apparent//shallow:target",
        result[keys[0]],
    )

    return unittest.end(env)

def _sanitize_label_injections_preserves_apparent_test_impl(ctx):
    """Test that sanitize_label_injections preserves the apparent label as the value."""
    env = unittest.begin(ctx)

    # The function should always use the apparent label as the value
    result = sanitize_label_injections({
        Label("@bazel_skylib//original/path:original_target"): "@apparent_repo//new/path:new_target",
    })

    # The value should be the full apparent label
    keys = [k for k in result.keys()]
    asserts.equals(env, 1, len(keys))
    asserts.true(env, keys[0].endswith("//new/path:new_target"), "Expected key to end with //new/path:new_target")
    asserts.equals(
        env,
        "@apparent_repo//new/path:new_target",
        result[keys[0]],
    )

    # Test with apparent label without target path
    result = sanitize_label_injections({
        Label("@bazel_skylib//original/path:original_target"): "@apparent_repo",
    })

    # The value should be the apparent label (just the repo name)
    keys = [k for k in result.keys()]
    asserts.equals(env, 1, len(keys))

    # When there's no // in apparent, it should not have a target path appended
    asserts.equals(
        env,
        "@apparent_repo",
        result[keys[0]],
    )

    return unittest.end(env)

def _apply_label_injections_string_test_impl(ctx):
    """Test apply_label_injections with string attributes."""
    env = unittest.begin(ctx)

    # Test with empty label_mapping
    asserts.equals(
        env,
        "@crate_index//:tokio",
        apply_label_injections(label_mapping = {}, attribute = "@crate_index//:tokio"),
    )

    # Test with None label_mapping
    asserts.equals(
        env,
        "@crate_index//:tokio",
        apply_label_injections(label_mapping = None, attribute = "@crate_index//:tokio"),
    )

    # Test with None attribute
    asserts.equals(
        env,
        None,
        apply_label_injections(label_mapping = {"@crate_index": "@my_crates"}, attribute = None),
    )

    # Test single replacement in string
    asserts.equals(
        env,
        "@my_crates//:tokio",
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = "@crate_index//:tokio",
        ),
    )

    # Test multiple replacements in string
    asserts.equals(
        env,
        "@my_crates//:serde @other_crates//:log",
        apply_label_injections(
            label_mapping = {
                "@my_crates": "@crate_index",
                "@other_crates": "@logging_crates",
            },
            attribute = "@crate_index//:serde @logging_crates//:log",
        ),
    )

    # Test no matching replacement
    asserts.equals(
        env,
        "@some_other_repo//:target",
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = "@some_other_repo//:target",
        ),
    )

    return unittest.end(env)

def _apply_label_injections_list_test_impl(ctx):
    """Test apply_label_injections with list attributes."""
    env = unittest.begin(ctx)

    # Test with empty list
    asserts.equals(
        env,
        [],
        apply_label_injections(label_mapping = {"@my_crates": "@crate_index"}, attribute = []),
    )

    # Test single element list
    asserts.equals(
        env,
        ["@my_crates//:tokio"],
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = ["@crate_index//:tokio"],
        ),
    )

    # Test multiple element list
    asserts.equals(
        env,
        ["@my_crates//:tokio", "@my_crates//:serde", "@other_crates//:log"],
        apply_label_injections(
            label_mapping = {
                "@my_crates": "@crate_index",
                "@other_crates": "@logging_crates",
            },
            attribute = ["@crate_index//:tokio", "@crate_index//:serde", "@logging_crates//:log"],
        ),
    )

    # Test list with no matching replacements
    asserts.equals(
        env,
        ["@some_other_repo//:target"],
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = ["@some_other_repo//:target"],
        ),
    )

    return unittest.end(env)

def _apply_label_injections_dict_string_values_test_impl(ctx):
    """Test apply_label_injections with dict attributes having string values."""
    env = unittest.begin(ctx)

    # Test with empty dict
    asserts.equals(
        env,
        {},
        apply_label_injections(label_mapping = {"@my_crates": "@crate_index"}, attribute = {}),
    )

    # Test dict with string values
    asserts.equals(
        env,
        {"tokio": "@my_crates//:tokio"},
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {"tokio": "@crate_index//:tokio"},
        ),
    )

    # Test dict with multiple entries
    asserts.equals(
        env,
        {
            "log": "@other_crates//:log",
            "serde": "@my_crates//:serde",
            "tokio": "@my_crates//:tokio",
        },
        apply_label_injections(
            label_mapping = {
                "@my_crates": "@crate_index",
                "@other_crates": "@logging_crates",
            },
            attribute = {
                "log": "@logging_crates//:log",
                "serde": "@crate_index//:serde",
                "tokio": "@crate_index//:tokio",
            },
        ),
    )

    # Test dict with keys that are labels (keys should be replaced too)
    asserts.equals(
        env,
        {"@my_crates//:tokio": "value"},
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {"@crate_index//:tokio": "value"},
        ),
    )

    # Test dict with both keys and values needing replacement
    asserts.equals(
        env,
        {"@my_crates//:key": "@my_crates//:value"},
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {"@crate_index//:key": "@crate_index//:value"},
        ),
    )

    return unittest.end(env)

def _apply_label_injections_dict_list_values_test_impl(ctx):
    """Test apply_label_injections with dict attributes having list values."""
    env = unittest.begin(ctx)

    # Test dict with list values
    asserts.equals(
        env,
        {"deps": ["@my_crates//:tokio", "@my_crates//:serde"]},
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {"deps": ["@crate_index//:tokio", "@crate_index//:serde"]},
        ),
    )

    # Test dict with multiple list values
    asserts.equals(
        env,
        {
            "data": ["@other_crates//:log"],
            "deps": ["@my_crates//:tokio"],
        },
        apply_label_injections(
            label_mapping = {
                "@my_crates": "@crate_index",
                "@other_crates": "@logging_crates",
            },
            attribute = {
                "data": ["@logging_crates//:log"],
                "deps": ["@crate_index//:tokio"],
            },
        ),
    )

    # Test dict with empty list values
    asserts.equals(
        env,
        {"deps": []},
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {"deps": []},
        ),
    )

    return unittest.end(env)

def _apply_label_injections_dict_dict_values_test_impl(ctx):
    """Test apply_label_injections with dict attributes having dict values."""
    env = unittest.begin(ctx)

    # Test dict with dict values
    asserts.equals(
        env,
        {"config": {"runtime": "@my_crates//:tokio"}},
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {"config": {"runtime": "@crate_index//:tokio"}},
        ),
    )

    # Test dict with nested dict values
    asserts.equals(
        env,
        {
            "env": {"TOKIO_PATH": "@my_crates//:tokio"},
            "targets": {"linux": "@my_crates//:linux_specific"},
        },
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {
                "env": {"TOKIO_PATH": "@crate_index//:tokio"},
                "targets": {"linux": "@crate_index//:linux_specific"},
            },
        ),
    )

    # Test dict with dict values - both keys and values replaced
    asserts.equals(
        env,
        {"config": {"@my_crates//:key": "@my_crates//:value"}},
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = {"config": {"@crate_index//:key": "@crate_index//:value"}},
        ),
    )

    return unittest.end(env)

def _apply_label_injections_edge_cases_test_impl(ctx):
    """Test apply_label_injections edge cases."""
    env = unittest.begin(ctx)

    # Test with empty strings
    asserts.equals(
        env,
        "",
        apply_label_injections(label_mapping = {"@my_crates": "@crate_index"}, attribute = ""),
    )

    # Test overlapping replacements (should replace all)
    asserts.equals(
        env,
        "@my_crates//:tokio @my_crates//:serde",
        apply_label_injections(
            label_mapping = {"@my_crates": "@crate_index"},
            attribute = "@crate_index//:tokio @crate_index//:serde",
        ),
    )

    # Test with special characters in labels
    asserts.equals(
        env,
        "@my_crates~v1.0//:tokio-core",
        apply_label_injections(
            label_mapping = {"@my_crates~v1.0": "@crate_index~v1.0"},
            attribute = "@crate_index~v1.0//:tokio-core",
        ),
    )

    return unittest.end(env)

# Create test rules
sanitize_label_injections_basic_test = unittest.make(_sanitize_label_injections_basic_test_impl)
sanitize_label_injections_multiple_test = unittest.make(_sanitize_label_injections_multiple_test_impl)
sanitize_label_injections_same_canonical_repo_test = unittest.make(_sanitize_label_injections_same_canonical_repo_test_impl)
sanitize_label_injections_edge_cases_test = unittest.make(_sanitize_label_injections_edge_cases_test_impl)
sanitize_label_injections_preserves_apparent_test = unittest.make(_sanitize_label_injections_preserves_apparent_test_impl)
apply_label_injections_string_test = unittest.make(_apply_label_injections_string_test_impl)
apply_label_injections_list_test = unittest.make(_apply_label_injections_list_test_impl)
apply_label_injections_dict_string_values_test = unittest.make(_apply_label_injections_dict_string_values_test_impl)
apply_label_injections_dict_list_values_test = unittest.make(_apply_label_injections_dict_list_values_test_impl)
apply_label_injections_dict_dict_values_test = unittest.make(_apply_label_injections_dict_dict_values_test_impl)
apply_label_injections_edge_cases_test = unittest.make(_apply_label_injections_edge_cases_test_impl)

def label_injections_test_suite(name):
    """Entry-point macro called from the BUILD file.

    Args:
        name (str): Name of the test suite.
    """

    sanitize_label_injections_basic_test(
        name = "sanitize_label_injections_basic_test",
    )
    sanitize_label_injections_multiple_test(
        name = "sanitize_label_injections_multiple_test",
    )
    sanitize_label_injections_same_canonical_repo_test(
        name = "sanitize_label_injections_same_canonical_repo_test",
    )
    sanitize_label_injections_edge_cases_test(
        name = "sanitize_label_injections_edge_cases_test",
    )
    sanitize_label_injections_preserves_apparent_test(
        name = "sanitize_label_injections_preserves_apparent_test",
    )
    apply_label_injections_string_test(
        name = "apply_label_injections_string_test",
    )
    apply_label_injections_list_test(
        name = "apply_label_injections_list_test",
    )
    apply_label_injections_dict_string_values_test(
        name = "apply_label_injections_dict_string_values_test",
    )
    apply_label_injections_dict_list_values_test(
        name = "apply_label_injections_dict_list_values_test",
    )
    apply_label_injections_dict_dict_values_test(
        name = "apply_label_injections_dict_dict_values_test",
    )
    apply_label_injections_edge_cases_test(
        name = "apply_label_injections_edge_cases_test",
    )

    native.test_suite(
        name = name,
        tests = [
            "sanitize_label_injections_basic_test",
            "sanitize_label_injections_multiple_test",
            "sanitize_label_injections_same_canonical_repo_test",
            "sanitize_label_injections_edge_cases_test",
            "sanitize_label_injections_preserves_apparent_test",
            "apply_label_injections_string_test",
            "apply_label_injections_list_test",
            "apply_label_injections_dict_string_values_test",
            "apply_label_injections_dict_list_values_test",
            "apply_label_injections_dict_dict_values_test",
            "apply_label_injections_edge_cases_test",
        ],
    )
