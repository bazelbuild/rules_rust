#[cfg(target_os = "linux")]
pub fn get_time() -> String {
    format!(
        "nix time: {}",
        nix::time::clock_getcpuclockid(nix::unistd::Pid::this())
            .and_then(nix::time::clock_gettime)
            .unwrap()
    )
}

#[cfg(not(target_os = "linux"))]
pub fn get_time() -> String {
    format!("other time: {:?}", std::time::SystemTime::now())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_time() {
        let time = get_time();
        #[cfg(target_os = "linux")]
        assert!(time.starts_with("nix time:"), "unexpected: {time}");
        #[cfg(not(target_os = "linux"))]
        assert!(time.starts_with("other time:"), "unexpected: {time}");
    }
}
