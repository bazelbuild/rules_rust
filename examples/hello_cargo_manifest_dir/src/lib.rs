
pub fn get_included_str() -> &'static str {
    include_str!(concat!(env!("CARGO_MANIFEST_DIR"), "/include/included_file.rs.inc"))
}
