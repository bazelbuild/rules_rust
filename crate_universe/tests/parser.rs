use crate_universe_resolver::config::Package;
use crate_universe_resolver::parser::merge_cargo_tomls;
use crate_universe_resolver::NamedTempFile;
use indoc::indoc;
use maplit::{btreemap, btreeset};
use semver::VersionReq;
use spectral::prelude::*;
use std::collections::{BTreeMap, BTreeSet};

#[test]
fn parses_one_cargo_toml() {
    let cargo_toml = indoc! { r#"
    [package]
    name = "frobber"
    version = "0.1.0"

    [dependencies]
    # Normalises string or map values
    lazy_static = { version = "1" }
    maplit = "1.0.1"
    serde = { version = "1", default-features = false, features = ["derive"] }
    structopt = { version = "0.3", optional = true }

    [patch.crates-io]
    syn = { git = "https://github.com/forked/syn.git" }

    [features]
    cmd = ["structopt"]

    [dev-dependencies]
    futures = "0.1"

    [build-dependencies]
    syn = "1"
    "# };

    let cargo_tomls = btreemap! { "//some:Cargo.toml" => cargo_toml };

    let want_deps = indoc! {r#"
    lazy_static = { version = ">=1.0.0, <2.0.0", default-features = true, features = [] }
    maplit = { version = ">=1.0.1, <2.0.0", default-features = true, features = [] }
    serde = { version = ">=1.0.0, <2.0.0", default-features = false, features = ["derive"] }
    structopt = { version = ">=0.3.0, <0.4.0", default-features = true, features = [] }
    "#};

    let want_labels_to_deps = btreemap! {
        "//some:Cargo.toml" => btreeset!{
            "futures",
            "lazy_static",
            "maplit",
            "serde",
            "structopt",
            "syn",
        },
    };

    let value = test(cargo_tomls, vec![], want_deps, want_labels_to_deps);

    let patch_syn_git = value
        .as_table()
        .unwrap()
        .get("patch")
        .unwrap()
        .as_table()
        .unwrap()
        .get("crates-io")
        .unwrap()
        .as_table()
        .unwrap()
        .get("syn")
        .unwrap()
        .as_table()
        .unwrap()
        .get("git")
        .unwrap()
        .as_str()
        .unwrap();
    assert_eq!("https://github.com/forked/syn.git", patch_syn_git);

    assert_eq!(
        value.as_table().unwrap().get("build-dependencies").unwrap(),
        &r#"syn = { version = ">=1.0.0, <2.0.0", default-features = true, features = [] }"#
            .parse::<toml::Value>()
            .unwrap(),
    );

    assert_eq!(
        value.as_table().unwrap().get("dev-dependencies").unwrap(),
        &r#"futures = { version = ">=0.1.0, <0.2.0", default-features = true, features = [] }"#
            .parse::<toml::Value>()
            .unwrap(),
    );
}

#[test]
fn merges_two_cargo_tomls() {
    let cargo_toml1 = indoc! { r#"
    [package]
    name = "blepper"
    version = "1.0.0"

    [dependencies]
    lazy_static = { version = "1" }
    num_enum = { version = "0.5", features = ["complex-expressions"] }
    serde = { version = "1", default-features = false, features = ["derive"] }
    "# };

    let cargo_toml2 = indoc! { r#"
    [package]
    name = "mlemer"
    version = "2.0.0"

    [dependencies]
    lazy_static = { version = "1.1" }
    maplit = "1.0.1"
    serde = { version = "1.0.57", features = ["rc"] }
    "# };

    let cargo_tomls = btreemap! {
       "//a:Cargo.toml" => cargo_toml1,
       "//b:Cargo.toml" => cargo_toml2,
    };

    let want_deps = indoc! {r#"
    lazy_static = { version = ">=1.0.0, <2.0.0, >=1.1.0, <1.2.0", default-features = true, features = [] }
    maplit = { version = ">=1.0.1, <2.0.0", default-features = true, features = [] }
    num_enum = { version = ">=0.5.0, <0.6.0", default-features = true, features = ["complex-expressions"] }
    serde = { version = ">=1.0.0, <2.0.0, >=1.0.57, <2.0.0", default-features = true, features = ["derive", "rc"] }
    "#};

    let want_labels_to_deps = btreemap! {
        "//a:Cargo.toml" => btreeset!{
            "lazy_static",
            "num_enum",
            "serde",
        },
        "//b:Cargo.toml" => btreeset!{
            "lazy_static",
            "maplit",
            "serde",
        }
    };

    test(cargo_tomls, vec![], want_deps, want_labels_to_deps);
}

#[test]
fn fails_to_merge_semver_and_git() {
    let cargo_toml1 = indoc! { r#"
    [package]
    name = "blepper"
    version = "1.0.0"

    [dependencies]
    lazy_static = { version = "42" }
    "# };

    let cargo_toml2 = indoc! { r#"
    [package]
    name = "mlemer"
    version = "2.0.0"

    [dependencies]
    lazy_static = { git = "https://github.com/rust-lang-nursery/lazy-static.rs.git" }
    "# };

    let cargo_tomls = btreemap! {
       "//a:Cargo.toml" => cargo_toml1,
       "//b:Cargo.toml" => cargo_toml2,
    };

    let err = format!("{:?}", expect_err(cargo_tomls, vec![]));

    assert_that(&err).starts_with("Failed to merge multiple dependencies on lazy_static");
    assert_that(&err).contains("Can't merge semver and git versions of the same dependency");
    assert_that(&err).contains("42");
    assert_that(&err).contains("https://github.com/rust-lang-nursery/lazy-static.rs.git");
}

#[test]
fn fails_to_merge_different_git() {
    let cargo_toml1 = indoc! { r#"
    [package]
    name = "blepper"
    version = "1.0.0"

    [dependencies]
    lazy_static = { git = "https://github.com/some-fork/lazy-static.rs.git" }
    "# };

    let cargo_toml2 = indoc! { r#"
    [package]
    name = "mlemer"
    version = "2.0.0"

    [dependencies]
    lazy_static = { git = "https://github.com/rust-lang-nursery/lazy-static.rs.git" }
    "# };

    let cargo_tomls = btreemap! {
       "//a:Cargo.toml" => cargo_toml1,
       "//b:Cargo.toml" => cargo_toml2,
    };

    let err = format!("{:?}", expect_err(cargo_tomls, vec![]));

    assert_that(&err).starts_with("Failed to merge multiple dependencies on lazy_static");
    assert_that(&err).contains("Can't merge different git versions of the same dependency");
    assert_that(&err).contains("https://github.com/some-fork/lazy-static.rs.git");
    assert_that(&err).contains("https://github.com/rust-lang-nursery/lazy-static.rs.git");
}

#[test]
fn can_have_just_packages() {
    let packages = vec![Package {
        name: String::from("serde"),
        semver: VersionReq::parse("^1").unwrap(),
        features: vec![String::from("derive")],
    }];

    let want_deps = indoc! {r#"
    serde = { version = ">=1.0.0, <2.0.0", default-features = true, features = ["derive"] }
    "#};

    let want_labels_to_deps = BTreeMap::new();

    test(BTreeMap::new(), packages, want_deps, want_labels_to_deps);
}

#[test]
fn can_add_packages() {
    let cargo_toml = indoc! { r#"
    [package]
    name = "frobber"
    version = "0.1.0"

    [dependencies]
    # Normalises string or map values
    lazy_static = { version = "1" }
    "# };

    let cargo_tomls = btreemap! { "//some:Cargo.toml" => cargo_toml };

    let packages = vec![Package {
        name: String::from("serde"),
        semver: VersionReq::parse("^1.0.57").unwrap(),
        features: vec![String::from("derive")],
    }];

    let want_deps = indoc! {r#"
    lazy_static = { version = ">=1.0.0, <2.0.0", default-features = true, features = [] }
    serde = { version = ">=1.0.57, <2.0.0", default-features = true, features = ["derive"] }
    "#};

    let want_labels_to_deps = btreemap! {
        "//some:Cargo.toml" => btreeset!{
            "lazy_static",
        },
    };

    test(cargo_tomls, packages, want_deps, want_labels_to_deps);
}

#[test]
fn package_conflicts_are_errors() {
    let cargo_toml = indoc! { r#"
    [package]
    name = "frobber"
    version = "0.1.0"

    [dependencies]
    # Normalises string or map values
    lazy_static = { version = "1" }
    "# };

    let cargo_tomls = btreemap! { "//some:Cargo.toml" => cargo_toml };

    let packages = vec![Package {
        name: String::from("lazy_static"),
        semver: VersionReq::parse("^1").unwrap(),
        features: vec![],
    }];

    let err = expect_err(cargo_tomls, packages);

    assert_eq!(
        String::from("The following package was provided both in a Cargo.toml and in the crate_universe repository rule: lazy_static."),
        format!("{}", err)
    );
}

#[test]
fn applies_overrides() {}

fn test(
    input: BTreeMap<&str, &str>,
    additional_packages: Vec<Package>,
    want_deps: &str,
    want_labels_to_deps: BTreeMap<&str, BTreeSet<&str>>,
) -> toml::Value {
    let labels_to_cargo_tomls = write_cargo_tomls_to_disk(input);

    let (merged_cargo_toml, labels_to_deps) = merge_cargo_tomls(
        labels_to_cargo_tomls
            .iter()
            .map(|(label, file)| (label.clone(), file.path().to_owned()))
            .collect(),
        additional_packages,
    )
    .unwrap();

    let value = toml::Value::from(merged_cargo_toml);
    assert_eq!(
        value.as_table().unwrap().get("dependencies").unwrap(),
        &want_deps.parse::<toml::Value>().unwrap(),
    );

    assert_eq!(
        labels_to_deps,
        want_labels_to_deps
            .into_iter()
            .map(|(k, vs)| (k.to_owned(), vs.into_iter().map(|v| v.to_owned()).collect()))
            .collect()
    );

    value
}

fn expect_err(
    cargo_tomls: BTreeMap<&str, &str>,
    additional_packages: Vec<Package>,
) -> anyhow::Error {
    let labels_to_cargo_tomls = write_cargo_tomls_to_disk(cargo_tomls);

    merge_cargo_tomls(
        labels_to_cargo_tomls
            .iter()
            .map(|(label, file)| (label.clone(), file.path().to_owned()))
            .collect(),
        additional_packages,
    )
    .expect_err("Want error")
}

fn write_cargo_tomls_to_disk(input: BTreeMap<&str, &str>) -> BTreeMap<String, NamedTempFile> {
    input
        .into_iter()
        .map(|(label, cargo_toml)| {
            (
                label.to_owned(),
                NamedTempFile::with_str_content("Cargo.toml", cargo_toml).unwrap(),
            )
        })
        .collect::<BTreeMap<_, _>>()
}
