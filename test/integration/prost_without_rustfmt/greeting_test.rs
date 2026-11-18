//! Prost generates code for `greeting.proto` with no `rustfmt_toolchain`
//! resolved, so this compiles only if the codegen does not require one.

use greeting_proto::greeting::Greeting;

#[test]
fn generated_code_is_usable() {
    let greeting = Greeting {
        text: "hello".to_owned(),
    };
    assert_eq!(greeting.text, "hello");
}
