mod print_generic;

#[cfg(target_os = "linux")]
mod print_linux;

#[cfg(target_os = "macos")]
mod print_macos;

#[cfg(target_os = "windows")]
mod print_windows;

#[cfg(target_os = "linux")]
pub fn print() -> Vec<String> {
    vec![print_generic::print(), print_linux::print()]
}

#[cfg(target_os = "macos")]
pub fn print() -> Vec<String> {
    vec![print_generic::print(), print_macos::print()]
}

#[cfg(target_os = "windows")]
pub fn print() -> Vec<String> {
    vec![print_generic::print(), print_windows::print()]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn prints_correctly() {
        let outs = print();

        assert_eq!(
            outs,
            vec![
                "Hello Generic!",
                #[cfg(target_os = "linux")]
                "Hello Linux!",
                #[cfg(target_os = "macos")]
                "Hello MacOS!",
                #[cfg(target_os = "windows")]
                "Hello Windows!",
            ]
        );
    }
}
