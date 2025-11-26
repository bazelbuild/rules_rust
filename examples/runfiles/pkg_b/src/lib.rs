use runfiles::{rlocation, Runfiles};
use pkg_a_library::invoke_binary;

pub fn invoke_say_hello_binary_with_path() {
    let r = Runfiles::create().unwrap();
    let bin = rlocation!(r, "_main/pkg_a/say_hello").unwrap();
    println!("Invoking say_hello binary with path: {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_say_hello_binary_with_env_var() {
    let r = Runfiles::create().unwrap();
    let bin = rlocation!(r, env!("SAY_HELLO_BIN")).unwrap();
    println!("Invoking say_hello binary with env var: {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_pkg_a_binary_with_path() {
    let r = Runfiles::create().unwrap();
    let bin = rlocation!(r, "_main/pkg_a/pkg_a_binary").unwrap();
    println!("Invoking pkg_a binary with path: {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_pkg_a_binary_with_env_var() {
    let r = Runfiles::create().unwrap();
    let bin = rlocation!(r, env!("PKG_A_BINARY_BIN")).unwrap();
    println!("Invoking pkg_a binary with env var: {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_pkg_a_binary_with_late_join() {
    let r = Runfiles::create().unwrap();
    let bin_folder = rlocation!(r, "_main/pkg_a").unwrap();

    let bin = bin_folder.join("pkg_a_binary");
    println!("Invoking pkg_a binary with late join: {}", bin.display());

    invoke_binary(bin);
}

pub fn invoke_pkg_a_binary_with_late_join_parent() {
    let r = Runfiles::create().unwrap();
    let bin_folder = rlocation!(r, "_main/pkg_a/pkg_a_binary").unwrap();

    let bin = bin_folder.parent().unwrap().join("pkg_a_binary");
    println!("Invoking pkg_a binary with late join parent: {}", bin.display());

    invoke_binary(bin);
}
