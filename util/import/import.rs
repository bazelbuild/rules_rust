use syn::parse_macro_input;

fn mode() -> import_internal::Mode {
    match std::env::var("RULES_RUST_THIRD_PARTY_DIR")
        .ok()
        .and_then(|dir| dir.strip_prefix("//").map(|s| s.to_string()))
    {
        Some(third_party_dir) => import_internal::Mode::RenameFirstPartyCrates { third_party_dir },
        _ => import_internal::Mode::NoRenaming,
    }
}

#[proc_macro]
pub fn import(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let input = parse_macro_input!(input as import_internal::ImportMacroInput);
    import_internal::expand_imports(input, &mode())
        .unwrap_or_else(|errors| errors.into_iter().map(|e| e.into_compile_error()).collect())
        .into()
}
