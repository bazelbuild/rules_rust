cfg_if::cfg_if! {
    if #[cfg(unix)] {
        pub const FAMILY: &str = "unix";
    } else {
        pub const FAMILY: &str = "other";
    }
}
