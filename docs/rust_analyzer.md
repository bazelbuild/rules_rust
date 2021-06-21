<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Rust Analyzer

* [rust_analyzer](#rust_analyzer)
* [rust_analyzer_aspect](#rust_analyzer_aspect)


## Overview

For [non-Cargo projects](https://rust-analyzer.github.io/manual.html#non-cargo-based-projects),
[rust-analyzer](https://rust-analyzer.github.io/) depends on a `rust-project.json` file at the
root of the project that describes its structure. The `rust_analyzer` rule facilitates generating 
such a file.

### Setup

First, add the following to the `WORKSPACE` file:

```python
load("@rules_rust//tools/rust_analyzer:deps.bzl", "rust_analyzer_deps")

rust_analyzer_deps()
```

Next, add the following lines to the `.bazelrc` file of your workspace:
```
build --repo_env=RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS=true
```

This will ensure rust source code is available to `rust-analyzer`. Users
can also set `include_rustc_srcs = True` on any `rust_repository` or
`rust_repositories` calls in the workspace but the environment variable
has higher priority and can override the attribute.

Finally, add a rule to the root `BUILD` file like the following.

```python
load("@rules_rust//rust:defs.bzl", "rust_analyzer")

rust_analyzer(
    name = "rust_analyzer",
    targets = [
        # all the binary/library targets you want in the rust-project.json
    ],
)
```

A list of `rust_analyzer` compatible targets can be found by usign the following query:

```bash
bazel query 'kind("rust_*library|rust_binary", //...:all)'
```

Note that visibility rules apply.

Run `bazel run @rules_rust//tools/rust_analyzer:gen_rust_project` whenever
dependencies change to regenerate the `rust-project.json` file. It should be
added to `.gitignore` because it is effectively a build artifact. Once the
`rust-project.json` has been generated in the project root, rust-analyzer can
pick it up upon restart.

#### VSCode

To set this up using [VSCode](https://code.visualstudio.com/), users should first install the
[rust_analyzer plugin](https://marketplace.visualstudio.com/items?itemName=matklad.rust-analyzer).
With that in place, the following task can be added to the `.vscode/tasks.json` file of the workspace
to ensure a `rust-project.json` file is created and up to date when the editor is opened.

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Generate rust-project.json",
            "command": "bazel",
            "args": ["run", "@rules_rust//tools/rust_analyzer:gen_rust_project"],
            "options": {
                "cwd": "${workspaceFolder}"
            },
            "group": "build",
            "problemMatcher": [],
            "presentation": {
                "reveal": "never",
                "panel": "dedicated",
            },
            "runOptions": {
                "runOn": "folderOpen"
            }
        },
    ]
}
```


<a id="#rust_analyzer"></a>

## rust_analyzer

<pre>
rust_analyzer(<a href="#rust_analyzer-name">name</a>, <a href="#rust_analyzer-targets">targets</a>)
</pre>

Produces a rust-project.json for the given targets. Configure rust-analyzer to load the generated file via the linked projects mechanism.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_analyzer-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="rust_analyzer-targets"></a>targets |  List of all targets to be included in the index   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a id="#rust_analyzer_aspect"></a>

## rust_analyzer_aspect

<pre>
rust_analyzer_aspect(<a href="#rust_analyzer_aspect-name">name</a>)
</pre>

Annotates rust rules with RustAnalyzerInfo later used to build a rust-project.json

**ASPECT ATTRIBUTES**


| Name | Type |
| :------------- | :------------- |
| deps| String |
| proc_macro_deps| String |
| crate| String |


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="rust_analyzer_aspect-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |   |


