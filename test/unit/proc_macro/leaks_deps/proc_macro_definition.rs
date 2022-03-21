use proc_macro::TokenStream;

#[proc_macro]
pub fn make_double_forty_two(_item: TokenStream) -> TokenStream {
    ("fn double_forty_two() -> i32 { 2 * proc_macro_dep::forty_two() }")
        .parse()
        .unwrap()
}
