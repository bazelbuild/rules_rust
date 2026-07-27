use std::collections::{BTreeMap, BTreeSet};

use serde::Deserialize;

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CrateSpec {
    pub aliases: BTreeMap<String, String>,
    pub crate_id: String,
    pub display_name: String,
    pub edition: String,
    pub root_module: String,
    pub is_workspace_member: bool,
    pub deps: BTreeSet<String>,
    pub proc_macro_dylib_path: Option<String>,
    pub source: Option<CrateSpecSource>,
    pub cfg: Vec<String>,
    pub env: BTreeMap<String, String>,
    pub target: String,
    pub crate_type: CrateType,
    pub is_test: bool,
    pub build: Option<CrateSpecBuild>,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CrateSpecBuild {
    pub label: String,
    pub build_file: String,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CrateSpecSource {
    pub exclude_dirs: Vec<String>,
    pub include_dirs: Vec<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CrateType {
    Bin,
    Rlib,
    Lib,
    Dylib,
    Cdylib,
    Staticlib,
    ProcMacro,
}

/// Read all crate specs, deduplicating crates with the same ID. This happens when
/// a rust_test depends on a rust_library, for example.
pub fn consolidate_crate_specs(crate_specs: Vec<CrateSpec>) -> anyhow::Result<BTreeSet<CrateSpec>> {
    let mut consolidated_specs: BTreeMap<String, CrateSpec> = BTreeMap::new();
    for mut spec in crate_specs.into_iter() {
        log::debug!("{:?}", spec);
        if let Some(existing) = consolidated_specs.get_mut(&spec.crate_id) {
            existing.deps.extend(spec.deps);
            existing.env.extend(spec.env);
            existing.aliases.extend(spec.aliases);

            if let Some(source) = &mut existing.source {
                if let Some(mut new_source) = spec.source {
                    new_source
                        .exclude_dirs
                        .retain(|src| !source.exclude_dirs.contains(src));
                    new_source
                        .include_dirs
                        .retain(|src| !source.include_dirs.contains(src));
                    source.exclude_dirs.extend(new_source.exclude_dirs);
                    source.include_dirs.extend(new_source.include_dirs);
                }
            } else {
                existing.source = spec.source;
            }

            spec.cfg.retain(|cfg| !existing.cfg.contains(cfg));
            existing.cfg.extend(spec.cfg);

            // display_name should match the library's crate name because Rust Analyzer
            // seems to use display_name for matching crate entries in rust-project.json
            // against symbols in source files. For more details, see
            // https://github.com/bazelbuild/rules_rust/issues/1032
            if spec.crate_type == CrateType::Rlib {
                existing.display_name = spec.display_name;
                existing.crate_type = CrateType::Rlib;
                existing.is_test = spec.is_test;
            }

            // We want to use the test target's build label to provide
            // unit tests codelens actions for library crates in IDEs.
            if spec.is_test {
                if let Some(build) = spec.build {
                    existing.build = Some(build);
                }
            }

            // For proc-macro crates that exist within the workspace, there will be a
            // generated crate-spec in both the fastbuild and opt-exec configuration.
            // Prefer proc macro paths with an opt-exec component in the path.
            if let Some(dylib_path) = spec.proc_macro_dylib_path.as_ref() {
                const OPT_PATH_COMPONENT: &str = "-opt-exec";
                if dylib_path.contains(OPT_PATH_COMPONENT) {
                    existing.proc_macro_dylib_path.replace(dylib_path.clone());
                }
            }
        } else {
            consolidated_specs.insert(spec.crate_id.clone(), spec);
        }
    }

    Ok(consolidated_specs.into_values().collect())
}

#[cfg(test)]
mod test {
    use super::*;
    use itertools::Itertools;

    #[test]
    fn consolidate_lib_then_test_specs() {
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-lib_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: Some(CrateSpecBuild {
                    label: "//:mylib".to_owned(),
                    build_file: "BUILD.bazel".to_owned(),
                }),
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-extra_test_dep.rs".into(),
                display_name: "extra_test_dep".into(),
                edition: "2018".into(),
                root_module: "extra_test_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-lib_dep.rs".into(),
                display_name: "lib_dep".into(),
                edition: "2018".into(),
                root_module: "lib_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-extra_test_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Bin,
                is_test: true,
                build: None,
            },
        ];

        assert_eq!(
            consolidate_crate_specs(crate_specs).unwrap(),
            BTreeSet::from([
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-mylib.rs".into(),
                    display_name: "mylib".into(),
                    edition: "2018".into(),
                    root_module: "mylib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from(["ID-lib_dep.rs".into(), "ID-extra_test_dep.rs".into()]),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: Some(CrateSpecBuild {
                        label: "//:mylib".to_owned(),
                        build_file: "BUILD.bazel".to_owned(),
                    }),
                },
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-extra_test_dep.rs".into(),
                    display_name: "extra_test_dep".into(),
                    edition: "2018".into(),
                    root_module: "extra_test_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None
                },
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-lib_dep.rs".into(),
                    display_name: "lib_dep".into(),
                    edition: "2018".into(),
                    root_module: "lib_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None
                },
            ])
        );
    }

    #[test]
    fn consolidate_test_then_lib_specs() {
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-extra_test_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Bin,
                is_test: true,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-lib_dep.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-extra_test_dep.rs".into(),
                display_name: "extra_test_dep".into(),
                edition: "2018".into(),
                root_module: "extra_test_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-lib_dep.rs".into(),
                display_name: "lib_dep".into(),
                edition: "2018".into(),
                root_module: "lib_dep.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            },
        ];

        assert_eq!(
            consolidate_crate_specs(crate_specs).unwrap(),
            BTreeSet::from([
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-mylib.rs".into(),
                    display_name: "mylib".into(),
                    edition: "2018".into(),
                    root_module: "mylib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from(["ID-lib_dep.rs".into(), "ID-extra_test_dep.rs".into()]),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None
                },
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-extra_test_dep.rs".into(),
                    display_name: "extra_test_dep".into(),
                    edition: "2018".into(),
                    root_module: "extra_test_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None
                },
                CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-lib_dep.rs".into(),
                    display_name: "lib_dep".into(),
                    edition: "2018".into(),
                    root_module: "lib_dep.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: false,
                    build: None
                },
            ])
        );
    }

    #[test]
    fn consolidate_lib_test_main_specs() {
        // mylib.rs is a library but has tests and an entry point, and mylib2.rs
        // depends on mylib.rs. The display_name of the library target mylib.rs
        // should be "mylib" no matter what order the crate specs is in.
        // Otherwise Rust Analyzer will not be able to resolve references to
        // mylib in mylib2.rs.
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Bin,
                is_test: true,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_main".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Bin,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib2.rs".into(),
                display_name: "mylib2".into(),
                edition: "2018".into(),
                root_module: "mylib2.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::from(["ID-mylib.rs".into()]),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: false,
                build: None,
            },
        ];

        for perm in crate_specs.into_iter().permutations(4) {
            assert_eq!(
                consolidate_crate_specs(perm).unwrap(),
                BTreeSet::from([
                    CrateSpec {
                        aliases: BTreeMap::new(),
                        crate_id: "ID-mylib.rs".into(),
                        display_name: "mylib".into(),
                        edition: "2018".into(),
                        root_module: "mylib.rs".into(),
                        is_workspace_member: true,
                        deps: BTreeSet::from([]),
                        proc_macro_dylib_path: None,
                        source: None,
                        cfg: vec!["test".into(), "debug_assertions".into()],
                        env: BTreeMap::new(),
                        target: "x86_64-unknown-linux-gnu".into(),
                        crate_type: CrateType::Rlib,
                        is_test: false,
                        build: None,
                    },
                    CrateSpec {
                        aliases: BTreeMap::new(),
                        crate_id: "ID-mylib2.rs".into(),
                        display_name: "mylib2".into(),
                        edition: "2018".into(),
                        root_module: "mylib2.rs".into(),
                        is_workspace_member: true,
                        deps: BTreeSet::from(["ID-mylib.rs".into()]),
                        proc_macro_dylib_path: None,
                        source: None,
                        cfg: vec!["test".into(), "debug_assertions".into()],
                        env: BTreeMap::new(),
                        target: "x86_64-unknown-linux-gnu".into(),
                        crate_type: CrateType::Rlib,
                        is_test: false,
                        build: None
                    },
                ])
            );
        }
    }

    #[test]
    fn consolidate_proc_macro_prefer_exec() {
        // proc macro crates should prefer the -opt-exec path which is always generated
        // during builds where it is used, while the fastbuild version would only be built
        // when explicitly building that target.
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-myproc_macro.rs".into(),
                display_name: "myproc_macro".into(),
                edition: "2018".into(),
                root_module: "myproc_macro.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: Some(
                    "bazel-out/k8-opt-exec-F005BA11/bin/myproc_macro/libmyproc_macro-12345.so"
                        .into(),
                ),
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::ProcMacro,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-myproc_macro.rs".into(),
                display_name: "myproc_macro".into(),
                edition: "2018".into(),
                root_module: "myproc_macro.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: Some(
                    "bazel-out/k8-fastbuild/bin/myproc_macro/libmyproc_macro-12345.so".into(),
                ),
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::ProcMacro,
                is_test: false,
                build: None,
            },
        ];

        for perm in crate_specs.into_iter().permutations(2) {
            assert_eq!(
                consolidate_crate_specs(perm).unwrap(),
                BTreeSet::from([CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-myproc_macro.rs".into(),
                    display_name: "myproc_macro".into(),
                    edition: "2018".into(),
                    root_module: "myproc_macro.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::new(),
                    proc_macro_dylib_path: Some(
                        "bazel-out/k8-opt-exec-F005BA11/bin/myproc_macro/libmyproc_macro-12345.so"
                            .into()
                    ),
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::ProcMacro,
                    is_test: false,
                    build: None,
                },])
            );
        }
    }

    #[test]
    fn consolidate_proc_macro_prefer_unsuffixed_exec() {
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-myproc_macro.rs".into(),
                display_name: "myproc_macro".into(),
                edition: "2018".into(),
                root_module: "myproc_macro.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "wasm32-unknown-unknown".into(),
                crate_type: CrateType::ProcMacro,
                is_test: false,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-myproc_macro.rs".into(),
                display_name: "myproc_macro".into(),
                edition: "2018".into(),
                root_module: "myproc_macro.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: Some(
                    "bazel-out/k8-opt-exec/bin/myproc_macro/libmyproc_macro-12345.so".into(),
                ),
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::ProcMacro,
                is_test: false,
                build: None,
            },
        ];

        assert_eq!(
            consolidate_crate_specs(crate_specs).unwrap(),
            BTreeSet::from([CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-myproc_macro.rs".into(),
                display_name: "myproc_macro".into(),
                edition: "2018".into(),
                root_module: "myproc_macro.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: Some(
                    "bazel-out/k8-opt-exec/bin/myproc_macro/libmyproc_macro-12345.so".into(),
                ),
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "wasm32-unknown-unknown".into(),
                crate_type: CrateType::ProcMacro,
                is_test: false,
                build: None,
            }])
        );
    }

    #[test]
    fn consolidate_spec_with_aliases() {
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: true,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::from([("ID-mylib_dep.rs".into(), "aliased_name".into())]),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Bin,
                is_test: true,
                build: None,
            },
        ];

        for perm in crate_specs.into_iter().permutations(2) {
            assert_eq!(
                consolidate_crate_specs(perm).unwrap(),
                BTreeSet::from([CrateSpec {
                    aliases: BTreeMap::from([("ID-mylib_dep.rs".into(), "aliased_name".into())]),
                    crate_id: "ID-mylib.rs".into(),
                    display_name: "mylib".into(),
                    edition: "2018".into(),
                    root_module: "mylib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from([]),
                    proc_macro_dylib_path: None,
                    source: None,
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: true,
                    build: None,
                }])
            );
        }
    }

    #[test]
    fn consolidate_spec_with_sources() {
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: None,
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: true,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: Some(CrateSpecSource {
                    exclude_dirs: vec!["exclude".into()],
                    include_dirs: vec!["include".into()],
                }),
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Bin,
                is_test: true,
                build: None,
            },
        ];

        for perm in crate_specs.into_iter().permutations(2) {
            assert_eq!(
                consolidate_crate_specs(perm).unwrap(),
                BTreeSet::from([CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-mylib.rs".into(),
                    display_name: "mylib".into(),
                    edition: "2018".into(),
                    root_module: "mylib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from([]),
                    proc_macro_dylib_path: None,
                    source: Some(CrateSpecSource {
                        exclude_dirs: vec!["exclude".into()],
                        include_dirs: vec!["include".into()],
                    }),
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: true,
                    build: None,
                }])
            );
        }
    }

    #[test]
    fn consolidate_spec_with_duplicate_sources() {
        let crate_specs = vec![
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: Some(CrateSpecSource {
                    exclude_dirs: vec!["exclude".into()],
                    include_dirs: vec!["include".into()],
                }),
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Rlib,
                is_test: true,
                build: None,
            },
            CrateSpec {
                aliases: BTreeMap::new(),
                crate_id: "ID-mylib.rs".into(),
                display_name: "mylib_test".into(),
                edition: "2018".into(),
                root_module: "mylib.rs".into(),
                is_workspace_member: true,
                deps: BTreeSet::new(),
                proc_macro_dylib_path: None,
                source: Some(CrateSpecSource {
                    exclude_dirs: vec!["exclude".into()],
                    include_dirs: vec!["include".into()],
                }),
                cfg: vec!["test".into(), "debug_assertions".into()],
                env: BTreeMap::new(),
                target: "x86_64-unknown-linux-gnu".into(),
                crate_type: CrateType::Bin,
                is_test: true,
                build: None,
            },
        ];

        for perm in crate_specs.into_iter().permutations(2) {
            assert_eq!(
                consolidate_crate_specs(perm).unwrap(),
                BTreeSet::from([CrateSpec {
                    aliases: BTreeMap::new(),
                    crate_id: "ID-mylib.rs".into(),
                    display_name: "mylib".into(),
                    edition: "2018".into(),
                    root_module: "mylib.rs".into(),
                    is_workspace_member: true,
                    deps: BTreeSet::from([]),
                    proc_macro_dylib_path: None,
                    source: Some(CrateSpecSource {
                        exclude_dirs: vec!["exclude".into()],
                        include_dirs: vec!["include".into()],
                    }),
                    cfg: vec!["test".into(), "debug_assertions".into()],
                    env: BTreeMap::new(),
                    target: "x86_64-unknown-linux-gnu".into(),
                    crate_type: CrateType::Rlib,
                    is_test: true,
                    build: None,
                }])
            );
        }
    }
}
