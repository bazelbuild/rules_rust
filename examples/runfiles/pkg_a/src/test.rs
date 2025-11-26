use pkg_a_library;

#[test]
fn test_invoke_say_hello_binary_with_path() {
    pkg_a_library::invoke_say_hello_binary_with_path();
}

#[test]
fn test_invoke_say_hello_binary_with_env_var() {
    pkg_a_library::invoke_say_hello_binary_with_env_var();
}

#[test]
fn test_invoke_say_hello_with_late_join() {
    pkg_a_library::invoke_say_hello_with_late_join();
}

#[test]
fn test_invoke_say_hello_with_late_join_parent() {
    pkg_a_library::invoke_say_hello_with_late_join_parent();
}
