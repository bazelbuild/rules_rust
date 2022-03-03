"""# Rules

- [crates_repository](#crates_repository)
- [crates_vendor](#crates_vendor)
- [crate.spec](#cratespec)
- [crate.workspace_member](#crateworkspace_member)
- [crate.annotation](#crateannotation)
- [render_config](#render_config)
- [splicing_config](#splicing_config)

"""

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
)
load(
    "//crate_universe/private:generate_utils.bzl",
    _render_config = "render_config",
)
load(
    "//crate_universe/private:splicing_utils.bzl",
    _splicing_config = "splicing_config",
)

crate = _crate
crates_repository = _crates_repository
crates_vendor = _crates_vendor
render_config = _render_config
splicing_config = _splicing_config
