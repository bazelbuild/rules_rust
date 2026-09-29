use proc_macro::TokenStream;

/// Returns the input unchanged; this crate exercises explicit proc-macro lints.
#[proc_macro]
pub fn identity(input: TokenStream) -> TokenStream {
    input
}
