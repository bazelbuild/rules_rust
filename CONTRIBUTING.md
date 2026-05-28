Want to contribute? Great! First, read this page.

## Before you contribute
**Before we can use your code, you must sign the
[Google Individual Contributor License Agreement](https://developers.google.com/open-source/cla/individual?csw=1)
(CLA)**, which you can do online.

The CLA is necessary mainly because you own the copyright to your changes,
even after your contribution becomes part of our codebase, so we need your
permission to use and distribute your code. We also need to be sure of
various other things — for instance that you'll tell us if you know that
your code infringes on other people's patents. You don't have to sign
the CLA until after you've submitted your code for review and a member has
approved it, but you must do it before we can put your code into our codebase.

Before you start working on a larger contribution, you should get in touch
with us first. Use the issue tracker to explain your idea so we can help and
possibly guide you.

**Contributions made by corporations are covered by a different agreement than
the one above, the
[Software Grant and Corporate Contributor License Agreement](https://cla.developers.google.com/about/google-corporate).**

## Code Reviews and Contributing PRs
**All submissions, including submissions by project members, require review.**

### AI Generated Contributions
**To ensure maintainability & sustainability of rules_rust in the LLM era, we’re adopting LLVM’s AI tools [policy](https://llvm.org/docs/AIToolPolicy.html).** As a short summary, when contributing to `rules_rust` you are expected to:
* **Understand and Own the Code**: You may use AI tools, but you are fully accountable for the work. You must thoroughly read, understand, and self-review all content before submitting it for review.
* **Learn from Feedback**: When maintainers review your work, use their feedback as a human learning opportunity to grow your skills, rather than simply funneling their comments back into an LLM to generate a quick fix.
* **Be Transparent**: Clearly label any contribution that contains a substantial amount of AI-generated content (e.g., using an Assisted-by commit trailer).

### Public Interface changes
**If your proposed change affects an existing or adds a public API (e.g new attribute, new build setting), please file an issue explaining the problem space & proposed design first.**

As Rust & Bazel are seeing increased adoption in the industry, we see more and more PRs that add/enhance the public facing interface of rules_rust (e.g new attributes, new rules, new build settings). Sometimes such PRs are near-universally beneficial, other times they address specific/narrow use cases. In its present shape, the core ruleset does not provide a sufficient level of configurability so that the latter use cases can be addressed locally. We will soon start a [redesign](https://github.com/bazelbuild/rules_rust/issues/4049) of the core ruleset that aims to allow for sufficient configurability so that users can address their own needs without expanding the rules_rust API surface.

### Adding New Rules
**We do not accept new non-core rules to the `rules_rust` repository.**

In its current state, rules_rust contains functionality broader than most rulesets: in addition to a core ruleset, it also contains functionality for automated `BUILD`/`bzl` file generation for crates, IDE integration via `rust-analyzer`, docs generation via `rustdoc`, C++ interop via `bindgen`, Js/Ts interop via `wasm_bindgen` etc.  At present time there are areas that the maintainers don’t have sufficient expertise in, or where there is a single maintainer that can meaningfully act on incoming PRs and issues, making it difficult for interested parties to contribute. To address this, we will be splitting the non-core rulesets into separate repositories. This will allow for additional maintainers to join specific areas. For areas where we don’t find maintainers, we’ll deprecate and retire.

#### Core Rules
Rules used to compile Rust code.
* `rust_library`
* `rust_binary`
* `rust_test`
* `rust_static_library`
* `rust_shared_library`
* `rust_proc_macro`
* `cargo_build_script`

### Unowned / Undermaintained / Undertested areas
There are areas of `rules_rust` that no maintainers currently have expertise in. For these areas, expect some friction during contribution:
* `prost`
Best effort maintenance, long term these rules will not live in rules_rust. If you’re interested in taking over maintenance please reach out.
* `wasm-bindgen`
Best effort maintenance, long term these rules will not live in rules_rust. If you’re interested in taking over maintenance please reach out.
* Windows as host
Best effort maintenance, with no capability / bandwidth to help contributors. Experts willing to help review PRs would be much appreciated!
* Platforms other than Linux / MacOS / Windows
Best effort maintenance, no CI testing.

### Testing
A PR should contain tests for the change where feasible.

### Stale PRs and Issues
PRs and issues that are in awaiting-response state for more than 90 days will be closed as inactive.

