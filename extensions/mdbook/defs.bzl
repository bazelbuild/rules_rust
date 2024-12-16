"""# rules_rust_mdbook

Bazel rules for [mdBook](https://github.com/rust-lang/mdBook).

## Rules

- [mdbook](#mdbook)
- [mdbook_server](#mdbook_server)
- [mdbook_toolchain](#mdbook_toolchain)

## Setup

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# See releases for urls and checksums
http_archive(
    name = "rules_mdbook",
    integrity = "{integrity}",
    urls = ["https://github.com/abrisco/rules_mdbook/releases/download/{version}/rules_mdbook-{version}.tar.gz"],
)

load("@rules_rust_mdbook//:repositories.bzl", "mdbook_register_toolchains", "rules_mdbook_dependencies")

rules_mdbook_dependencies()

mdbook_register_toolchains()

load("@rules_rust_mdbook//:repositories_transitive.bzl", "rules_mdbook_transitive_deps")

rules_mdbook_transitive_deps()
```

---
---
"""

load(
    "//private:mdbook.bzl",
    _mdbook = "mdbook",
    _mdbook_server = "mdbook_server",
)
load(
    "//private:toolchain.bzl",
    _mdbook_toolchain = "mdbook_toolchain",
)

mdbook = _mdbook
mdbook_server = _mdbook_server
mdbook_toolchain = _mdbook_toolchain
