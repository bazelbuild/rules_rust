// This differs from the edition 2015 version because it does not have an `extern proc_macro`
// statement, which became optional in edition 2018.

use proc_macro::TokenStream;

/// This macro is a no-op; it is exceedingly simple as a result
/// of avoiding dependencies on both the syn and quote crates.
#[proc_macro_derive(HelloWorld)]
pub fn hello_world(_input: TokenStream) -> TokenStream {
    TokenStream::new()
}
