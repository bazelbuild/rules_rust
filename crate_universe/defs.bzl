"""# Crate Universe"""

load(
    "//crate_universe/private:crate.bzl",
    _crate = "crate",
)
load(
    "//crate_universe/private:crates_repository.bzl",
    _crates_repository = "crates_repository",
)
load(
    "//crate_universe/private:crates_vendor.bzl",
    _crates_vendor = "crates_vendor",
    _crates_vendor_remote_repository = "crates_vendor_remote_repository",
)
load(
    "//crate_universe/private:generate_utils.bzl",
    _render_config = "render_config",
)
load(
    "//crate_universe/private:local_crate_mirror.bzl",
    _local_crate_mirror = "local_crate_mirror",
)
load(
    "//crate_universe/private:splicing_utils.bzl",
    _splicing_config = "splicing_config",
)

# Rules
crates_repository = _crates_repository
crates_vendor = _crates_vendor

# Repository rules consumed by generated `crates.bzl` files. Exposed here
# so the generated files only `load` from this public surface, insulating
# committed vendor outputs from `//crate_universe/private:...` churn.
crates_vendor_remote_repository = _crates_vendor_remote_repository
local_crate_mirror = _local_crate_mirror

# Utility Macros
crate = _crate
render_config = _render_config
splicing_config = _splicing_config
