"""Unit tests for rust_toolchain_toml.bzl parser functions."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load(
    "//rust/private:rust_toolchain_toml.bzl",
    "normalize_toml_multiline_arrays",
    "parse_rust_toolchain_file",
    "parse_toml_list",
    "parse_toml_string",
)

def _parse_toml_string_test_impl(ctx):
    env = unittest.begin(ctx)

    # Basic string parsing
    asserts.equals(env, "1.86.0", parse_toml_string('channel = "1.86.0"'))
    asserts.equals(env, "nightly-2024-01-01", parse_toml_string('channel = "nightly-2024-01-01"'))

    # With extra whitespace
    asserts.equals(env, "1.86.0", parse_toml_string('channel   =   "1.86.0"'))

    # Single quotes
    asserts.equals(env, "1.86.0", parse_toml_string("channel = '1.86.0'"))

    # No equals sign
    asserts.equals(env, None, parse_toml_string("just a string"))

    return unittest.end(env)

def _parse_toml_list_test_impl(ctx):
    env = unittest.begin(ctx)

    # Basic list parsing
    asserts.equals(
        env,
        ["rustfmt", "clippy"],
        parse_toml_list('components = ["rustfmt", "clippy"]'),
    )

    # Single item
    asserts.equals(
        env,
        ["wasm32-unknown-unknown"],
        parse_toml_list('targets = ["wasm32-unknown-unknown"]'),
    )

    # Empty list
    asserts.equals(env, [], parse_toml_list("targets = []"))

    # With extra whitespace
    asserts.equals(
        env,
        ["a", "b", "c"],
        parse_toml_list('items = [ "a" , "b" , "c" ]'),
    )

    # No equals sign
    asserts.equals(env, [], parse_toml_list("not a list"))

    # Not a list value
    asserts.equals(env, [], parse_toml_list('key = "value"'))

    return unittest.end(env)

def _normalize_multiline_arrays_test_impl(ctx):
    env = unittest.begin(ctx)

    # Single-line array should be unchanged
    single_line = 'targets = ["a", "b"]'
    asserts.equals(env, single_line, normalize_toml_multiline_arrays(single_line))

    # Multi-line array should be collapsed
    multi_line = """components = [
  "rustfmt",
  "clippy",
]"""
    normalized = normalize_toml_multiline_arrays(multi_line)
    asserts.true(env, "components = [" in normalized)
    asserts.true(env, "]" in normalized)
    asserts.true(env, "\n" not in normalized or normalized.count("\n") == 0)

    # Verify the list can be parsed after normalization
    parsed = parse_toml_list(normalized)
    asserts.equals(env, ["rustfmt", "clippy"], parsed)

    # Mixed content
    mixed = """[toolchain]
channel = "1.86.0"
components = [
  "rustfmt",
  "clippy",
]
targets = ["wasm32-unknown-unknown"]"""
    normalized_mixed = normalize_toml_multiline_arrays(mixed)
    asserts.true(env, 'channel = "1.86.0"' in normalized_mixed)
    asserts.true(env, 'targets = ["wasm32-unknown-unknown"]' in normalized_mixed)

    return unittest.end(env)

def _parse_rust_toolchain_file_test_impl(ctx):
    env = unittest.begin(ctx)

    # Basic TOML format
    basic = """[toolchain]
channel = "1.86.0"
"""
    parsed = parse_rust_toolchain_file(basic)
    asserts.true(env, parsed != None, "Should parse basic TOML")
    asserts.equals(env, ["1.86.0"], parsed.versions)
    asserts.equals(env, [], parsed.extra_target_triples)
    asserts.equals(env, False, parsed.dev_components)

    # Full TOML with all fields
    full = """[toolchain]
channel = "1.92.0"
components = ["rustfmt", "clippy", "rustc-dev"]
targets = ["wasm32-unknown-unknown", "x86_64-unknown-linux-gnu"]
"""
    parsed_full = parse_rust_toolchain_file(full)
    asserts.true(env, parsed_full != None, "Should parse full TOML")
    asserts.equals(env, ["1.92.0"], parsed_full.versions)
    asserts.equals(
        env,
        ["wasm32-unknown-unknown", "x86_64-unknown-linux-gnu"],
        parsed_full.extra_target_triples,
    )
    asserts.equals(env, True, parsed_full.dev_components)

    # Multi-line arrays
    multiline = """[toolchain]
channel = "1.86.0"
components = [
  "rustfmt",
  "clippy",
]
targets = ["wasm32-unknown-unknown"]
"""
    parsed_multiline = parse_rust_toolchain_file(multiline)
    asserts.true(env, parsed_multiline != None, "Should parse multi-line arrays")
    asserts.equals(env, ["1.86.0"], parsed_multiline.versions)
    asserts.equals(env, ["wasm32-unknown-unknown"], parsed_multiline.extra_target_triples)

    # Simple format (just version string)
    simple = "1.86.0"
    parsed_simple = parse_rust_toolchain_file(simple)
    asserts.true(env, parsed_simple != None, "Should parse simple format")
    asserts.equals(env, ["1.86.0"], parsed_simple.versions)

    # With comments
    with_comments = """# This is a comment
[toolchain]
# Another comment
channel = "1.86.0"
"""
    parsed_comments = parse_rust_toolchain_file(with_comments)
    asserts.true(env, parsed_comments != None, "Should handle comments")
    asserts.equals(env, ["1.86.0"], parsed_comments.versions)

    # Invalid content (no version)
    invalid = """[toolchain]
components = ["rustfmt"]
"""
    parsed_invalid = parse_rust_toolchain_file(invalid)
    asserts.equals(env, None, parsed_invalid, "Should return None for invalid content")

    # Nightly channel
    nightly = """[toolchain]
channel = "nightly-2024-06-01"
"""
    parsed_nightly = parse_rust_toolchain_file(nightly)
    asserts.true(env, parsed_nightly != None)
    asserts.equals(env, ["nightly-2024-06-01"], parsed_nightly.versions)

    return unittest.end(env)

parse_toml_string_test = unittest.make(_parse_toml_string_test_impl)
parse_toml_list_test = unittest.make(_parse_toml_list_test_impl)
normalize_multiline_arrays_test = unittest.make(_normalize_multiline_arrays_test_impl)
parse_rust_toolchain_file_test = unittest.make(_parse_rust_toolchain_file_test_impl)

def rust_toolchain_toml_test_suite(name):
    unittest.suite(
        name,
        parse_toml_string_test,
        parse_toml_list_test,
        normalize_multiline_arrays_test,
        parse_rust_toolchain_file_test,
    )
