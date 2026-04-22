extern crate proc_macro;
use proc_macro::TokenStream;

#[proc_macro]
pub fn noop(_item: TokenStream) -> TokenStream {
    TokenStream::new()
}
