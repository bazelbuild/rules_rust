#[cfg(not(build_script_cfg))]
compile_error!("the binary must receive its build script's cfg flags");

include!(concat!(env!("OUT_DIR"), "/generated.rs"));

fn main() {
    assert_eq!(env!("BUILD_SCRIPT_VALUE"), GENERATED_VALUE);
}
