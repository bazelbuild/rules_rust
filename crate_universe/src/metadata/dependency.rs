//! Gathering dependencies is the largest part of annotating.

use anyhow::{bail, Result};
use cargo_metadata::{Metadata as CargoMetadata, Node, NodeDep, Package, PackageId};
use cargo_platform::Platform;
use serde::{Deserialize, Serialize};

use crate::utils::sanitize_module_name;
use crate::utils::starlark::{Select, SelectList};

/// A representation of a crate dependency
#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord, Clone)]
pub struct Dependency {
    /// The PackageId of the target
    pub package_id: PackageId,

    /// The library target name of the dependency.
    pub target_name: String,

    /// The alias for the dependency from the perspective of the current package
    pub alias: Option<String>,
}

/// A collection of [Dependency]s sorted by dependency kind.
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct DependencySet {
    pub normal_deps: SelectList<Dependency>,
    pub normal_dev_deps: SelectList<Dependency>,
    pub proc_macro_deps: SelectList<Dependency>,
    pub proc_macro_dev_deps: SelectList<Dependency>,
    pub build_deps: SelectList<Dependency>,
    pub build_link_deps: SelectList<Dependency>,
    pub build_proc_macro_deps: SelectList<Dependency>,
}

impl DependencySet {
    /// Collect all dependencies for a given node in the resolve graph.
    pub fn new_for_node(node: &Node, metadata: &CargoMetadata) -> Self {
        let (normal_dev_deps, normal_deps) = {
            let (dev, normal) = node
                .deps
                .iter()
                // Do not track workspace members as dependencies. Users are expected to maintain those connections
                .filter(|dep| !is_workspace_member(dep, metadata))
                .filter(|dep| is_lib_package(&metadata[&dep.pkg]))
                .filter(|dep| is_normal_dependency(dep) || is_dev_dependency(dep))
                .partition(|dep| is_dev_dependency(dep));

            (
                collect_deps_selectable(node, dev, metadata),
                collect_deps_selectable(node, normal, metadata),
            )
        };

        let (proc_macro_dev_deps, proc_macro_deps) = {
            let (dev, normal) = node
                .deps
                .iter()
                // Do not track workspace members as dependencies. Users are expected to maintain those connections
                .filter(|dep| !is_workspace_member(dep, metadata))
                .filter(|dep| is_proc_macro_package(&metadata[&dep.pkg]))
                .filter(|dep| !is_build_dependency(dep))
                .partition(|dep| is_dev_dependency(dep));

            (
                collect_deps_selectable(node, dev, metadata),
                collect_deps_selectable(node, normal, metadata),
            )
        };

        // For rules on build script dependencies see:
        //  https://doc.rust-lang.org/cargo/reference/build-scripts.html#build-dependencies
        let (build_proc_macro_deps, build_deps) = {
            let (proc_macro, normal) = node
                .deps
                .iter()
                // Do not track workspace members as dependencies. Users are expected to maintain those connections
                .filter(|dep| !is_workspace_member(dep, metadata))
                .filter(|dep| is_build_dependency(dep))
                .filter(|dep| !is_dev_dependency(dep))
                .partition(|dep| is_proc_macro_package(&metadata[&dep.pkg]));

            (
                collect_deps_selectable(node, proc_macro, metadata),
                collect_deps_selectable(node, normal, metadata),
            )
        };

        // packages with the `links` property follow slightly different rules than other
        // dependencies. These packages provide zero or more environment variables to the build
        // script's of packages that directly (non-transitively) depend on these packages. Note that
        // dependency specifically means of the package (`dependencies`), and not of the build
        // script (`build-dependencies`).
        // https://doc.rust-lang.org/cargo/reference/build-scripts.html#the-links-manifest-key
        // https://doc.rust-lang.org/cargo/reference/build-scripts.html#-sys-packages
        // https://doc.rust-lang.org/cargo/reference/build-script-examples.html#using-another-sys-crate
        let mut build_link_deps = SelectList::<Dependency>::default();
        normal_deps.configurations().into_iter().for_each(|config| {
            normal_deps
                .get_iter(config)
                // Iterating over known key should be safe
                .unwrap()
                // Add any normal dependency to build dependencies that are associated `*-sys` crates
                .for_each(|dep| {
                    if metadata[&dep.package_id].links.is_some() {
                        build_link_deps.insert(dep.clone(), config.cloned())
                    }
                });
        });

        Self {
            normal_deps,
            normal_dev_deps,
            proc_macro_deps,
            proc_macro_dev_deps,
            build_deps,
            build_link_deps,
            build_proc_macro_deps,
        }
    }
}

/// For details on optional dependencies see [the Rust docs](https://doc.rust-lang.org/cargo/reference/features.html#optional-dependencies).
fn is_optional_crate_enabled(
    parent: &Node,
    dep: &NodeDep,
    target: Option<&Platform>,
    metadata: &CargoMetadata,
) -> bool {
    let pkg = &metadata[&parent.id];

    let mut enabled_deps = pkg
        .features
        .iter()
        .filter(|(pkg_feature, _)| parent.features.contains(pkg_feature))
        .flat_map(|(_, features)| features)
        .filter_map(|f| f.strip_prefix("dep:"));

    // if the crate is marked as optional dependency, we check whether
    // a feature prefixed with dep: is enabled
    if let Some(toml_dep) = pkg
        .dependencies
        .iter()
        .filter(|&d| d.target.as_ref() == target)
        .filter(|&d| d.optional)
        .find(|&d| sanitize_module_name(&d.name) == dep.name)
    {
        enabled_deps.any(|d| d == toml_dep.name.as_str())
    } else {
        true
    }
}

fn collect_deps_selectable(
    node: &Node,
    deps: Vec<&NodeDep>,
    metadata: &cargo_metadata::Metadata,
) -> SelectList<Dependency> {
    let mut selectable = SelectList::default();

    for dep in deps.into_iter() {
        let dep_pkg = &metadata[&dep.pkg];
        let target_name = get_library_target_name(dep_pkg, &dep.name)
            .expect("Nodes Dependencies are expected to exclusively be library-like targets");
        let alias = get_target_alias(&dep.name, dep_pkg);

        for kind_info in &dep.dep_kinds {
            if is_optional_crate_enabled(node, dep, kind_info.target.as_ref(), metadata) {
                selectable.insert(
                    Dependency {
                        package_id: dep.pkg.clone(),
                        target_name: target_name.clone(),
                        alias: alias.clone(),
                    },
                    kind_info
                        .target
                        .as_ref()
                        .map(|platform| platform.to_string()),
                );
            }
        }
    }

    selectable
}

fn is_lib_package(package: &Package) -> bool {
    package.targets.iter().any(|target| {
        target
            .crate_types
            .iter()
            .any(|t| ["lib", "rlib"].contains(&t.as_str()))
    })
}

fn is_proc_macro_package(package: &Package) -> bool {
    package
        .targets
        .iter()
        .any(|target| target.crate_types.iter().any(|t| t == "proc-macro"))
}

fn is_dev_dependency(node_dep: &NodeDep) -> bool {
    let is_normal_dep = is_normal_dependency(node_dep);
    let is_dev_dep = node_dep
        .dep_kinds
        .iter()
        .any(|k| matches!(k.kind, cargo_metadata::DependencyKind::Development));

    // In the event that a dependency is listed as both a dev and normal dependency,
    // it's only considered a dev dependency if it's __not__ a normal dependency.
    !is_normal_dep && is_dev_dep
}

fn is_build_dependency(node_dep: &NodeDep) -> bool {
    node_dep
        .dep_kinds
        .iter()
        .any(|k| matches!(k.kind, cargo_metadata::DependencyKind::Build))
}

fn is_normal_dependency(node_dep: &NodeDep) -> bool {
    node_dep
        .dep_kinds
        .iter()
        .any(|k| matches!(k.kind, cargo_metadata::DependencyKind::Normal))
}

fn is_workspace_member(node_dep: &NodeDep, metadata: &CargoMetadata) -> bool {
    metadata
        .workspace_members
        .iter()
        .any(|id| id == &node_dep.pkg)
}

fn get_library_target_name(package: &Package, potential_name: &str) -> Result<String> {
    // If the potential name is not an alias in a dependent's package, a target's name
    // should match which means we already know what the target library name is.
    if package.targets.iter().any(|t| t.name == potential_name) {
        return Ok(potential_name.to_string());
    }

    // Locate any library type targets
    let lib_targets: Vec<&cargo_metadata::Target> = package
        .targets
        .iter()
        .filter(|t| {
            t.kind
                .iter()
                .any(|k| k == "lib" || k == "rlib" || k == "proc-macro")
        })
        .collect();

    // Only one target should be found
    if lib_targets.len() != 1 {
        bail!(
            "Unexpected number of 'library-like' targets found for {}: {:?}",
            package.name,
            package.targets
        )
    }

    let target = lib_targets.into_iter().last().unwrap();
    Ok(target.name.clone())
}

/// The resolve graph (resolve.nodes[#].deps[#].name) of Cargo metadata uses module names
/// for targets where packages (packages[#].targets[#].name) uses crate names. In order to
/// determine whether or not a dependency is aliased, we compare it with all available targets
/// on it's package. Note that target names are not guaranteed to be module names where Node
/// dependencies are, so we need to do a conversion to check for this
fn get_target_alias(target_name: &str, package: &Package) -> Option<String> {
    match package
        .targets
        .iter()
        .all(|t| sanitize_module_name(&t.name) != target_name)
    {
        true => Some(target_name.to_string()),
        false => None,
    }
}

#[cfg(test)]
mod test {
    use std::collections::BTreeSet;

    use super::*;

    use crate::test::*;

    #[test]
    fn get_expected_lib_target_name() {
        let mut package = mock_cargo_metadata_package();
        package
            .targets
            .extend(vec![serde_json::from_value(serde_json::json!({
                "name": "potential",
                "kind": ["lib"],
                "crate_types": [],
                "required_features": [],
                "src_path": "/tmp/mock.rs",
                "edition": "2021",
                "doctest": false,
                "test": false,
                "doc": false,
            }))
            .unwrap()]);

        assert_eq!(
            get_library_target_name(&package, "potential").unwrap(),
            "potential"
        );
    }

    #[test]
    fn get_lib_target_name() {
        let mut package = mock_cargo_metadata_package();
        package
            .targets
            .extend(vec![serde_json::from_value(serde_json::json!({
                "name": "lib_target",
                "kind": ["lib"],
                "crate_types": [],
                "required_features": [],
                "src_path": "/tmp/mock.rs",
                "edition": "2021",
                "doctest": false,
                "test": false,
                "doc": false,
            }))
            .unwrap()]);

        assert_eq!(
            get_library_target_name(&package, "mock-pkg").unwrap(),
            "lib_target"
        );
    }

    #[test]
    fn get_rlib_target_name() {
        let mut package = mock_cargo_metadata_package();
        package
            .targets
            .extend(vec![serde_json::from_value(serde_json::json!({
                "name": "rlib_target",
                "kind": ["rlib"],
                "crate_types": [],
                "required_features": [],
                "src_path": "/tmp/mock.rs",
                "edition": "2021",
                "doctest": false,
                "test": false,
                "doc": false,
            }))
            .unwrap()]);

        assert_eq!(
            get_library_target_name(&package, "mock-pkg").unwrap(),
            "rlib_target"
        );
    }

    #[test]
    fn get_proc_macro_target_name() {
        let mut package = mock_cargo_metadata_package();
        package
            .targets
            .extend(vec![serde_json::from_value(serde_json::json!({
                "name": "proc_macro_target",
                "kind": ["proc-macro"],
                "crate_types": [],
                "required_features": [],
                "src_path": "/tmp/mock.rs",
                "edition": "2021",
                "doctest": false,
                "test": false,
                "doc": false,
            }))
            .unwrap()]);

        assert_eq!(
            get_library_target_name(&package, "mock-pkg").unwrap(),
            "proc_macro_target"
        );
    }

    #[test]
    fn get_bin_target_name() {
        let mut package = mock_cargo_metadata_package();
        package
            .targets
            .extend(vec![serde_json::from_value(serde_json::json!({
                "name": "bin_target",
                "kind": ["bin"],
                "crate_types": [],
                "required_features": [],
                "src_path": "/tmp/mock.rs",
                "edition": "2021",
                "doctest": false,
                "test": false,
                "doc": false,
            }))
            .unwrap()]);

        // It's an error for no library target to be found.
        assert!(get_library_target_name(&package, "mock-pkg").is_err());
    }

    /// Locate the [cargo_metadata::Node] for the crate matching the given name
    fn find_metadata_node<'a>(
        name: &str,
        metadata: &'a cargo_metadata::Metadata,
    ) -> &'a cargo_metadata::Node {
        metadata
            .resolve
            .as_ref()
            .unwrap()
            .nodes
            .iter()
            .find(|node| {
                let pkg = &metadata[&node.id];
                pkg.name == name
            })
            .unwrap()
    }

    #[test]
    fn sys_dependencies() {
        let metadata = metadata::build_scripts();

        let openssl_node = find_metadata_node("openssl", &metadata);

        let dependencies = DependencySet::new_for_node(openssl_node, &metadata);

        let normal_sys_crate = dependencies
            .normal_deps
            .get_iter(None)
            .unwrap()
            .find(|dep| {
                let pkg = &metadata[&dep.package_id];
                pkg.name == "openssl-sys"
            });

        let link_dep_sys_crate = dependencies
            .build_link_deps
            .get_iter(None)
            .unwrap()
            .find(|dep| {
                let pkg = &metadata[&dep.package_id];
                pkg.name == "openssl-sys"
            });

        // sys crates like `openssl-sys` should always be dependencies of any
        // crate which matches it's name minus the `-sys` suffix
        assert!(normal_sys_crate.is_some());
        assert!(link_dep_sys_crate.is_some());
    }

    #[test]
    fn sys_crate_with_build_script() {
        let metadata = metadata::build_scripts();

        let libssh2 = find_metadata_node("libssh2-sys", &metadata);
        let libssh2_depset = DependencySet::new_for_node(libssh2, &metadata);

        // Collect build dependencies into a set
        let build_deps: BTreeSet<String> = libssh2_depset
            .build_deps
            .configurations()
            .into_iter()
            .flat_map(|conf| {
                libssh2_depset
                    .build_deps
                    .get_iter(conf)
                    .unwrap()
                    .map(|dep| dep.package_id.repr.clone())
                    .collect::<Vec<String>>()
            })
            .collect();

        assert_eq!(
            BTreeSet::from([
                "cc 1.0.72 (registry+https://github.com/rust-lang/crates.io-index)".to_owned(),
                "pkg-config 0.3.24 (registry+https://github.com/rust-lang/crates.io-index)"
                    .to_owned(),
                "vcpkg 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)".to_owned()
            ]),
            build_deps,
        );

        // Collect normal dependencies into a set
        let normal_deps: BTreeSet<String> = libssh2_depset
            .normal_deps
            .configurations()
            .into_iter()
            .flat_map(|conf| {
                libssh2_depset
                    .normal_deps
                    .get_iter(conf)
                    .unwrap()
                    .map(|dep| dep.package_id.to_string())
                    .collect::<Vec<String>>()
            })
            .collect();

        assert_eq!(
            BTreeSet::from([
                "libc 0.2.112 (registry+https://github.com/rust-lang/crates.io-index)".to_owned(),
                "libz-sys 1.1.8 (registry+https://github.com/rust-lang/crates.io-index)".to_owned(),
                "openssl-sys 0.9.87 (registry+https://github.com/rust-lang/crates.io-index)"
                    .to_owned(),
            ]),
            normal_deps,
        );

        assert!(libssh2_depset.proc_macro_deps.is_empty());
        assert!(libssh2_depset.normal_dev_deps.is_empty());
        assert!(libssh2_depset.proc_macro_dev_deps.is_empty());
        assert!(libssh2_depset.build_proc_macro_deps.is_empty());
    }

    #[test]
    fn tracked_aliases() {
        let metadata = metadata::alias();

        let aliases_node = find_metadata_node("aliases", &metadata);
        let dependencies = DependencySet::new_for_node(aliases_node, &metadata);

        let aliases: Vec<&Dependency> = dependencies
            .normal_deps
            .get_iter(None)
            .unwrap()
            .filter(|dep| dep.alias.is_some())
            .collect();

        assert_eq!(aliases.len(), 2);

        let expected: BTreeSet<String> = aliases
            .into_iter()
            .map(|dep| dep.alias.as_ref().unwrap().clone())
            .collect();

        assert_eq!(
            expected,
            BTreeSet::from(["pinned_log".to_owned(), "pinned_names".to_owned()])
        );
    }

    #[test]
    fn matched_rlib() {
        let metadata = metadata::crate_types();

        let node = find_metadata_node("crate-types", &metadata);
        let dependencies = DependencySet::new_for_node(node, &metadata);

        let rlib_deps: Vec<&Dependency> = dependencies
            .normal_deps
            .get_iter(None)
            .unwrap()
            .filter(|dep| {
                let pkg = &metadata[&dep.package_id];
                pkg.targets
                    .iter()
                    .any(|t| t.crate_types.contains(&"rlib".to_owned()))
            })
            .collect();

        // Currently the only expected __explicitly__ "rlib" target in this metadata is `sysinfo`.
        assert_eq!(rlib_deps.len(), 1);

        let sysinfo_dep = rlib_deps.iter().last().unwrap();
        assert_eq!(sysinfo_dep.target_name, "sysinfo");
    }

    #[test]
    fn multiple_dep_kinds() {
        let metadata = metadata::multi_cfg_dep();

        let node = find_metadata_node("cpufeatures", &metadata);
        let dependencies = DependencySet::new_for_node(node, &metadata);

        let libc_cfgs: BTreeSet<String> = dependencies
            .normal_deps
            .configurations()
            .into_iter()
            .flat_map(|conf| {
                dependencies
                    .normal_deps
                    .get_iter(conf)
                    .expect("Iterating over known keys should never panic")
                    .filter(|dep| dep.target_name == "libc")
                    .map(move |_| conf.cloned())
            })
            .flatten()
            .collect();

        assert_eq!(
            BTreeSet::from([
                "aarch64-linux-android".to_owned(),
                "cfg(all(target_arch = \"aarch64\", target_os = \"linux\"))".to_owned(),
                "cfg(all(target_arch = \"aarch64\", target_vendor = \"apple\"))".to_owned(),
            ]),
            libc_cfgs,
        );
    }

    #[test]
    fn optional_deps_disabled() {
        let metadata = metadata::optional_deps_disabled();

        let node = find_metadata_node("clap", &metadata);
        let dependencies = DependencySet::new_for_node(node, &metadata);

        assert!(!dependencies
            .normal_deps
            .get_iter(None)
            .expect("Iterating over known keys should never panic")
            .any(|dep| { dep.target_name == "is-terminal" || dep.target_name == "termcolor" }));
    }

    #[test]
    fn optional_deps_enabled() {
        let metadata = metadata::optional_deps_enabled();

        let clap = find_metadata_node("clap", &metadata);
        let clap_depset = DependencySet::new_for_node(clap, &metadata);
        assert_eq!(
            clap_depset
                .normal_deps
                .get_iter(None)
                .expect("Iterating over known keys should never panic")
                .filter(|dep| {
                    dep.target_name == "is-terminal" || dep.target_name == "termcolor"
                })
                .count(),
            2
        );

        let notify = find_metadata_node("notify", &metadata);
        let notify_depset = DependencySet::new_for_node(notify, &metadata);

        // mio is not present in the common list of dependencies
        assert!(!notify_depset
            .normal_deps
            .get_iter(None)
            .expect("Iterating over known keys should never panic")
            .any(|dep| { dep.target_name == "mio" }));

        // mio is a dependency on linux
        assert!(notify_depset
            .normal_deps
            .get_iter(Some(&"cfg(target_os = \"linux\")".to_string()))
            .expect("Iterating over known keys should never panic")
            .any(|dep| { dep.target_name == "mio" }));

        // mio is marked optional=true on macos
        assert!(!notify_depset
            .normal_deps
            .get_iter(Some(&"cfg(target_os = \"macos\")".to_string()))
            .expect("Iterating over known keys should never panic")
            .any(|dep| { dep.target_name == "mio" }));
    }
}
