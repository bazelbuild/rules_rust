# Rust rules
* [rust_workspace](#rust_workspace)
* [bazel_version](#bazel_version)

<a id="#rust_workspace"></a>

## rust_workspace

<pre>
rust_workspace()
</pre>

A helper macro for setting up requirements for `rules_rust` within a given workspace.

This macro should always loaded and invoked after `rust_repositories` within a WORKSPACE
file.

**PARAMETERS**



