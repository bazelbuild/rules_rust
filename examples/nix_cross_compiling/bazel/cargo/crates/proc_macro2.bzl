""" Crate Annotation for proc-macro2 """

load("@rules_rust//crate_universe:defs.bzl", "crate")

ANNOTATION = crate.annotation(
    rustc_flags = [
        "--cfg=proc_macro_span",
        "--cfg=span_locations",
        "--cfg=use_proc_macro",
        "--cfg=wrap_proc_macro",
    ],
)
