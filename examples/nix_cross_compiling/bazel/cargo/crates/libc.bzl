""" Crate Annotation for libc """

load("@rules_rust//crate_universe:defs.bzl", "crate")

ANNOTATION = crate.annotation(
    rustc_flags = crate.select(
        [
            "--cfg=freebsd11",
            "--cfg=libc_priv_mod_use",
            "--cfg=libc_union",
            "--cfg=libc_const_size_of",
            "--cfg=libc_align",
            "--cfg=libc_int128",
            "--cfg=libc_core_cvoid",
            "--cfg=libc_packedN",
            "--cfg=libc_cfg_target_vendor",
            "--cfg=libc_non_exhaustive",
            "--cfg=libc_long_array",
            "--cfg=libc_ptr_addr_of",
            "--cfg=libc_underscore_const_names",
            "--cfg=libc_const_extern_fn",
        ],
        # Shoehorning in a fake `feature` for coverage of `crate.select()`.
        {
            "x86_64-unknown-nixos-gnu": [
                "--cfg=fake_nioxs_feature",
            ],
        },
    ),
)
