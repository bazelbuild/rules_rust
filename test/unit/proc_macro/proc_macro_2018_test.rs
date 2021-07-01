use proc_macro_lib_2018::HelloWorld;

#[derive(HelloWorld)]
struct TestStruct {}

#[test]
fn test_hello_world_macro() {
    let _ = TestStruct {};
}
