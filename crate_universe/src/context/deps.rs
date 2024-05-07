use crate::config::CrateId;
use crate::context::CrateContext;
use crate::select::Select;

/// Allows Dependencies to be resolved during conditional compilations.  An example
/// of a conditonal compilation would be `tokio` with the unstable flag:
/// `RUST_FLAGS='--cfg tokio_unstable' cargo build foo`
///
/// Or in bazel terms `bazel build -s --config local @crates//:tokio`
///
/// With the crate annotation looking like the following in WORKSPACE or MODULE.bazel
///
/// ## WORKSPACE
/// ```ignore
/// annotations = {
///     "tokio": [crate.annotation(
///         rustc_flags = ["--cfg", "tokio_unstable"],
///     )],
/// },
/// ```
/// ## MODULE.bazel
/// ```ignore
/// crate.annotation(
///    crate = "tokio",
///    repositories = ["crates"],
///    version = "1.28.0",
///    rustc_flags = ["--cfg", "tokio_unstable"],
/// )
/// ```
pub(super) fn resolve_cfg_deps(crate_context: &mut CrateContext) {
    let rustc_flags = get_cfg_flag_values(crate_context.common_attrs.rustc_flags.values());
    let crate_id = CrateId::new(crate_context.name.clone(), crate_context.version.clone());
    let mut new_crate_dependencies = Select::new();

    for (key, crate_feature_dep) in crate_context.common_attrs.deps.items() {
        if let Some(key) = key {
            let expr = cfg_expr::Expression::parse(&key);
            // if the key is not all, any, or not, we ignore it
            // (this causes an error in cfg-expr)
            if let Ok(expr) = expr {
                expr.eval(|pred| match pred {
                    cfg_expr::Predicate::Flag(f) => {
                        let flag_string = f.to_string();
                        if rustc_flags.contains(&flag_string) {
                            // dont want to accidently re insert the same dep
                            // as a dep dependency.
                            if crate_id != crate_feature_dep.id {
                                new_crate_dependencies.insert(crate_feature_dep.clone(), None);
                            }
                        }
                        true
                    }
                    _ => {
                        println!("Not a flag {:?}", pred);
                        false
                    }
                });
            }
            new_crate_dependencies.insert(crate_feature_dep.clone(), Some(key.clone()));
        } else {
            new_crate_dependencies.insert(crate_feature_dep.clone(), None);
        }
    }

    crate_context.common_attrs.deps = new_crate_dependencies;
}

/// We only care about the `--cfg` conditional compilation flags.  
/// An example of a conditional compilation flag is `--cfg tokio_unstable`
///
/// There could be other rustc flags, that are not lead with `--cfg`.
/// We only want to gather the conditional compilation cfg flags, and return
/// the values of those flags, so we can do a comparison to see if they exist
/// in the select dependencies, as a key value of `cfg(tokio_unstable)
fn get_cfg_flag_values(rustc_flags: Vec<String>) -> Vec<String> {
    let mut cfg_rustc_flags = vec![];
    let mut rustc_flags_peekable = rustc_flags.iter().peekable();
    while let Some(flag) = rustc_flags_peekable.next() {
        if flag == "--cfg" {
            if let Some(next_flag) = rustc_flags_peekable.peek() {
                cfg_rustc_flags.push(next_flag.to_string());
            }
        }
    }
    cfg_rustc_flags
}
