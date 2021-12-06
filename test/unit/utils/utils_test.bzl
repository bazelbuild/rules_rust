""" Unit tests for functions defined in utils.bzl. """

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//rust/private:utils.bzl", "encode_label_as_crate_name", "should_encode_label_in_crate_name")

def _encode_label_as_crate_name_test_impl(ctx):
    env = unittest.begin(ctx)

    # Typical case:
    asserts.equals(
        env,
        "some_slash_package_colon_target",
        encode_label_as_crate_name("some/package", "target"),
    )

    # Target name includes a character illegal in crate names:
    asserts.equals(
        env,
        "some_slash_package_colon_foo_slash_target",
        encode_label_as_crate_name("some/package", "foo/target"),
    )

    # Package/target includes some of the substitutions:
    asserts.equals(
        env,
        "some_quoteslash__slash_package_colon_target_quotedot_foo",
        encode_label_as_crate_name("some_slash_/package", "target_dot_foo"),
    )
    return unittest.end(env)

def _is_third_party_crate_test_impl(ctx):
    env = unittest.begin(ctx)

    # A target at the root of the 3p dir is considered 3p:
    asserts.true(env, should_encode_label_in_crate_name("third_party", "//third_party"))

    # Targets in subpackages are detected properly:
    asserts.true(env, should_encode_label_in_crate_name("third_party/serde", "//third_party"))
    asserts.true(env, should_encode_label_in_crate_name("third_party/serde/v1", "//third_party"))

    # Ensure the directory name truly matches, and doesn't just include the
    # 3p dir as a substring (or vice versa).
    asserts.false(env, should_encode_label_in_crate_name("third_party_decoy", "//third_party"))
    asserts.false(env, should_encode_label_in_crate_name("decoy_third_party", "//third_party"))
    asserts.false(env, should_encode_label_in_crate_name("third_", "//third_party"))
    asserts.false(env, should_encode_label_in_crate_name("third_party_decoy/serde", "//third_party"))
    return unittest.end(env)

encode_label_as_crate_name_test = unittest.make(_encode_label_as_crate_name_test_impl)
is_third_party_crate_test = unittest.make(_is_third_party_crate_test_impl)

def utils_test_suite(name):
    unittest.suite(
        name,
        encode_label_as_crate_name_test,
        is_third_party_crate_test,
    )
