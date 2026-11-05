"""Analysis tests for allocator_library platform selection"""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")

def _allocator_library_provides_ccinfo_test_impl(env, target):
    # Basic test: ensure the target provides CcInfo (this means it analyzed successfully)
    env.expect.that_target(target).has_provider(CcInfo)

    # The fact that this test passes means the select() logic worked correctly
    # and didn't fail due to missing WASI toolchain tools

def _allocator_library_analysis_test(name):
    # Create analysis test rule that works without needing WASI toolchain
    # Test that allocator_library can be analyzed successfully
    # This indirectly tests that our WASI select() fix works
    analysis_test(
        name = name,
        impl = _allocator_library_provides_ccinfo_test_impl,
        target = "//ffi/cc/allocator_library:allocator_library",
    )

def allocator_library_test_suite(name):
    """Test suite for allocator_library platform behavior"""
    test_suite(
        name = name,
        tests = [
            _allocator_library_analysis_test,
        ],
    )
