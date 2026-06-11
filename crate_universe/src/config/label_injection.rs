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
        if out.contains(apparent.as_str()) {
            out = out.replace(apparent.as_str(), canonical.as_str());
        }
    }
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
    use super::*;
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
}
