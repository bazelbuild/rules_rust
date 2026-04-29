"""# crates_repository"""

load(
    "//crate_universe/private:crates_repository.bzl",
    _crates_repository = "crates_repository",
)

crates_repository = _crates_repository
