#[cfg(target_os = "linux")]
fn print_time() {
    println!(
        "nix time: {}",
        nix::time::clock_getcpuclockid(nix::unistd::Pid::this())
            .and_then(nix::time::clock_gettime)
            .unwrap()
    )
}

#[cfg(not(target_os = "linux"))]
fn print_time() {
    println!("other time: {:?}", std::time::SystemTime::now())
}

fn main() {
    print_time()
}
