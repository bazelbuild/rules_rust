struct DropMarker(std::path::PathBuf);

impl Drop for DropMarker {
    fn drop(&mut self) {
        std::fs::write(&self.0, "unwound").unwrap();
    }
}

fn main() {
    let value = native::linked_value();
    assert_eq!(value, 73);
    println!("linked={value}");

    // Adding native shared-library inputs must preserve the panic runtime
    // selected by rustc, including the default unwind behavior.
    let _marker = DropMarker(std::env::args_os().nth(1).unwrap().into());
    panic!("controlled panic");
}
