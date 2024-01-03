""" Crate Annotation for syn """

load("@rules_rust//crate_universe:defs.bzl", "crate")

ANNOTATION = crate.annotation(
    crate_features = [
        "clone-impls",
        "derive",
        "extra-traits",
        "fold",
        "full",
        "parsing",
        "printing",
        "proc-macro",
        "visit-mut",
        "visit",
    ],
)
