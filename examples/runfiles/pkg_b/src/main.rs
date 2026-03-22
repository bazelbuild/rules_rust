use pkg_b_library;

fn main() {
    pkg_a_library::invoke_say_hello_binary_with_path();
    pkg_a_library::invoke_say_hello_binary_with_env_var();
    // pkg_a_library::invoke_say_hello_with_late_join(); // This fails with bazel run, will be added in a follow up PR
    pkg_a_library::invoke_say_hello_with_late_join_parent();

    pkg_b_library::invoke_say_hello_binary_with_path();
    pkg_b_library::invoke_say_hello_binary_with_env_var();

    pkg_b_library::invoke_pkg_a_binary_with_path();
    pkg_b_library::invoke_pkg_a_binary_with_env_var();
    // pkg_b_library::invoke_pkg_a_binary_with_late_join(); // This fails with bazel run, will be added in a follow up PR
    pkg_b_library::invoke_pkg_a_binary_with_late_join_parent();
}
