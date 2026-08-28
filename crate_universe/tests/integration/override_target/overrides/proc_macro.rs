//! Stands in for the `paste` proc macro.
//!
//! `paste` has no `overridden` macro, so anything that expands it only
//! compiles when `crate.annotation(override_target_proc_macro = ...)` was
//! applied.

use proc_macro::TokenStream;

#[proc_macro]
pub fn overridden(_item: TokenStream) -> TokenStream {
    "true".parse().unwrap()
}
