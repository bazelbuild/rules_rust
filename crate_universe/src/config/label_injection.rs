//! Apply per-annotation `label_injections` to the raw config JSON before it is
//! deserialized into typed structures.
//!
//! Each annotation may carry a `label_injections` object that maps a canonical
//! repository prefix (e.g. `@@xz~v1.2.3`) to the apparent repository prefix
//! the user wrote in the annotation (e.g. `@xz`). Keys and values are bare
//! repo prefixes — no `//pkg:target` suffix — because the rewrite below is a
//! plain substring `replace`, and appending a target would cause double-`//`
//! mangling on user references like `@xz//:lzma`. The map is produced by
//! `sanitize_label_injections` in `crate_universe/private/common_utils.bzl`,
//! which is the only place the apparent → canonical resolution is available.
//!
//! Here we apply that map by walking every string under each annotation and
//! replacing apparent occurrences with their canonical form. Any `//pkg:target`
//! the user wrote after the apparent repo prefix is preserved verbatim. The
//! `label_injections` field is consumed and removed before typed
//! deserialization sees the annotation.

use std::collections::BTreeMap;

use serde_json::{Map, Value};

/// Locates `annotations` in the parsed config JSON and applies each
/// annotation's `label_injections` to itself, removing the field in the
/// process. No-op if `annotations` is absent or empty.
pub(super) fn apply(config: &mut Value) {
    let Some(annotations) = config.get_mut("annotations").and_then(Value::as_object_mut) else {
        return;
    };

    for annotation in annotations.values_mut() {
        apply_to_annotation(annotation);
    }
}

fn apply_to_annotation(annotation: &mut Value) {
    let Some(obj) = annotation.as_object_mut() else {
        return;
    };

    let Some(injections) = obj.remove("label_injections") else {
        return;
    };

    let mapping = into_mapping(injections);
    if mapping.is_empty() {
        return;
    }

    for value in obj.values_mut() {
        rewrite(value, &mapping);
    }
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
    // The mapping keys in these tests come from `sanitize_label_injections`
    // in `crate_universe/private/common_utils.bzl`. That helper takes
    // `{Label(canonical): apparent_string}` and produces
    // `{canonical_repo_prefix: apparent_string}`. The shape of the keys is
    // therefore "canonical repo with optional package/target", and the values
    // are the apparent labels the user wrote in their annotations. The Rust
    // pass below substitutes apparent → canonical.
    use super::*;
    use serde_json::json;

    fn run(mut config: Value) -> Value {
        apply(&mut config);
        config
    }

    #[test]
    fn no_annotations_is_noop() {
        let input = json!({"other": 1});
        assert_eq!(run(input.clone()), input);
    }

    #[test]
    fn missing_label_injections_is_noop() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {"deps": ["@crate_index//:foo"]}
            }
        });
        assert_eq!(run(input.clone()), input);
    }

    #[test]
    fn empty_label_injections_is_stripped() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {},
                    "deps": ["@crate_index//:foo"],
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {"deps": ["@crate_index//:foo"]}
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn substitutes_in_list_strings() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "build_script_data": ["@xz//:lzma"],
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "build_script_data": ["@@xz~v1.2.3//:lzma"],
                }
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn substitutes_in_dict_values() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "build_script_env": {"LZMA_BIN": "$(execpath @xz//:lzma)"},
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "build_script_env": {"LZMA_BIN": "$(execpath @@xz~v1.2.3//:lzma)"},
                }
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn substitutes_in_dict_keys() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "extra_aliased_targets": {"@xz//:lzma": "lzma_alias"},
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "extra_aliased_targets": {"@@xz~v1.2.3//:lzma": "lzma_alias"},
                }
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn substitutes_in_additive_build_file_content() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "additive_build_file_content": "rust_library(deps = [\"@xz//:lzma\"])",
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "additive_build_file_content":
                        "rust_library(deps = [\"@@xz~v1.2.3//:lzma\"])",
                }
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn substitutes_in_nested_select() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "deps": {
                        "common": ["@xz//:lzma"],
                        "selects": {
                            "@platforms//os:linux": ["@xz//:linux_only"]
                        }
                    }
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "deps": {
                        "common": ["@@xz~v1.2.3//:lzma"],
                        "selects": {
                            "@platforms//os:linux": ["@@xz~v1.2.3//:linux_only"]
                        }
                    }
                }
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn applies_multiple_mappings() {
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {
                        "@@xz~v1.2.3": "@xz",
                        "@@bzip2~v0.5": "@bzip2",
                    },
                    "build_script_data": ["@xz//:lzma", "@bzip2//:bz2"],
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "build_script_data": ["@@xz~v1.2.3//:lzma", "@@bzip2~v0.5//:bz2"],
                }
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn substitutes_in_build_script_env_with_select_and_location_expansion() {
        // The headline use case: a `build_script_env` that carries a
        // `$(execpath ...)` expansion of an apparent label, both at the
        // `common` level and under a platform `select`. Every nested string
        // must be rewritten.
        let input = json!({
            "annotations": {
                "lzma-sys 0.1.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
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
                }
            }
        });
        let expected = json!({
            "annotations": {
                "lzma-sys 0.1.0": {
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
                }
            }
        });
        assert_eq!(run(input), expected);
    }

    #[test]
    fn per_annotation_isolation() {
        // Mapping under one annotation must not leak into another.
        let input = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "label_injections": {"@@xz~v1.2.3": "@xz"},
                    "deps": ["@xz//:lzma"],
                },
                "serde 1.0.0": {
                    "deps": ["@xz//:lzma"],
                }
            }
        });
        let expected = json!({
            "annotations": {
                "tokio 1.0.0": {
                    "deps": ["@@xz~v1.2.3//:lzma"],
                },
                "serde 1.0.0": {
                    "deps": ["@xz//:lzma"],
                }
            }
        });
        assert_eq!(run(input), expected);
    }
}
