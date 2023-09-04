use std::collections::{BTreeMap, BTreeSet};

use anyhow::{anyhow, Context, Result};
use cfg_expr::targets::{get_builtin_target_by_triple, TargetInfo};
use cfg_expr::{Expression, Predicate};

use crate::context::CrateContext;
use crate::utils::starlark::Select;

/// Walk through all dependencies in a [CrateContext] list for all configuration specific
/// dependencies to produce a mapping of configuration to compatible platform triples.
/// Also adds mappings for all known platform triples.
pub fn resolve_cfg_platforms(
    crates: Vec<&CrateContext>,
    supported_platform_triples: &BTreeSet<String>,
) -> Result<BTreeMap<String, BTreeSet<String>>> {
    // Collect all unique configurations from all dependencies into a single set
    let configurations: BTreeSet<String> = crates
        .iter()
        .flat_map(|ctx| {
            let attr = &ctx.common_attrs;
            attr.deps
                .configurations()
                .into_iter()
                .chain(attr.deps_dev.configurations())
                .chain(attr.proc_macro_deps.configurations())
                .chain(attr.proc_macro_deps_dev.configurations())
                // Chain the build dependencies if some are defined
                .chain(if let Some(attr) = &ctx.build_script_attrs {
                    attr.deps
                        .configurations()
                        .into_iter()
                        .chain(attr.proc_macro_deps.configurations())
                        .collect::<BTreeSet<Option<&String>>>()
                        .into_iter()
                } else {
                    BTreeSet::new().into_iter()
                })
                .flatten()
        })
        .cloned()
        .collect();

    // Generate target information for each triple string
    let target_infos = supported_platform_triples
        .iter()
        .map(|t| match get_builtin_target_by_triple(t) {
            Some(info) => Ok(info),
            None => Err(anyhow!(
                "Invalid platform triple in supported platforms: {}",
                t
            )),
        })
        .collect::<Result<Vec<&'static TargetInfo>>>()?;

    // `cfg-expr` does not understand configurations that are simply platform triples
    // (`x86_64-unknown-linux-gun` vs `cfg(target = "x86_64-unkonwn-linux-gnu")`). So
    // in order to parse configurations, the text is renamed for the check but the
    // original is retained for comaptibility with the manifest.
    let rename = |cfg: &str| -> String { format!("cfg(target = \"{cfg}\")") };
    let original_cfgs: BTreeMap<String, String> = configurations
        .iter()
        .filter(|cfg| !cfg.starts_with("cfg("))
        .map(|cfg| (rename(cfg), cfg.clone()))
        .collect();

    configurations
        .into_iter()
        // `cfg-expr` requires that the expressions be actual `cfg` expressions. Any time
        // there's a target triple (which is a valid constraint), convert it to a cfg expression.
        .map(|cfg| match cfg.starts_with("cfg(") {
            true => cfg.to_string(),
            false => rename(&cfg),
        })
        // Check the current configuration with against each supported triple
        .map(|cfg| {
            let expression =
                Expression::parse(&cfg).context(format!("Failed to parse expression: '{cfg}'"))?;

            let triples = target_infos
                .iter()
                .filter(|info| {
                    expression.eval(|p| match p {
                        Predicate::Target(tp) => tp.matches(**info),
                        Predicate::KeyValue { key, val } => {
                            *key == "target" && val == &info.triple.as_str()
                        }
                        // For now there is no other kind of matching
                        _ => false,
                    })
                })
                .map(|info| info.triple.to_string())
                .collect();

            // Map any renamed configurations back to their original IDs
            let cfg = match original_cfgs.get(&cfg) {
                Some(orig) => orig.clone(),
                None => cfg,
            };

            Ok((cfg, triples))
        })
        .chain(supported_platform_triples.iter().filter_map(|triple| {
            let target = get_builtin_target_by_triple(triple);
            target.map(|target| Ok((triple.clone(), [target.triple.to_string()].into())))
        }))
        .collect()
}

#[cfg(test)]
mod test {
    use crate::config::CrateId;
    use crate::context::crate_context::CrateDependency;
    use crate::context::CommonAttributes;
    use crate::utils::starlark::SelectList;

    use super::*;

    fn supported_platform_triples() -> BTreeSet<String> {
        BTreeSet::from([
            "aarch64-apple-darwin".to_owned(),
            "i686-apple-darwin".to_owned(),
            "x86_64-unknown-linux-gnu".to_owned(),
        ])
    }

    #[test]
    fn resolve_no_targeted() {
        let mut deps = SelectList::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), "0.1.0".to_owned()),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            None,
        );

        let context = CrateContext {
            name: "mock_crate_a".to_owned(),
            version: "0.1.0".to_owned(),
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            ..CrateContext::default()
        };

        let configurations =
            resolve_cfg_platforms(vec![&context], &supported_platform_triples()).unwrap();

        assert_eq!(
            configurations,
            BTreeMap::from([
                // All known triples.
                (
                    "aarch64-apple-darwin".to_owned(),
                    BTreeSet::from(["aarch64-apple-darwin".to_owned()]),
                ),
                (
                    "i686-apple-darwin".to_owned(),
                    BTreeSet::from(["i686-apple-darwin".to_owned()]),
                ),
                (
                    "x86_64-unknown-linux-gnu".to_owned(),
                    BTreeSet::from(["x86_64-unknown-linux-gnu".to_owned()]),
                ),
            ])
        )
    }

    fn mock_resolve_context(configuration: String) -> CrateContext {
        let mut deps = SelectList::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), "0.1.0".to_owned()),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            Some(configuration),
        );

        CrateContext {
            name: "mock_crate_a".to_owned(),
            version: "0.1.0".to_owned(),
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            ..CrateContext::default()
        }
    }

    #[test]
    fn resolve_targeted() {
        let data = BTreeMap::from([
            (
                r#"cfg(target = "x86_64-unknown-linux-gnu")"#.to_owned(),
                BTreeSet::from(["x86_64-unknown-linux-gnu".to_owned()]),
            ),
            (
                r#"cfg(any(target_os = "macos", target_os = "ios"))"#.to_owned(),
                BTreeSet::from([
                    "aarch64-apple-darwin".to_owned(),
                    "i686-apple-darwin".to_owned(),
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
                    (configuration, expectation,),
                    // All known triples.
                    (
                        "aarch64-apple-darwin".to_owned(),
                        BTreeSet::from(["aarch64-apple-darwin".to_owned()]),
                    ),
                    (
                        "i686-apple-darwin".to_owned(),
                        BTreeSet::from(["i686-apple-darwin".to_owned()]),
                    ),
                    (
                        "x86_64-unknown-linux-gnu".to_owned(),
                        BTreeSet::from(["x86_64-unknown-linux-gnu".to_owned()]),
                    ),
                ])
            );
        })
    }

    #[test]
    fn resolve_platforms() {
        let configuration = r#"x86_64-unknown-linux-gnu"#.to_owned();
        let mut deps = SelectList::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), "0.1.0".to_owned()),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            Some(configuration.clone()),
        );

        let context = CrateContext {
            name: "mock_crate_a".to_owned(),
            version: "0.1.0".to_owned(),
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            ..CrateContext::default()
        };

        let configurations =
            resolve_cfg_platforms(vec![&context], &supported_platform_triples()).unwrap();

        assert_eq!(
            configurations,
            BTreeMap::from([
                (
                    configuration,
                    BTreeSet::from(["x86_64-unknown-linux-gnu".to_owned()])
                ),
                // All known triples.
                (
                    "aarch64-apple-darwin".to_owned(),
                    BTreeSet::from(["aarch64-apple-darwin".to_owned()]),
                ),
                (
                    "i686-apple-darwin".to_owned(),
                    BTreeSet::from(["i686-apple-darwin".to_owned()]),
                ),
                (
                    "x86_64-unknown-linux-gnu".to_owned(),
                    BTreeSet::from(["x86_64-unknown-linux-gnu".to_owned()]),
                ),
            ])
        );
    }

    #[test]
    fn resolve_unsupported_targeted() {
        let configuration = r#"cfg(target = "x86_64-unknown-unknown")"#.to_owned();
        let mut deps = SelectList::default();
        deps.insert(
            CrateDependency {
                id: CrateId::new("mock_crate_b".to_owned(), "0.1.0".to_owned()),
                target: "mock_crate_b".to_owned(),
                alias: None,
            },
            Some(configuration.clone()),
        );

        let context = CrateContext {
            name: "mock_crate_a".to_owned(),
            version: "0.1.0".to_owned(),
            common_attrs: CommonAttributes {
                deps,
                ..CommonAttributes::default()
            },
            ..CrateContext::default()
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
                    BTreeSet::from(["aarch64-apple-darwin".to_owned()]),
                ),
                (
                    "i686-apple-darwin".to_owned(),
                    BTreeSet::from(["i686-apple-darwin".to_owned()]),
                ),
                (
                    "x86_64-unknown-linux-gnu".to_owned(),
                    BTreeSet::from(["x86_64-unknown-linux-gnu".to_owned()]),
                ),
            ])
        );
    }
}
