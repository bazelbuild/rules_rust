#[cfg(test)]
mod tests {
    #[test]
    fn build_script_ran() {
        assert_eq!(env!("FROM_BUILD_SCRIPT"), "ok");
    }
}
