use proc_macro::TokenStream;

extern "C" {
    #[allow(dead_code)]
    fn native_dep() -> isize;
}
#[proc_macro_derive(UsingNativeDep)]
pub fn use_native_dep(_input: TokenStream) -> TokenStream {
    panic!("done")
}
