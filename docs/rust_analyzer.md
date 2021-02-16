# Rust rules
* [rust_analyzer](#rust_analyzer)
* [rust_analyzer_aspect](#rust_analyzer_aspect)

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


