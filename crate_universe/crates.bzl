"""**DEPRECATED** - Instead, use `@rules_rust//crate_universe:repositories.bzl"""

load(":repositories.bzl", "crate_universe_dependencies")

def crate_deps_repository(**kwargs):
    # buildifier: disable=print
    print("`crate_deps_repository` is deprecated. See setup instructions for how to update: https://bazelbuild.github.io/rules_rust/crate_universe.html#setup")
    crate_universe_dependencies(**kwargs)
