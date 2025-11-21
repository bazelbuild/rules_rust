//! A cross platform implementation of `/bin/false`

fn main() {
    eprintln!(concat!("No binary provided for ", env!("BINARY_ENV")));
    std::process::exit(1);
}
