use std::env;
use std::path::PathBuf;

use lttng_ust_generate::{Provider, Generator, CTFType, CIntegerType};

fn main() {
    let mut provider = Provider::new("my_first_rust_provider"); // stage 1
    provider.create_class("my_first_class") //stage 2
        .add_field("my_integer_field", CTFType::Integer(CIntegerType::I32))
        .add_field("my_string_field", CTFType::SequenceText)
        .instantiate("my_first_tracepoint"); // stage 3

    Generator::default()
        .generated_lib_name("tracepoint_library_link_name")
        .register_provider(provider)
        .output_file_name(PathBuf::from(env::var("OUT_DIR").unwrap()).join("tracepoints.rs"))
        .generate()
        .expect("Unable to generate tracepoint bindings");
}
