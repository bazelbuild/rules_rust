#[proc_macro_derive(NoOpMacro)]
pub fn no_op_macro(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    input
}