use std::env;
use std::path::PathBuf;

use lttng_ust_generate::{CIntegerType, CTFType, Generator, Provider};

fn main() {
    let mut provider = Provider::new("my_first_rust_provider"); // stage 1
    provider
        .create_class("my_first_class") //stage 2
        .add_field("my_integer_field", CTFType::Integer(CIntegerType::I32))
        .add_field("my_string_field", CTFType::SequenceText)
        .instantiate("my_first_tracepoint"); // stage 3

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    Generator::default()
        .generated_lib_name("tracepoint_library_link_name")
        .register_provider(provider)
        .output_file_name(out_path.join("tracepoints.rs"))
        .generate()
        .expect("Unable to generate tracepoint bindings");

    let output_path = out_path.join("tracepoints.rs");
    let generated = std::fs::read_to_string(&output_path).unwrap();
    let replacement = generated
        .replace(
            &format!(r#""{}"#, env::var("OUT_DIR").unwrap()),
            r#"concat!(env!("OUT_DIR"), ""#,
        )
        .replace(r#"tracepoints.rs""#, r#"tracepoints.rs")"#);
    std::fs::write(output_path, replacement.as_bytes()).unwrap();
}
