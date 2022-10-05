use std::iter;
use std::vec;

use aho_corasick::AhoCorasick;
use lazy_static::lazy_static;
use proc_macro2::{Span, TokenStream};
use quote::quote_spanned;
use syn::parse::{Parse, ParseStream};
use syn::{Error, Ident, Lit, LitStr, Result, Token};

/// The possible renaming modes for this macro.
pub enum Mode {
    /// No renaming will be done; the expansion will replace each label with
    /// just the target.
    NoRenaming,
    /// First-party crates will be renamed, and third-party crates will not be.
    /// The expansion will replace first-party labels with an encoded version,
    /// and third-party labels with just their target.
    RenameFirstPartyCrates { third_party_dir: String },
}

/// A special case of label::Label, which must be absolute and must not specify
/// a repository.
#[derive(Debug, PartialEq, Eq)]
pub struct AbsoluteLabel<'s> {
    package_name: &'s str,
    name: &'s str,
}

impl<'s> AbsoluteLabel<'s> {
    /// Parses a string as an absolute Bazel label. Labels must be for the
    /// current repository.
    pub fn parse(label: &'s str, span: &'s Span) -> Result<Self> {
        if let Ok(label::Label {
            repository_name: None,
            package_name: Some(package_name),
            name,
        }) = label::analyze(label)
        {
            Ok(AbsoluteLabel { package_name, name })
        } else {
            Err(Error::new(
                *span,
                "Bazel labels must be of the form '//package[:target]'",
            ))
        }
    }

    /// Returns true iff this label should be renamed.
    fn should_rename(&self, mode: &Mode) -> bool {
        match mode {
            Mode::NoRenaming => false,
            Mode::RenameFirstPartyCrates { third_party_dir } => {
                !self.package_name.starts_with(third_party_dir)
            }
        }
    }

    /// Returns the appropriate (encoded) alias to use, if this label is being
    /// renamed; otherwise, returns None.
    fn target_as_alias(&self, mode: &Mode) -> Option<String> {
        self.should_rename(mode).then(|| encode(self.name))
    }

    /// Returns the full crate name, encoded if necessary.
    pub fn crate_name(&self, mode: &Mode) -> String {
        if self.should_rename(mode) {
            encode(&format!("{}:{}", self.package_name, self.name))
        } else {
            self.name.to_string()
        }
    }
}

lazy_static! {
    // The (unencoded, encoded) pairings here must match those in
    // //rust/private/utils.bzl exactly.
    static ref ENCODINGS: Vec<(&'static str, &'static str)> =
            vec![
                    (":", "x"),
                    ("!", "excl"),
                    ("%", "prc"),
                    ("@", "ao"),
                    ("^", "caret"),
                    ("`", "bt"),
                    (" ", "sp"),
                    ("\"", "dq"),
                    ("#", "octo"),
                    ("$", "dllr"),
                    ("&", "amp"),
                    ("'", "sq"),
                    ("(", "lp"),
                    (")", "rp"),
                    ("*", "astr"),
                    ("-", "d"),
                    ("+", "pl"),
                    (",", "cm"),
                    (";", "sm"),
                    ("<", "la"),
                    ("=", "eq"),
                    (">", "ra"),
                    ("?", "qm"),
                    ("[", "lbk"),
                    ("]", "rbk"),
                    ("{", "lbe"),
                    ("|", "pp"),
                    ("}", "rbe"),
                    ("~", "td"),
                    ("/", "y"),
                    (".", "pd"),
            ];

    // Transformations are stored as "(unencoded, encoded)" tuples.
    // Target names can include:
    // !%-@^_` "#$&'()*-+,;<=>?[]{|}~/.
    //
    // Package names are alphanumeric, plus [_/-].
    //
    // Packages and targets are separated by colons.
    static ref SUBSTITUTIONS: (Vec<String>, Vec<String>) =
        iter::once(("_z".to_string(), "_zz_".to_string()))
        .chain(ENCODINGS.iter()
            .flat_map(|pair| {
                vec![
                    (format!("_{}_", &pair.1), format!("_z{}_", &pair.1)),
                    (pair.0.to_string(), format!("_{}_", &pair.1)),
                ].into_iter()
            })
        )
        .unzip();

    static ref ENCODER: AhoCorasick = AhoCorasick::new(&SUBSTITUTIONS.0);
    static ref DECODER: AhoCorasick = AhoCorasick::new(&SUBSTITUTIONS.1);
}

/// Encodes a string using the above encoding scheme.
fn encode(s: &str) -> String {
    ENCODER.replace_all(s, &SUBSTITUTIONS.1)
}

struct Import {
    label: LitStr,
    alias: Option<Ident>,
}

impl Import {
    fn try_into_statement(self, mode: &Mode) -> Result<proc_macro2::TokenStream> {
        let label_literal = &self.label.value();
        let span = self.label.span();
        let label = AbsoluteLabel::parse(label_literal, &span)?;
        let crate_name = &label.crate_name(mode);

        let crate_ident = Ident::new(crate_name, span);
        let alias = self
            .alias
            .or_else(|| {
                label
                    .target_as_alias(mode)
                    .map(|alias| Ident::new(&alias, span))
            })
            .filter(|alias| alias != crate_name);

        Ok(if let Some(alias) = alias {
            quote_spanned! {span=> extern crate #crate_ident as #alias; }
        } else {
            quote_spanned! {span=> extern crate #crate_ident;}
        })
    }
}

pub struct ImportMacroInput {
    imports: Vec<Import>,
}

impl Parse for ImportMacroInput {
    fn parse(input: ParseStream) -> Result<Self> {
        let mut imports: Vec<Import> = Vec::new();

        while !input.is_empty() {
            let label = match Lit::parse(input)
                .map_err(|_| input.error("expected Bazel label as a string literal"))?
            {
                Lit::Str(label) => label,
                lit => {
                    return Err(input.error(format!(
                        "expected Bazel label as string literal, found '{}' literal",
                        quote::quote! {#lit}
                    )));
                }
            };
            let alias = if input.peek(Token![as]) {
                <Token![as]>::parse(input)?;
                Some(
                    Ident::parse(input)
                        .map_err(|_| input.error("alias must be a valid Rust identifier"))?,
                )
            } else {
                None
            };
            imports.push(Import { label, alias });
            <syn::Token![;]>::parse(input)?;
        }

        Ok(Self { imports })
    }
}

pub fn expand_imports(
    input: ImportMacroInput,
    mode: &Mode,
) -> std::result::Result<TokenStream, Vec<syn::Error>> {
    let (statements, errs): (Vec<_>, Vec<_>) = input
        .imports
        .into_iter()
        .map(|i| i.try_into_statement(mode))
        .partition(Result::is_ok);

    if !errs.is_empty() {
        Err(errs.into_iter().map(Result::unwrap_err).collect())
    } else {
        Ok(statements.into_iter().map(Result::unwrap).collect())
    }
}

#[cfg(test)]
mod tests {
    use crate::*;
    use quickcheck::quickcheck;
    use syn::parse_quote;

    /// Decodes a string that was encoded using `encode`.
    fn decode(s: &str) -> String {
        DECODER.replace_all(s, &SUBSTITUTIONS.0)
    }

    #[test]
    fn test_expand_imports_without_renaming() -> std::result::Result<(), Vec<syn::Error>> {
        let mode = Mode::NoRenaming;

        // Nothing to do.
        let expanded = expand_imports(parse_quote! {}, &mode)?;
        assert_eq!(expanded.to_string(), "");

        // Package and a target.
        let expanded = expand_imports(parse_quote! { "//some_project:utils"; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate utils ;");

        // Package and a target, with a no-op alias.
        let expanded = expand_imports(parse_quote! { "//some_project:utils"; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate utils ;");

        // Package and a target, with an alias.
        let expanded = expand_imports(parse_quote! { "//some_project:utils" as my_utils; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate utils as my_utils ;");

        // Package and an implicit target.
        let expanded = expand_imports(parse_quote! { "//some_project/utils"; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate utils ;");

        // Package and an implicit target, with a no-op alias.
        let expanded = expand_imports(parse_quote! { "//some_project/utils" as utils; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate utils ;");

        // Package and an implicit target, with an alias.
        let expanded = expand_imports(parse_quote! { "//some_project:utils" as my_utils; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate utils as my_utils ;");

        // A third-party target.
        let expanded =
            expand_imports(parse_quote! { "//third_party/rust/serde/v1:serde"; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate serde ;");

        // A third-party target with a no-op alias.
        let expanded = expand_imports(
            parse_quote! { "//third_party/rust/serde/v1:serde" as serde; },
            &mode,
        )?;
        assert_eq!(expanded.to_string(), "extern crate serde ;");

        // A third-party target with an alias.
        let expanded = expand_imports(
            parse_quote! { "//third_party/rust/serde/v1:serde" as my_serde; },
            &mode,
        )?;
        assert_eq!(expanded.to_string(), "extern crate serde as my_serde ;");

        // Multiple targets.
        let expanded = expand_imports(
            parse_quote! { "//some_project:utils"; "//third_party/rust/serde/v1:serde"; },
            &mode,
        )?;
        assert_eq!(
            expanded.to_string(),
            "extern crate utils ; extern crate serde ;"
        );

        Ok(())
    }

    #[test]
    fn test_expand_imports_with_renaming() -> std::result::Result<(), Vec<syn::Error>> {
        let mode = Mode::RenameFirstPartyCrates {
            third_party_dir: "third_party/rust".to_string(),
        };

        // Nothing to do.
        let expanded = expand_imports(parse_quote! {}, &mode)?;
        assert_eq!(expanded.to_string(), "");

        // Package and a target.
        let expanded = expand_imports(parse_quote! { "//some_project:utils"; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_x_utils as utils ;"
        );

        // Package and a target, with a no-op alias.
        let expanded = expand_imports(parse_quote! { "//some_project:utils" as utils; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_x_utils as utils ;"
        );

        // Package and a target, with an alias.
        let expanded = expand_imports(parse_quote! { "//some_project:utils" as my_utils; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_x_utils as my_utils ;"
        );

        // Package and an implicit target.
        let expanded = expand_imports(parse_quote! { "//some_project/utils"; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_y_utils_x_utils as utils ;"
        );

        // Package and an implicit target, with a no-op alias.
        let expanded = expand_imports(parse_quote! { "//some_project/utils" as utils; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_y_utils_x_utils as utils ;"
        );

        // Package and an implicit target, with an alias.
        let expanded = expand_imports(parse_quote! { "//some_project/utils" as my_utils; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_y_utils_x_utils as my_utils ;"
        );

        // A third-party target.
        let expanded =
            expand_imports(parse_quote! { "//third_party/rust/serde/v1:serde"; }, &mode)?;
        assert_eq!(expanded.to_string(), "extern crate serde ;");

        // A third-party target with a no-op alias.
        let expanded = expand_imports(
            parse_quote! { "//third_party/rust/serde/v1:serde" as serde; },
            &mode,
        )?;
        assert_eq!(expanded.to_string(), "extern crate serde ;");

        // A third-party target with an alias.
        let expanded = expand_imports(
            parse_quote! { "//third_party/rust/serde/v1:serde" as my_serde; },
            &mode,
        )?;
        assert_eq!(expanded.to_string(), "extern crate serde as my_serde ;");

        // Multiple targets.
        let expanded = expand_imports(
            parse_quote! { "//some_project:utils"; "//third_party/rust/serde/v1:serde"; },
            &mode,
        )?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_x_utils as utils ; extern crate serde ;"
        );

        // Problematic target name.
        let expanded = expand_imports(parse_quote! { "//some_project:thing-types"; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_x_thing_d_types as thing_d_types ;"
        );

        // Problematic target name with alias.
        let expanded = expand_imports(
            parse_quote! { "//some_project:thing-types" as types; },
            &mode,
        )?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_x_thing_d_types as types ;"
        );

        // Problematic package name.
        let expanded = expand_imports(parse_quote! { "//some_project-prototype:utils"; }, &mode)?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_d_prototype_x_utils as utils ;"
        );

        // Problematic package and target names.
        let expanded = expand_imports(
            parse_quote! { "//some_project-prototype:thing-types"; },
            &mode,
        )?;
        assert_eq!(
            expanded.to_string(),
            "extern crate some_project_d_prototype_x_thing_d_types as thing_d_types ;"
        );

        Ok(())
    }

    #[test]
    fn test_expansion_failures() -> Result<()> {
        let mode = Mode::NoRenaming;

        // Missing leading "//", not a valid label.
        let errs = expand_imports(parse_quote! { "some_project:utils"; }, &mode).unwrap_err();
        assert_eq!(
            errs.into_iter()
                .map(|e| e.to_string())
                .collect::<Vec<String>>(),
            vec!["Bazel labels must be of the form '//package[:target]'"]
        );

        // Valid label, but relative.
        let errs = expand_imports(parse_quote! { ":utils"; }, &mode).unwrap_err();
        assert_eq!(
            errs.into_iter()
                .map(|e| e.to_string())
                .collect::<Vec<String>>(),
            vec!["Bazel labels must be of the form '//package[:target]'"]
        );

        // Valid label, but a wildcard.
        let errs = expand_imports(parse_quote! { "some_project/..."; }, &mode).unwrap_err();
        assert_eq!(
            errs.into_iter()
                .map(|e| e.to_string())
                .collect::<Vec<String>>(),
            vec!["Bazel labels must be of the form '//package[:target]'"]
        );

        // Valid label, but only in Bazel (not in Bazel).
        let errs =
            expand_imports(parse_quote! { "@repository//some_project:utils"; }, &mode).unwrap_err();
        assert_eq!(
            errs.into_iter()
                .map(|e| e.to_string())
                .collect::<Vec<String>>(),
            vec!["Bazel labels must be of the form '//package[:target]'"]
        );

        Ok(())
    }

    #[test]
    fn test_macro_input_parsing_errors() -> Result<()> {
        // Label is not a string literal.
        assert_eq!(
            syn::parse_str::<ImportMacroInput>("some_project:utils;")
                .err()
                .unwrap()
                .to_string(),
            "expected Bazel label as a string literal"
        );

        // Label is the wrong kind of literal.
        assert_eq!(
            syn::parse_str::<ImportMacroInput>("true;")
                .err()
                .unwrap()
                .to_string(),
            "expected Bazel label as string literal, found 'true' literal"
        );
        assert_eq!(
            syn::parse_str::<ImportMacroInput>("123;")
                .err()
                .unwrap()
                .to_string(),
            "expected Bazel label as string literal, found '123' literal"
        );

        // Alias is not a valid identifier.
        assert_eq!(
            syn::parse_str::<ImportMacroInput>(r#""some_project:utils" as "!@#$%";"#)
                .err()
                .unwrap()
                .to_string(),
            "alias must be a valid Rust identifier"
        );

        Ok(())
    }

    #[test]
    fn test_label_parsing() -> Result<()> {
        assert_eq!(
            AbsoluteLabel::parse("//some_project:utils", &Span::call_site())?,
            AbsoluteLabel {
                package_name: "some_project",
                name: "utils"
            },
        );
        assert_eq!(
            AbsoluteLabel::parse("//some_project/utils", &Span::call_site())?,
            AbsoluteLabel {
                package_name: "some_project/utils",
                name: "utils"
            },
        );
        assert_eq!(
            AbsoluteLabel::parse("//some_project", &Span::call_site())?,
            AbsoluteLabel {
                package_name: "some_project",
                name: "some_project"
            },
        );

        Ok(())
    }

    #[test]
    fn test_substitutions_concatenate() -> Result<()> {
        // Every combination of orig + orig, orig + encoded, encoded + orig, and
        // encoded + encoded round trips the encoding successfully.
        for s in SUBSTITUTIONS.0.iter().chain(SUBSTITUTIONS.1.iter()) {
            for t in SUBSTITUTIONS.0.iter().chain(SUBSTITUTIONS.1.iter()) {
                let concatenated = format!("{}{}", s, t);
                assert_eq!(&decode(&encode(&concatenated)), &concatenated);
            }
        }

        Ok(())
    }

    #[test]
    fn test_encode() -> Result<()> {
        assert_eq!(encode("some_project:utils"), "some_project_x_utils");
        assert_eq!(&encode("_zpd_"), "_zz_pd_");

        // All the encodings should be what we expect.
        for (orig, encoded) in SUBSTITUTIONS.0.iter().zip(SUBSTITUTIONS.1.iter()) {
            assert_eq!(&encode(orig), encoded);
        }

        Ok(())
    }

    #[test]
    fn test_decode() -> Result<()> {
        assert_eq!(decode("some_project_x_utils"), "some_project:utils");
        assert_eq!(decode("_zz_pd_"), "_zpd_");

        // All the decodings should be what we expect.
        for (orig, encoded) in SUBSTITUTIONS.0.iter().zip(SUBSTITUTIONS.1.iter()) {
            assert_eq!(&decode(encoded), orig);
        }

        Ok(())
    }

    #[test]
    fn test_substitutions_compose() -> Result<()> {
        for s in SUBSTITUTIONS.0.iter().chain(SUBSTITUTIONS.1.iter()) {
            assert_eq!(&decode(&encode(s)), s);
        }

        Ok(())
    }

    quickcheck! {
        fn composition_is_identity(s: String) -> bool {
            s == decode(&encode(&s))
        }
    }
}
