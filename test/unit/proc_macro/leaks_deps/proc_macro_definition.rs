use proc_macro::TokenStream;
use proc_macro_dep::forty_two;

#[proc_macro]
pub fn make_double_forty_two(_item: TokenStream) -> TokenStream {
    let return_value = forty_two().to_string();
    ("fn double_forty_two() -> i32 { 2 * ".to_string() + &return_value + " }")
        .parse()
        .unwrap()
}
