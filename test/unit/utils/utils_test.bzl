""" Unit tests for functions defined in utils.bzl. """

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")

# buildifier: disable=bzl-visibility
load("//rust/private:utils.bzl", "decode_crate_name_as_label_for_testing", "encode_label_as_crate_name", "should_encode_label_in_crate_name")

def _encode_label_as_crate_name_test_impl(ctx):
    env = unittest.begin(ctx)

    # Typical cases.
    asserts.equals(
        env,
        "x_slash_y_colon_z",
        encode_label_as_crate_name("x/y", "z"),
    )
    asserts.equals(
        env,
        "some_slash_package_colon_target",
        encode_label_as_crate_name("some/package", "target"),
    )

    # Target name includes a character illegal in crate names.
    asserts.equals(
        env,
        "some_slash_package_colon_foo_slash_target",
        encode_label_as_crate_name("some/package", "foo/target"),
    )

    # Package/target includes some of the encodings.
    asserts.equals(
        env,
        "some_quoteslash__slash_package_colon_target_quotedot_foo",
        encode_label_as_crate_name("some_slash_/package", "target_dot_foo"),
    )

    # Some pathological cases: test that round-tripping the encoding works as
    # expected.

    # Label includes a quoted encoding.
    package = "_quotedot_"
    target = "target"
    asserts.equals(env, "_quotequote_dot__colon_target", encode_label_as_crate_name(package, target))
    asserts.equals(env, package + ":" + target, decode_crate_name_as_label_for_testing(encode_label_as_crate_name(package, target)))

    package = "x_slash_y"
    target = "z"
    asserts.equals(env, "x_quoteslash_y_colon_z", encode_label_as_crate_name(package, target))
    asserts.equals(env, package + ":" + target, decode_crate_name_as_label_for_testing(encode_label_as_crate_name(package, target)))

    # Package is identical to a valid encoding already.
    package = "_quotequote_dot__colon_target"
    target = "target"
    asserts.equals(env, "_quotequote_quote_quotedot__quotecolon_target_colon_target", encode_label_as_crate_name(package, target))
    asserts.equals(env, package + ":" + target, decode_crate_name_as_label_for_testing(encode_label_as_crate_name(package, target)))
    return unittest.end(env)

def _is_third_party_crate_test_impl(ctx):
    env = unittest.begin(ctx)

    # A target at the root of the third-party dir is considered third-party:
    asserts.false(env, should_encode_label_in_crate_name("some_workspace", Label("//third_party:foo"), "//third_party"))

    # Targets in subpackages are detected properly:
    asserts.false(env, should_encode_label_in_crate_name("some_workspace", Label("//third_party/serde:serde"), "//third_party"))
    asserts.false(env, should_encode_label_in_crate_name("some_workspace", Label("//third_party/serde/v1:serde"), "//third_party"))

    # Ensure the directory name truly matches, and doesn't just include the
    # third-party dir as a substring (or vice versa).
    asserts.true(env, should_encode_label_in_crate_name("some_workspace", Label("//third_party_decoy:thing"), "//third_party"))
    asserts.true(env, should_encode_label_in_crate_name("some_workspace", Label("//decoy_third_party:thing"), "//third_party"))
    asserts.true(env, should_encode_label_in_crate_name("some_workspace", Label("//third_:thing"), "//third_party"))
    asserts.true(env, should_encode_label_in_crate_name("some_workspace", Label("//third_party_decoy/serde:serde"), "//third_party"))

    # Targets in rules_rust's repo should never be renamed.
    asserts.false(env, should_encode_label_in_crate_name("rules_rust", Label("//some_package:foo"), "//third_party"))

    return unittest.end(env)

encode_label_as_crate_name_test = unittest.make(_encode_label_as_crate_name_test_impl)
is_third_party_crate_test = unittest.make(_is_third_party_crate_test_impl)

def utils_test_suite(name):
    unittest.suite(
        name,
        encode_label_as_crate_name_test,
        is_third_party_crate_test,
    )
