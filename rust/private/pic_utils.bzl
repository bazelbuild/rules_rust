"""Utilities related to Position Independent Code/Executables (PIC/PIE)"""

_NON_PIE_OS_KEYWORDS = [
    "windows",
    "uefi",
    "vxworks",
    "solaris",
    "illumos",
    "helenos",
    "cygwin",
    "l4re",
    "lynxos178",
    "aix",
    "cuda",
]

_NON_PIE_ARCH_PREFIXES = [
    "wasm",
    "xtensa",
    "nvptx",
    "amdgcn",
    "msp430",
    "avr",
]

_NON_PIE_ENV_KEYWORDS = [
    "nuttx",
    "espidf",
    "rtems",
    "xous",
    "zkvm",
    "qurt",
    "psp",
    "psx",
    "vita",
    "3ds",
    "vex",
]

def parse_rustc_version(version_semver):
    """Convert a parsed semver struct into the (major, minor, patch) tuple used for version comparisons.

    A `None` input (channel labels like "nightly"/"beta" and unset versions
    don't parse as semver) returns a sentinel representing "latest", since
    nightly and beta are always at or ahead of the most recent stable release.

    Args:
        version_semver: A semver struct from `rust/private/semver.bzl`, typically
            `toolchain.version_semver`, or `None`.

    Returns:
        A (major, minor, patch) tuple of ints.
    """
    if not version_semver:
        return (999, 0, 0)
    return (version_semver.major, version_semver.minor, version_semver.patch)

def produces_pie_binaries(
        target_triple,
        rust_version):
    """Returns True if rustc links binaries as Position Independent Executables.

    The truth table here is a port of the per-target `position_independent_executables`
    field that rustc sets in its target specs. The constants and special cases
    below were derived from analyzing
    https://github.com/rust-lang/rust/tree/1.95.0/compiler/rustc_target/src/spec/base
    across Rust 1.0.0-1.95.0.

    ## When to update

    Add or revise an entry here whenever any of the following happens upstream:

    - A new Rust release flips `position_independent_executables` on or off for
      some target (most commonly via a base spec like `linux_musl_base.rs`).
    - A new target triple is stabilized.
    - rustc's PIE default itself changes (rare, but happens — e.g. the bpf
      targets gained PIE in 1.75.0).

    A divergence here typically shows up as a link error: rustc-emitted PIC/PIE
    objects mixed with non-PIE intermediate rlibs (or vice versa).

    ## How to perform the analysis

    rustc target specs live under `compiler/rustc_target/src/spec/`. Each
    triple has a `targets/<triple>.rs` that returns a `Target` whose `options`
    field is usually built from one of the shared bases under `spec/base/`
    (e.g. `linux_gnu_base.rs`, `apple_base.rs`, `freebsd_base.rs`).

    The decision tree for a given triple is:

    1. Open `compiler/rustc_target/src/spec/targets/<triple>.rs` and follow
       which `base::*` it calls into.
    2. In that base file, look for `position_independent_executables: true`
       (or the field being overridden back to `false` after the base sets it).
       Some triples override the base's value directly in their own
       `targets/<triple>.rs` — check there too.
    3. To find the Rust release where the value changed, `git log -p -S
       'position_independent_executables' compiler/rustc_target/src/spec/`
       in a rust-lang/rust checkout and cross-reference the commit's first
       containing release tag (e.g. `git tag --contains <sha> | sort -V | head -1`).
    4. Cross-check with the `arm-linux-androideabi`, `x86_64-unknown-haiku`,
       and `nto` entries below — those are the existing examples of
       version-gated PIE flips and are the right shape to copy.

    Three buckets cover the bulk of the matrix without per-triple cases; only
    add a special case here when a triple is genuinely an outlier:

    - **`_NON_PIE_OS_KEYWORDS`** — operating systems whose base spec sets
      PIE off. Matched against any `-` separated component of the triple
      (i.e. exact-segment match). Add an entry if a *new OS* lands and its
      base spec sets `position_independent_executables: false` (or omits it,
      since the default is false).
    - **`_NON_PIE_ARCH_PREFIXES`** — architectures whose base spec sets PIE
      off. Matched as a prefix of the first triple component (the arch),
      because variants like `wasm32`/`wasm64` and `nvptx64` share a base.
    - **`_NON_PIE_ENV_KEYWORDS`** — embedded/environment markers whose base
      spec sets PIE off. Substring match against the full triple, because
      these often appear concatenated with the OS (e.g. `nuttx` in
      `aarch64-nuttx-elf`).

    Args:
        target_triple: A parsed target triple struct (see `rust/platform/triple.bzl`),
            typically `toolchain.target_triple`. Provides `arch`, `vendor`, `system`,
            `abi`, and `str` fields.
        rust_version: (major, minor, patch) tuple, e.g. (1, 93, 0).

    Returns:
        True if rustc will pass -pie to the linker for this target.
    """
    if target_triple.vendor == "apple":
        return True

    version = parse_rustc_version(rust_version)

    if target_triple.system == "none":
        if target_triple.arch in ("bpfeb", "bpfel"):
            return version >= (1, 75, 0)
        if target_triple.str == "x86_64-unknown-none":
            return True
        return False

    if target_triple.system in _NON_PIE_OS_KEYWORDS:
        return False

    for prefix in _NON_PIE_ARCH_PREFIXES:
        if target_triple.arch.startswith(prefix):
            return False

    # Env keywords use substring match against the full triple string because
    # they sometimes appear in 4+-segment triples (e.g. "rtems" in
    # "armv7-unknown-trappist-rtems-eabihf") that don't land cleanly in any
    # single struct field.
    for keyword in _NON_PIE_ENV_KEYWORDS:
        if keyword in target_triple.str:
            return False
    if "solid" in target_triple.str:
        return False

    if target_triple.str == "i686-unknown-haiku":
        return False
    if target_triple.vendor == "unikraft":
        return False

    if target_triple.str == "x86_64-unknown-haiku":
        return version >= (1, 29, 0)
    if target_triple.str == "arm-linux-androideabi":
        return version >= (1, 1, 0)

    if target_triple.abi == "musl" and target_triple.system == "linux":
        if target_triple.arch.startswith("mips"):
            return True
        return version >= (1, 21, 0)
    if target_triple.system == "freebsd":
        return version >= (1, 8, 0)
    if target_triple.system == "hermit":
        return version >= (1, 40, 0)
    if target_triple.system == "redox":
        return version >= (1, 38, 0)
    if target_triple.system == "nto":
        return version >= (1, 75, 0)

    return True

def should_use_pic(
        *,
        cc_toolchain,
        feature_configuration,
        crate_type,
        compilation_mode,
        toolchain):
    """Whether or not [PIC][pic] should be enabled

    [pic]: https://en.wikipedia.org/wiki/Position-independent_code

    Args:
        cc_toolchain (CcToolchainInfo): The current `cc_toolchain`.
        feature_configuration (FeatureConfiguration): Feature configuration to be queried.
        crate_type (str): A Rust target's crate type.
        compilation_mode: The compilation mode.
        toolchain (rust_toolchain): The current `rust_toolchain`, used to derive
            the target triple and rustc version for PIE detection.

    Returns:
        bool: Whether or not [PIC][pic] should be enabled.
    """

    # We use the same logic to select between `pic` and `nopic` outputs as the C++ rules:
    # - For shared libraries - we use `pic`. This covers `dylib`, `cdylib` and `proc-macro` crate types.
    # - In `fastbuild` and `dbg` mode we use `pic` by default.
    # - In `opt` mode we use `nopic` outputs to build binaries.
    if cc_toolchain and crate_type in ("cdylib", "dylib", "proc-macro"):
        return cc_toolchain.needs_pic_for_dynamic_libraries(feature_configuration = feature_configuration)
    elif compilation_mode in ("fastbuild", "dbg"):
        return True

    # In opt mode, rustc links executables with -pie on most platforms.
    # Any CC objects linked into a PIE binary must be PIC, including those
    # embedded in intermediate rlibs, so this applies to all crate types.
    # target_triple is None when a custom target JSON spec is used.
    if toolchain.target_triple:
        if produces_pie_binaries(toolchain.target_triple, toolchain.version_semver):
            return True
    return False
