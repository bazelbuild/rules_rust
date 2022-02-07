use syn::parse_macro_input;

fn mode() -> import_internal::Mode {
    match (
        std::env::var("RULES_RUST_RENAME_FIRST_PARTY_CRATES")
            .map_or(false, |s| s.parse::<bool>().unwrap_or(false)),
        std::env::var("RULES_RUST_THIRD_PARTY_DIR"),
    ) {
        (true, Ok(third_party_dir)) if !third_party_dir.is_empty() => {
            if let Some(stripped) = third_party_dir.strip_prefix("//") {
                import_internal::Mode::RenameFirstPartyCrates {
                    third_party_dir: stripped.into(),
                }
            } else {
                import_internal::Mode::NoRenaming
            }
        }
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
