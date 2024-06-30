use std::borrow::Cow;
use std::collections::{BTreeMap, BTreeSet};

use anyhow::{anyhow, Context, Result};
use cfg_expr::targets::Abi;
use cfg_expr::targets::{
    get_builtin_target_by_triple, Arch, Endian, Families, HasAtomics, Os, Panic, TargetInfo,
    Triple, Vendor,
};
use cfg_expr::{Expression, Predicate};

// since we use binary_search_by on it, the array must be sorted.
// NOTE: can be removed once, the visionos target is added to cfg_expr
pub const TARGET_INFO: &[TargetInfo] = &[
    TargetInfo {
        triple: Triple::new_const("aarch64-apple-visionos"),
        os: Some(Os(Cow::Borrowed("visionos"))),
        abi: None,
        arch: Arch::aarch64,
        env: None,
        vendor: Some(Vendor::apple),
        families: Families::unix,
        pointer_width: 64,
        endian: Endian::little,
        has_atomics: HasAtomics::atomic_8_16_32_64_128_ptr,
        panic: Panic::unwind,
    },
    TargetInfo {
        triple: Triple::new_const("aarch64-apple-visionos-sim"),
        os: Some(Os(Cow::Borrowed("visionos"))),
        abi: Some(Abi::new_const("sim")),
        arch: Arch::aarch64,
        env: None,
        vendor: Some(Vendor::apple),
        families: Families::unix,
        pointer_width: 64,
        endian: Endian::little,
        has_atomics: HasAtomics::atomic_8_16_32_64_128_ptr,
        panic: Panic::unwind,
    },
];

use crate::context::CrateContext;
use crate::utils::target_triple::TargetTriple;

/// Walk through all dependencies in a [CrateContext] list for all configuration specific
/// dependencies to produce a mapping of configurations/Cargo target_triples to compatible
/// Bazel target_triples.  Also adds mappings for all known target_triples.
pub(crate) fn resolve_cfg_platforms(
    crates: Vec<&CrateContext>,
    supported_platform_triples: &BTreeSet<TargetTriple>,
) -> Result<BTreeMap<String, BTreeSet<TargetTriple>>> {
    // Collect all unique configurations from all dependencies into a single set
    let configurations: BTreeSet<String> = crates
        .iter()
        .flat_map(|ctx| {
            let attr = &ctx.common_attrs;
            let mut configurations = BTreeSet::new();

            configurations.extend(attr.deps.configurations());
            configurations.extend(attr.deps_dev.configurations());
            configurations.extend(attr.proc_macro_deps.configurations());
            configurations.extend(attr.proc_macro_deps_dev.configurations());

            // Chain the build dependencies if some are defined
            if let Some(attr) = &ctx.build_script_attrs {
                configurations.extend(attr.deps.configurations());
                configurations.extend(attr.proc_macro_deps.configurations());
            }

            configurations
        })
        .collect();

    // Generate target information for each triple string
    let target_infos = supported_platform_triples
        .iter()
        .map(|target_triple| {
            match get_builtin_target_by_triple(&target_triple.to_cargo()).or_else(|| {
                TARGET_INFO
                    .binary_search_by(|ti| ti.triple.as_ref().cmp(&target_triple.to_cargo()))
                    .map(|i| &TARGET_INFO[i])
                    .ok()
            }) {
                Some(info) => Ok((target_triple, info)),
                None => Err(anyhow!(
                    "Invalid platform triple in supported platforms: {}",
                    target_triple
                )),
            }
        })
        .collect::<Result<BTreeMap<&TargetTriple, &'static TargetInfo>>>()?;

    // `cfg-expr` does not understand configurations that are simply platform triples
    // (`x86_64-unknown-linux-gnu` vs `cfg(target = "x86_64-unkonwn-linux-gnu")`). So
    // in order to parse configurations, the text is renamed for the check but the
    // original is retained for comaptibility with the manifest.
    let rename = |cfg: &str| -> String { format!("cfg(target = \"{cfg}\")") };
    let original_cfgs: BTreeMap<String, String> = configurations
        .iter()
        .filter(|cfg| !cfg.starts_with("cfg("))
        .map(|cfg| (rename(cfg), cfg.clone()))
        .collect();

    let mut conditions = configurations
        .into_iter()
        // `cfg-expr` requires that the expressions be actual `cfg` expressions. Any time
        // there's a target triple (which is a valid constraint), convert it to a cfg expression.
        .map(|cfg| match cfg.starts_with("cfg(") {
            true => cfg,
            false => rename(&cfg),
        })
        // Check the current configuration with against each supported triple
        .map(|cfg| {
            let expression =
                Expression::parse(&cfg).context(format!("Failed to parse expression: '{cfg}'"))?;

            let triples = target_infos
                .iter()
                .filter(|(_, target_info)| {
                    expression.eval(|p| match p {
                        Predicate::Target(tp) => tp.matches(**target_info),
                        Predicate::KeyValue { key, val } => {
                            *key == "target" && val == &target_info.triple.as_str()
                        }
                        // For now there is no other kind of matching
                        _ => false,
                    })
                })
                .map(|(triple, _)| (*triple).clone())
                .collect();

            // Map any renamed configurations back to their original IDs
            let cfg = match original_cfgs.get(&cfg) {
                Some(orig) => orig.clone(),
                None => cfg,
            };

            Ok((cfg, triples))
        })
        .collect::<Result<BTreeMap<String, BTreeSet<TargetTriple>>>>()?;
    // Insert identity relationships.
    for target_triple in supported_platform_triples.iter() {
        conditions
            .entry(target_triple.to_bazel())
            .or_default()
            .insert(target_triple.clone());
    }
    Ok(conditions)
}

#[cfg(test)]
mod test {
    use crate::config::CrateId;
    use crate::context::crate_context::CrateDependency;
    use crate::context::CommonAttributes;
    use crate::select::Select;

    use super::*;

    const VERSION_ZERO_ONE_ZERO: semver::Version = semver::Version::new(0, 1, 0);

    fn supported_platform_triples() -> BTreeSet<TargetTriple> {
        BTreeSet::from([
            TargetTriple::from_bazel("aarch64-apple-darwin".to_owned()),
            TargetTriple::from_bazel("i686-apple-darwin".to_owned()),
            TargetTriple::from_bazel("x86_64-unknown-linux-gnu".to_owned()),
        ])
    }

    #[test]
    fn resolve_no_targeted() {
        let mut deps: Select<BTreeSet<CrateDependency>> = Select::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), VERSION_ZERO_ONE_ZERO),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            None,
        );

        let context = CrateContext {
            name: "mock_crate_a".to_owned(),
            version: VERSION_ZERO_ONE_ZERO,
            package_url: None,
            repository: None,
            targets: BTreeSet::default(),
            library_target_name: None,
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            build_script_attrs: None,
            license: None,
            license_ids: BTreeSet::default(),
            license_file: None,
            additive_build_file_content: None,
            disable_pipelining: false,
            extra_aliased_targets: BTreeMap::default(),
            alias_rule: None,
            override_targets: BTreeMap::default(),
        };

        let configurations =
            resolve_cfg_platforms(vec![&context], &supported_platform_triples()).unwrap();

        assert_eq!(
            configurations,
            BTreeMap::from([
                // All known triples.
                (
                    "aarch64-apple-darwin".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel("aarch64-apple-darwin".to_owned())]),
                ),
                (
                    "i686-apple-darwin".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel("i686-apple-darwin".to_owned())]),
                ),
                (
                    "x86_64-unknown-linux-gnu".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel(
                        "x86_64-unknown-linux-gnu".to_owned()
                    )]),
                ),
            ])
        )
    }

    fn mock_resolve_context(configuration: String) -> CrateContext {
        let mut deps: Select<BTreeSet<CrateDependency>> = Select::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), VERSION_ZERO_ONE_ZERO),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            Some(configuration),
        );

        CrateContext {
            name: "mock_crate_a".to_owned(),
            version: VERSION_ZERO_ONE_ZERO,
            package_url: None,
            repository: None,
            targets: BTreeSet::default(),
            library_target_name: None,
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            build_script_attrs: None,
            license: None,
            license_ids: BTreeSet::default(),
            license_file: None,
            additive_build_file_content: None,
            disable_pipelining: false,
            extra_aliased_targets: BTreeMap::default(),
            alias_rule: None,
            override_targets: BTreeMap::default(),
        }
    }

    #[test]
    fn resolve_targeted() {
        let data = BTreeMap::from([
            (
                r#"cfg(target = "x86_64-unknown-linux-gnu")"#.to_owned(),
                BTreeSet::from([TargetTriple::from_bazel(
                    "x86_64-unknown-linux-gnu".to_owned(),
                )]),
            ),
            (
                r#"cfg(any(target_os = "macos", target_os = "ios"))"#.to_owned(),
                BTreeSet::from([
                    TargetTriple::from_bazel("aarch64-apple-darwin".to_owned()),
                    TargetTriple::from_bazel("i686-apple-darwin".to_owned()),
                ]),
            ),
        ]);

        data.into_iter().for_each(|(configuration, expectation)| {
            let context = mock_resolve_context(configuration.clone());

            let configurations =
                resolve_cfg_platforms(vec![&context], &supported_platform_triples()).unwrap();

            assert_eq!(
                configurations,
                BTreeMap::from([
                    (configuration, expectation),
                    // All known triples.
                    (
                        "aarch64-apple-darwin".to_owned(),
                        BTreeSet::from([TargetTriple::from_bazel(
                            "aarch64-apple-darwin".to_owned()
                        )]),
                    ),
                    (
                        "i686-apple-darwin".to_owned(),
                        BTreeSet::from([TargetTriple::from_bazel("i686-apple-darwin".to_owned())]),
                    ),
                    (
                        "x86_64-unknown-linux-gnu".to_owned(),
                        BTreeSet::from([TargetTriple::from_bazel(
                            "x86_64-unknown-linux-gnu".to_owned()
                        )]),
                    ),
                ])
            );
        })
    }

    #[test]
    fn resolve_platforms() {
        let configuration = r#"x86_64-unknown-linux-gnu"#.to_owned();
        let mut deps: Select<BTreeSet<CrateDependency>> = Select::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), VERSION_ZERO_ONE_ZERO),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            Some(configuration.clone()),
        );

        let context = CrateContext {
            name: "mock_crate_a".to_owned(),
            version: VERSION_ZERO_ONE_ZERO,
            package_url: None,
            repository: None,
            targets: BTreeSet::default(),
            library_target_name: None,
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            build_script_attrs: None,
            license: None,
            license_ids: BTreeSet::default(),
            license_file: None,
            additive_build_file_content: None,
            disable_pipelining: false,
            extra_aliased_targets: BTreeMap::default(),
            alias_rule: None,
            override_targets: BTreeMap::default(),
        };

        let configurations =
            resolve_cfg_platforms(vec![&context], &supported_platform_triples()).unwrap();

        assert_eq!(
            configurations,
            BTreeMap::from([
                (
                    configuration,
                    BTreeSet::from([TargetTriple::from_bazel(
                        "x86_64-unknown-linux-gnu".to_owned()
                    )])
                ),
                // All known triples.
                (
                    "aarch64-apple-darwin".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel("aarch64-apple-darwin".to_owned())]),
                ),
                (
                    "i686-apple-darwin".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel("i686-apple-darwin".to_owned())]),
                ),
                (
                    "x86_64-unknown-linux-gnu".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel(
                        "x86_64-unknown-linux-gnu".to_owned()
                    )]),
                ),
            ])
        );
    }

    #[test]
    fn resolve_unsupported_targeted() {
        let configuration = r#"cfg(target = "x86_64-unknown-unknown")"#.to_owned();
        let mut deps: Select<BTreeSet<CrateDependency>> = Select::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), VERSION_ZERO_ONE_ZERO),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            Some(configuration.clone()),
        );

        let context = CrateContext {
            name: "mock_crate_a".to_owned(),
            version: VERSION_ZERO_ONE_ZERO,
            package_url: None,
            repository: None,
            targets: BTreeSet::default(),
            library_target_name: None,
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            build_script_attrs: None,
            license: None,
            license_ids: BTreeSet::default(),
            license_file: None,
            additive_build_file_content: None,
            disable_pipelining: false,
            extra_aliased_targets: BTreeMap::default(),
            alias_rule: None,
            override_targets: BTreeMap::default(),
        };

        let configurations =
            resolve_cfg_platforms(vec![&context], &supported_platform_triples()).unwrap();

        assert_eq!(
            configurations,
            BTreeMap::from([
                (configuration, BTreeSet::new()),
                // All known triples.
                (
                    "aarch64-apple-darwin".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel("aarch64-apple-darwin".to_owned())]),
                ),
                (
                    "i686-apple-darwin".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel("i686-apple-darwin".to_owned())]),
                ),
                (
                    "x86_64-unknown-linux-gnu".to_owned(),
                    BTreeSet::from([TargetTriple::from_bazel(
                        "x86_64-unknown-linux-gnu".to_owned()
                    )]),
                ),
            ])
        );
    }
}
