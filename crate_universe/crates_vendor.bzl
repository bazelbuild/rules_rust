"""# crates_vendor"""

load(
    "//crate_universe/private:crates_vendor.bzl",
    _crates_vendor = "crates_vendor",
)

crates_vendor = _crates_vendor
