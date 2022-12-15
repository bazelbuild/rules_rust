fn main() {
    let cflags = std::env::var("CFLAGS").unwrap();
    assert!(cflags.contains("-target aarch64-linux-gnu.2.28"), "Expected CFLAGS to contain `-target aarch64-linux-gnu.2.28` because of zig toolchain but was `{}`", cflags);
    assert!(cflags.contains(" cbeep"), "Expected CFLAGS to contain ` cbeep` because of build_script_env but was `{}`", cflags);

    let cxxflags = std::env::var("CXXFLAGS").unwrap();
    assert!(cxxflags.contains("-target aarch64-linux-gnu.2.28"), "Expected CXXFLAGS to contain `-target aarch64-linux-gnu.2.28` because of zig toolchain but was `{}`", cxxflags);
    assert!(cxxflags.contains(" cxxbeep"), "Expected CXXFLAGS to contain ` cxxbeep` because of build_script_env but was `{}`", cxxflags);

    let ldflags = std::env::var("LDFLAGS").unwrap();
    assert!(ldflags.contains("-target aarch64-linux-gnu.2.28"), "Expected LDFLAGS to contain `-target aarch64-linux-gnu.2.28` because of zig toolchain but was `{}`", ldflags);
    assert!(ldflags.contains(" ldbeep"), "Expected LDFLAGS to contain ` ldbeep` because of build_script_env but was `{}`", ldflags);
}
