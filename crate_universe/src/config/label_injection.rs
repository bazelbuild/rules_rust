//! Per-annotation `label_injections` handling, deferred to render time so the
//! lockfile stays apparent-only.
//!
//! Each annotation may carry a `label_injections` object that maps a canonical
//! repository prefix (e.g. `@@openssl+v3.5.5`) to the apparent repository
//! prefix the user wrote in the annotation (e.g. `@openssl`). Keys and values
//! are bare repo prefixes — no `//pkg:target` suffix — because the rewrite is
//! a plain substring `replace`, and appending a target would cause double-`//`
//! mangling on user references like `@openssl//:install`. The map is produced
//! by `sanitize_label_injections` in `crate_universe/private/common_utils.bzl`,
//! which is the only place the apparent -> canonical resolution is available.
//!
//! Resolution timing matters: the apparent -> canonical mapping is computed
//! fresh in Starlark on every extension evaluation, so it reflects whatever
//! `bazel_dep` / `single_version_override` / `multiple_version_override` the
//! ROOT module is currently asking for — not whatever was in effect when the
//! producing module last repinned. If we baked the canonical form into the
//! lockfile (or hashed it into the digest), root-level overrides would force
//! every consumer to repin the producer's lockfile to recover. That's
//! impossible for proper bzlmod consumers — the producer's lockfile lives in
//! a read-only registry cache.
//!
//! The flow this module enables:
//!
//!   1. [`extract_global_mapping`] removes each annotation's
//!      `label_injections` field at config-load time and merges them into a
//!      single global apparent -> canonical map. The Config keeps the user's
//!      apparent labels intact.
//!   2. The Context built from that Config — and then serialized into the
//!      lockfile — therefore contains apparent labels and is stable across
//!      consumer-side overrides.
//!   3. Just before rendering BUILD files, [`apply_mapping_to_value`] walks
//!      the (per-session, freshly-loaded) Context and rewrites every string
//!      using the current session's mapping.
//!
//! Conflicts (same apparent prefix mapping to two different canonicals across
//! annotations) are rejected — they only arise under
//! `multiple_version_override` with crossing `label_injections`, which has no
//! coherent single-substitution form.

use std::collections::BTreeMap;

use anyhow::{bail, Result};
use serde_json::{Map, Value};

use crate::utils::starlark::is_repo_name_byte;

/// Walk `config.annotations` and:
///
///   * strip each annotation's `label_injections` field (so typed
///     deserialization downstream doesn't see it);
///   * merge every mapping into one global apparent -> canonical map.
///
/// Returns the merged map (canonical-repo-prefix -> apparent-repo-prefix, the
/// same orientation [`apply_mapping_to_value`] expects). Empty if `annotations`
/// is absent or no annotation declared injections.
///
/// Fails if two annotations declare different canonicals for the same apparent
/// — that only happens when a root module is in `multiple_version_override`
/// territory AND has two crate annotations injecting different versions of the
/// same apparent name. There's no sound way to substitute one string into
/// both forms; the user must split the offending crates into separate hubs.
pub(super) fn extract_global_mapping(config: &mut Value) -> Result<BTreeMap<String, String>> {
    let Some(annotations) = config.get_mut("annotations").and_then(Value::as_object_mut) else {
        return Ok(BTreeMap::new());
    };

    // Inverse map (apparent -> canonical) used for conflict detection; the
    // returned map is canonical -> apparent, matching `apply_mapping_to_value`'s
    // iteration shape.
    let mut by_apparent: BTreeMap<String, String> = BTreeMap::new();
    let mut by_canonical: BTreeMap<String, String> = BTreeMap::new();

    for annotation in annotations.values_mut() {
        let Some(obj) = annotation.as_object_mut() else {
            continue;
        };
        let Some(injections) = obj.remove("label_injections") else {
            continue;
        };
        for (canonical, apparent) in into_mapping(injections) {
            if let Some(existing) = by_apparent.get(&apparent) {
                if existing != &canonical {
                    bail!(
                        "conflicting `label_injections` across annotations for \
                         apparent label `{apparent}`: `{existing}` vs `{canonical}`. \
                         This occurs when the root module pulls two versions of the \
                         same bazel_dep (e.g. via `multiple_version_override`) and \
                         crate_universe annotations from different modules each inject \
                         their own version. Move the conflicting crate into its own \
                         `crate.from_specs`/`crate.from_cargo` hub so each hub only \
                         sees one canonical."
                    );
                }
            }
            by_apparent.insert(apparent.clone(), canonical.clone());
            by_canonical.insert(canonical, apparent);
        }
    }

    Ok(by_canonical)
}

/// Substitute every apparent-label prefix in `value` with its canonical form,
/// using `mapping` (canonical -> apparent — the same shape returned by
/// [`extract_global_mapping`]). Recurses into objects and arrays; rewrites
/// both keys and values of objects (annotation fields like `extra_aliased_targets`
/// use labels as keys).
///
/// Idempotent if the mapping is stable — applying it a second time with the
/// same canonical strings on the LHS finds nothing to replace because the
/// apparent prefix no longer appears.
pub(crate) fn apply_mapping_to_value(value: &mut Value, mapping: &BTreeMap<String, String>) {
    if mapping.is_empty() {
        return;
    }
    rewrite(value, mapping);
}

fn into_mapping(value: Value) -> BTreeMap<String, String> {
    let Value::Object(obj) = value else {
        return BTreeMap::new();
    };
    obj.into_iter()
        .filter_map(|(canonical, apparent)| match apparent {
            Value::String(s) if !s.is_empty() && !canonical.is_empty() => Some((canonical, s)),
            _ => None,
        })
        .collect()
}

fn rewrite(value: &mut Value, mapping: &BTreeMap<String, String>) {
    match value {
        Value::String(s) => {
            *s = replace_all(s, mapping);
        }
        Value::Array(arr) => {
            for item in arr {
                rewrite(item, mapping);
            }
        }
        Value::Object(obj) => {
            // Keys may themselves be labels (e.g. `extra_aliased_targets`
            // entries, `build_script_env` keys). Rebuild the map so both keys
            // and values are rewritten.
            let entries: Vec<(String, Value)> = obj
                .iter_mut()
                .map(|(k, v)| {
                    rewrite(v, mapping);
                    (replace_all(k, mapping), std::mem::replace(v, Value::Null))
                })
                .collect();
            *obj = Map::with_capacity(entries.len());
            for (k, v) in entries {
                obj.insert(k, v);
            }
        }
        Value::Null | Value::Bool(_) | Value::Number(_) => {}
    }
}

fn replace_all(input: &str, mapping: &BTreeMap<String, String>) -> String {
    let mut out = input.to_owned();
    for (canonical, apparent) in mapping {
        out = replace_at_label_boundary(&out, apparent, canonical);
    }
    out
}

/// Replace `apparent` with `canonical` in `input`, but only at label-prefix
/// boundaries — i.e., where `apparent` is not preceded by another `@` and is
/// not followed by another repo-name character (or `@`).
///
/// Plain `str::replace` is wrong for two reasons that combine catastrophically:
///
///   1. `sanitize_label_injections` partitions on `//`, so a user-written
///      apparent of `@//pkg:tgt` reduces to a one-character apparent `@`.
///      Naive replace would rewrite every `@` in every string, including the
///      leading `@@` on already-canonical labels in the same Context (e.g.
///      from `override_target_lib`'s `attr.label` resolution), producing
///      `@@@@…` and failing the next `Label::from_str` on JSON roundtrip.
///
///   2. Even with a well-formed apparent like `@curl`, the substring also
///      appears at position 1 of the canonical `@@curl+v8.0.0`, so any
///      already-canonical occurrence in the same Context would be partially
///      mangled to `@@@curl+v8.0.0+v8.0.0`.
///
/// Anchoring on `//` alone would fix (1) and (2) for `@curl//:tgt`, but break
/// `$(execpath @curl)` — Bazel's location-expansion shorthand for the bare
/// repo, which never carries a `//`. So we anchor on a label-boundary instead:
///
///   * Skip if the character before the match is `@` — that's the inside of
///     a canonical `@@…` prefix, not a label boundary.
///   * Skip if the character after the match is a repo-name char (alphanum,
///     `_`, `-`, `.`, `+`, `~`) or `@` — that means the match is a prefix of
///     a longer repo name (`@curl` inside `@curlx` or `@curl+v8`), or the
///     run-up to a canonical `@@`.
///
/// One more wrinkle: when the apparent occurs in **bare-shorthand** position
/// (no `//` follows), Bazel re-expands the bare form to `<repo>//:<repo>` at
/// resolution time. The repo name in the canonical includes Bazel's `+`
/// suffix (e.g. `native_lib+`), but the target that actually exists in the
/// canonical repo's BUILD file is the user's original target name (e.g.
/// `native_lib`). So substituting `@native_lib` → `@@native_lib+` for a
/// bare-shorthand occurrence yields `@@native_lib+` which Bazel re-expands
/// to `@@native_lib+//:native_lib+` — a target that doesn't exist. The
/// bare-shorthand case is rewritten with an explicit
/// `<canonical>//:<apparent_target>` to preserve the apparent target name
/// (which always matches the apparent repo name and equals what the repo's
/// BUILD file actually defines).
fn replace_at_label_boundary(input: &str, apparent: &str, canonical: &str) -> String {
    debug_assert!(
        !apparent.is_empty(),
        "empty apparents are filtered by `into_mapping`",
    );
    // Fast path: skip the per-match scan (and the output allocation) when the
    // apparent doesn't occur at all. Mappings often have several entries and
    // most Context strings won't reference most of them.
    if !input.contains(apparent) {
        return input.to_owned();
    }
    // The bare-shorthand target preserved on bare matches. `apparent` is
    // usually `@<name>`, in which case `strip_prefix('@')` yields the
    // bare repo name; for the degenerate `apparent = "@"` (which arises
    // from a user-written `label_injections` value of `@//pkg:tgt` —
    // see `does_not_mangle_at_signs_outside_repo_boundary`), the strip
    // yields `""`, and the bare-shorthand emission below skips itself.
    let apparent_target = apparent.strip_prefix('@').unwrap_or(apparent);

    let bytes = input.as_bytes();
    let mut out = String::with_capacity(input.len());
    let mut last_end = 0;
    for (start, _) in input.match_indices(apparent) {
        if start > 0 && bytes[start - 1] == b'@' {
            continue;
        }
        let after = start + apparent.len();
        if matches!(bytes.get(after), Some(&n) if n == b'@' || is_repo_name_byte(n)) {
            continue;
        }
        out.push_str(&input[last_end..start]);
        out.push_str(canonical);
        // Bare-shorthand expansion: when the apparent isn't followed by `//`,
        // re-emit the apparent target name explicitly. See the doc comment.
        // Skip when the apparent has no name (`@` alone): there's no target
        // to derive, and emitting `<canonical>//:` would be malformed.
        if !input[after..].starts_with("//") && !apparent_target.is_empty() {
            out.push_str("//:");
            out.push_str(apparent_target);
        }
        last_end = after;
    }
    out.push_str(&input[last_end..]);
    out
}

#[cfg(test)]
mod tests {
    // Mapping keys come from `sanitize_label_injections` in
    // `crate_universe/private/common_utils.bzl`. That helper takes
    // `{Label(apparent): apparent_string}` and produces
    // `{canonical_repo_prefix: apparent_repo_prefix}` (the Label coercion is
    // where Starlark resolves apparent -> canonical for the current session).
    // Substitution here rewrites apparent -> canonical.
    use std::str::FromStr;

    use super::*;
    use crate::utils::starlark::Label;
    use serde_json::json;

    // ---- extract_global_mapping ----

    #[test]
    fn returns_empty_when_no_annotations() {
        let mut input = json!({"other": 1});
        let mapping = extract_global_mapping(&mut input).unwrap();
        assert!(mapping.is_empty());
        assert_eq!(input, json!({"other": 1}));
    }

    #[test]
    fn returns_empty_when_no_annotation_declares_injections() {
        let mut input = json!({
            "annotations": {
                "tokio 1.0.0": {"deps": ["@crate_index//:foo"]}
            }
        });
        let mapping = extract_global_mapping(&mut input).unwrap();
        assert!(mapping.is_empty());
        // Input untouched — nothing to strip.
        assert_eq!(
            input,
            json!({"annotations": {"tokio 1.0.0": {"deps": ["@crate_index//:foo"]}}}),
        );
    }

    #[test]
    fn strips_empty_label_injections_field() {
        let mut input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {},
                    "deps": ["@crate_index//:foo"],
                }
            }
        });
        let mapping = extract_global_mapping(&mut input).unwrap();
        assert!(mapping.is_empty());
        // The (empty) label_injections field is stripped so typed deserialization
        // doesn't trip over it; remaining strings are NOT substituted (deferred).
        assert_eq!(
            input,
            json!({"annotations": {"tokio 1.0.0": {"deps": ["@crate_index//:foo"]}}}),
        );
    }

    #[test]
    fn merges_compatible_per_annotation_maps_into_one_global_map() {
        let mut input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "deps": ["@xz//:lzma"],
                },
                "rustls 0.21.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "deps": ["@xz//:liblzma"],
                }
            }
        });
        let mapping = extract_global_mapping(&mut input).unwrap();
        assert_eq!(
            mapping,
            BTreeMap::from([("@@xz~v1.2.3".to_owned(), "@xz".to_owned())]),
        );
        // label_injections stripped from both annotations; per-annotation strings
        // are NOT rewritten here — that's apply_mapping_to_value's job at render
        // time so the lockfile stays apparent-only.
        assert_eq!(
            input,
            json!({
                "annotations": {
                    "tokio 1.0.0": {"deps": ["@xz//:lzma"]},
                    "rustls 0.21.0": {"deps": ["@xz//:liblzma"]},
                }
            }),
        );
    }

    #[test]
    fn rejects_two_annotations_pointing_one_apparent_at_different_canonicals() {
        // The only scenario this triggers is a root module in
        // `multiple_version_override` territory where two crate annotations
        // (from different bzlmod modules) each inject their own version of
        // the same apparent label. There's no coherent single substitution.
        let mut input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@openssl+v3.5.5": "@openssl"},
                    "deps": ["@openssl//:install"],
                },
                "rustls 0.21.0": {
                    "label_injections": {"@@openssl+v3.3.1": "@openssl"},
                    "deps": ["@openssl//:install"],
                }
            }
        });
        let err = extract_global_mapping(&mut input).unwrap_err();
        let msg = format!("{err:#}");
        assert!(msg.contains("conflicting `label_injections`"), "{msg}");
        assert!(msg.contains("@openssl"), "{msg}");
    }

    // ---- apply_mapping_to_value ----

    #[test]
    fn noop_when_mapping_empty() {
        let mut v = json!({"deps": ["@openssl//:install"]});
        apply_mapping_to_value(&mut v, &BTreeMap::new());
        assert_eq!(v, json!({"deps": ["@openssl//:install"]}));
    }

    #[test]
    fn substitutes_in_list_strings() {
        let mut v = json!(["@xz//:lzma"]);
        let mapping = BTreeMap::from([("@@xz~v1.2.3".to_owned(), "@xz".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(v, json!(["@@xz~v1.2.3//:lzma"]));
    }

    #[test]
    fn substitutes_in_dict_values() {
        let mut v = json!({"LZMA_BIN": "$(execpath @xz//:lzma)"});
        let mapping = BTreeMap::from([("@@xz~v1.2.3".to_owned(), "@xz".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(v, json!({"LZMA_BIN": "$(execpath @@xz~v1.2.3//:lzma)"}));
    }

    #[test]
    fn substitutes_in_dict_keys() {
        // `extra_aliased_targets` keys, build_script_env keys, etc. are labels
        // — the rewrite walks both keys and values.
        let mut v = json!({"@xz//:lzma": "lzma_alias"});
        let mapping = BTreeMap::from([("@@xz~v1.2.3".to_owned(), "@xz".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(v, json!({"@@xz~v1.2.3//:lzma": "lzma_alias"}));
    }

    #[test]
    fn substitutes_in_long_string_payloads() {
        // additive_build_file_content is a raw Starlark blob; substring
        // substitution still applies (and must not double-mangle the `//`).
        let mut v = json!("rust_library(deps = [\"@xz//:lzma\"])");
        let mapping = BTreeMap::from([("@@xz~v1.2.3".to_owned(), "@xz".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(v, json!("rust_library(deps = [\"@@xz~v1.2.3//:lzma\"])"));
    }

    #[test]
    fn substitutes_under_deep_nesting_with_selects() {
        // The headline shape: build_script_env carrying `$(execpath ...)` /
        // `$(rlocationpath ...)` expansions of apparent labels, both at the
        // `common` level and inside platform `selects`. Every nested string
        // (including those nested via Select dict keys) must be rewritten.
        let mut v = json!({
            "build_script_data": {
                "common": ["@xz//:lzma"],
                "selects": {
                    "@platforms//os:linux": ["@xz//:liblzma"]
                }
            },
            "build_script_env": {
                "common": {"LZMA_BIN": "$(execpath @xz//:lzma)"},
                "selects": {
                    "@platforms//os:linux": {
                        "LZMA_LIB": "$(rlocationpath @xz//:liblzma)"
                    }
                }
            }
        });
        let mapping = BTreeMap::from([("@@xz~v1.2.3".to_owned(), "@xz".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(
            v,
            json!({
                "build_script_data": {
                    "common": ["@@xz~v1.2.3//:lzma"],
                    "selects": {
                        "@platforms//os:linux": ["@@xz~v1.2.3//:liblzma"]
                    }
                },
                "build_script_env": {
                    "common": {"LZMA_BIN": "$(execpath @@xz~v1.2.3//:lzma)"},
                    "selects": {
                        "@platforms//os:linux": {
                            "LZMA_LIB": "$(rlocationpath @@xz~v1.2.3//:liblzma)"
                        }
                    }
                }
            }),
        );
    }

    #[test]
    fn applies_multiple_mapping_entries_in_one_pass() {
        let mut v = json!(["@xz//:lzma", "@bzip2//:bz2"]);
        let mapping = BTreeMap::from([
            ("@@xz~v1.2.3".to_owned(), "@xz".to_owned()),
            ("@@bzip2~v0.5".to_owned(), "@bzip2".to_owned()),
        ]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(v, json!(["@@xz~v1.2.3//:lzma", "@@bzip2~v0.5//:bz2"]));
    }

    #[test]
    fn rewrites_context_like_payload() {
        // Approximates how generate.rs uses the helper: substitution applied
        // to a Context JSON's per-crate fields just before rendering.
        let mut context = json!({
            "crates": {
                "openssl-sys 0.9.116": {
                    "common_attrs": {
                        "build_script_data": ["@openssl//:install"],
                        "build_script_env": {
                            "common": {"OPENSSL_DIR": "$(execpath @openssl//:install)"}
                        },
                    }
                }
            }
        });
        let mapping = BTreeMap::from([("@@openssl+v3.5.5".to_owned(), "@openssl".to_owned())]);
        apply_mapping_to_value(&mut context, &mapping);
        assert_eq!(
            context,
            json!({
                "crates": {
                    "openssl-sys 0.9.116": {
                        "common_attrs": {
                            "build_script_data": ["@@openssl+v3.5.5//:install"],
                            "build_script_env": {
                                "common": {"OPENSSL_DIR": "$(execpath @@openssl+v3.5.5//:install)"}
                            },
                        }
                    }
                }
            }),
        );
    }

    #[test]
    fn does_not_mangle_at_signs_outside_repo_boundary() {
        // Regression: `sanitize_label_injections` partitions on `//` and so
        // reduces an apparent value of `@//pkg:target` (a label in the root
        // module, written with the explicit-apparent `@//` prefix) to just
        // `@`. A naive `str::replace` would then rewrite every `@` in the
        // Context — including the leading `@@` of already-canonical labels —
        // producing invalid strings like `@@@@rules_rust++crate+crate_index//:heapless`
        // that fail to parse on the JSON roundtrip back into Context.
        let mut v = json!({
            "override_targets": {
                "lib": "@@rules_rust++crate+crate_index//:heapless"
            },
            "deps": ["@//pkg:tgt"]
        });
        let mapping = BTreeMap::from([("@@".to_owned(), "@".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(
            v,
            json!({
                "override_targets": {
                    "lib": "@@rules_rust++crate+crate_index//:heapless"
                },
                "deps": ["@@//pkg:tgt"]
            }),
            "anchored substitution must rewrite `@//pkg:tgt` but leave the \
             unrelated `@@…//:` canonical untouched",
        );
    }

    #[test]
    fn substitutes_bare_repo_shorthand_in_location_expansion() {
        // `$(execpath @curl)` is Bazel's location-expansion shorthand for
        // `@curl//:curl` (no `//` separator). The label-boundary anchor must
        // still rewrite the `@curl` in this position, and must emit the
        // EXPLICIT canonical form `@@curl+v8.0.0//:curl` rather than the bare
        // `@@curl+v8.0.0` — Bazel would re-expand the bare canonical to
        // `@@curl+v8.0.0//:curl+v8.0.0` whose target name doesn't exist
        // (see `expands_bare_repo_shorthand_to_apparent_target` below for
        // the same shape in `deps`). The same mapping must NOT match
        // `@curl` at position 1 of an already-canonical `@@curl+v8.0.0//:curl`
        // (preceded by `@`), and must NOT match the prefix of a longer repo
        // name like `@curlx//:foo`.
        let mut v = json!({
            "build_script_env": {
                "common": {
                    "CURL_BIN": "$(execpath @curl)",
                    "CURL_LIB": "$(execpath @curl//:lib)",
                }
            },
            "deps": [
                "@curl",
                "@curl//:curl",
                "@@curl+v8.0.0//:curl",
                "@curlx//:foo",
            ]
        });
        let mapping = BTreeMap::from([("@@curl+v8.0.0".to_owned(), "@curl".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(
            v,
            json!({
                "build_script_env": {
                    "common": {
                        "CURL_BIN": "$(execpath @@curl+v8.0.0//:curl)",
                        "CURL_LIB": "$(execpath @@curl+v8.0.0//:lib)",
                    }
                },
                "deps": [
                    "@@curl+v8.0.0//:curl",
                    "@@curl+v8.0.0//:curl",
                    "@@curl+v8.0.0//:curl",
                    "@curlx//:foo",
                ]
            }),
        );
    }

    #[test]
    fn does_not_corrupt_canonical_when_apparent_is_its_prefix() {
        // Direct regression for the field-reported failure
        // `Failed to parse label from string: @@@rules_rust_pyo3++//:current_pyo3_toolchain`.
        //
        // Setup: `bazel_dep(name = "rules_rust_pyo3", version = "0.71.0")`
        // resolves to canonical `@@rules_rust_pyo3+`. The annotation has
        // `label_injections = {"@rules_rust_pyo3//...": "@rules_rust_pyo3//..."}`
        // so the sanitized mapping is `{"@@rules_rust_pyo3+": "@rules_rust_pyo3"}`.
        //
        // The annotation also references the same target in two shapes that
        // coexist in the same Context:
        //
        //   * `build_script_data` is `attr.string_list`-typed, preserved
        //     verbatim — value is the apparent `@rules_rust_pyo3//:…`.
        //   * `build_script_toolchains` is `attr.label_list`-typed, so
        //     Bazel resolves each entry to a Label and the JSON we receive
        //     already has the canonical form `@@rules_rust_pyo3+//:…`.
        //
        // The boundary-blind `str::replace` shipped in 0.71.0 found the
        // apparent at position 1 of the already-canonical string and
        // produced `@@@rules_rust_pyo3++//:current_pyo3_toolchain` — three
        // `@`s and the canonical's trailing `+` glued onto the input's `+`.
        // The downstream `serde_json::from_value` then tried to parse it as
        // a `Label` and surfaced the user-visible error.
        let mut v = json!({
            "build_script_data": [
                "@rules_rust_pyo3//:current_pyo3_toolchain"
            ],
            "build_script_toolchains": [
                "@@rules_rust_pyo3+//:current_pyo3_toolchain"
            ],
        });
        let mapping = BTreeMap::from([(
            "@@rules_rust_pyo3+".to_owned(),
            "@rules_rust_pyo3".to_owned(),
        )]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(
            v,
            json!({
                "build_script_data": [
                    "@@rules_rust_pyo3+//:current_pyo3_toolchain"
                ],
                "build_script_toolchains": [
                    "@@rules_rust_pyo3+//:current_pyo3_toolchain"
                ],
            }),
            "apparent in the apparent-form field must rewrite to canonical; \
             the already-canonical field must be left untouched",
        );

        // Tie the test directly to the user-visible failure mode: every
        // string in the rewritten Value must parse back as a `Label`. The
        // 0.71.0 bug surfaced inside `Context::apply_label_injection_mapping`'s
        // `serde_json::from_value` roundtrip, which uses exactly this
        // parser. If anyone reintroduces the substitution bug, this
        // assertion fails with the same `Failed to parse label from string:
        // @@@…` text that was reported in the field.
        for arr_key in ["build_script_data", "build_script_toolchains"] {
            for s in v[arr_key].as_array().unwrap() {
                Label::from_str(s.as_str().unwrap()).unwrap_or_else(|e| {
                    panic!("rewritten value {s} must parse as Label, got: {e:#}")
                });
            }
        }
    }

    #[test]
    fn expands_bare_repo_shorthand_to_apparent_target() {
        // Regression for the bare-shorthand-in-`deps` failure:
        // `no such target '@@native_lib+//:native_lib+': target 'native_lib+' not declared`.
        //
        // Setup: a `bazel_dep(name = "native_lib", ...)` resolves to
        // canonical `@@native_lib+`. The annotation is:
        //
        //     crate.annotation(
        //         crate = "some-sys",
        //         label_injections = {"@native_lib": "@native_lib"},
        //         deps = ["@native_lib"],
        //     )
        //
        // Sanitized mapping: `{"@@native_lib+": "@native_lib"}`. The
        // `"@native_lib"` in `deps` is Bazel's bare-shorthand form for
        // `@native_lib//:native_lib`.
        //
        // The fix must not substitute that to just `@@native_lib+` — Bazel
        // would then re-expand the bare canonical to
        // `@@native_lib+//:native_lib+`, and the target name `native_lib+`
        // doesn't exist in the canonical repo's BUILD file (which defines
        // `native_lib`, because `+` is part of the canonical-repo-name
        // suffix, not the user's target name). The substitution must emit
        // the explicit `@@native_lib+//:native_lib` form, preserving the
        // apparent target name.
        let mut v = json!({
            "deps": ["@native_lib"],
        });
        let mapping = BTreeMap::from([("@@native_lib+".to_owned(), "@native_lib".to_owned())]);
        apply_mapping_to_value(&mut v, &mapping);
        assert_eq!(
            v,
            json!({
                "deps": ["@@native_lib+//:native_lib"],
            }),
        );

        // The rewritten label must round-trip through `Label::from_str` —
        // i.e. it must be syntactically valid — and crucially must have
        // target name `native_lib` (the user's intended target), not the
        // canonical-name suffix `native_lib+` (which is what Bazel would
        // derive from a bare canonical re-expansion).
        let parsed =
            Label::from_str(v["deps"][0].as_str().unwrap()).expect("rewritten label must parse");
        assert_eq!(
            parsed.target(),
            "native_lib",
            "explicit `//:native_lib` target preserves the apparent target name; \
             the canonical-derived target `native_lib+` would not exist in the BUILD file",
        );
    }
}
