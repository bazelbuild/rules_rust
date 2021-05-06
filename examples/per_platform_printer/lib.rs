mod print_generic;

#[cfg(target_os = "linux")]
mod print_linux;

#[cfg(target_os = "macos")]
mod print_osx;

pub fn print() -> Vec<String> {
    let mut outs = vec![print_generic::print()];

    #[cfg(target_os = "linux")]
    outs.push(print_linux::print());

    #[cfg(target_os = "macos")]
    outs.push(print_osx::print());

    outs
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
                "Hello OSX!",
            ]
        );
    }
}
