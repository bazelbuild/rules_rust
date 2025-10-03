use pkg_b_library;
use pkg_a_library;

#[test]
fn test_invoke_say_hello_binary_with_path() {
    pkg_b_library::invoke_say_hello_binary_with_path();
}

#[test]
fn test_invoke_say_hello_binary_with_env_var() {
    pkg_b_library::invoke_say_hello_binary_with_env_var();
}

#[test]
fn test_invoke_pkg_a_say_hello_binary_with_path() {
    pkg_a_library::invoke_say_hello_binary_with_path();
}

#[test]
fn test_invoke_pkg_a_say_hello_binary_with_env_var() {
    pkg_a_library::invoke_say_hello_binary_with_env_var();
}

#[test]
fn test_invoke_pkg_a_binary_with_path() {
    pkg_b_library::invoke_pkg_a_binary_with_path();
}

#[test]
fn test_invoke_pkg_a_binary_with_env_var() {
    pkg_b_library::invoke_pkg_a_binary_with_env_var();
}

#[test]
fn test_invoke_pkg_a_binary_with_late_join() {
    pkg_b_library::invoke_pkg_a_binary_with_late_join();
}

#[test]
fn test_invoke_pkg_a_binary_with_late_join_parent() {
    pkg_b_library::invoke_pkg_a_binary_with_late_join_parent();
}
