<!-- Generated with Stardoc: http://skydoc.bazel.build -->
# Settings

* [incompatible_flag](#incompatible_flag)
* [fail_when_enabled](#fail_when_enabled)

<a id="#fail_when_enabled"></a>

## fail_when_enabled

<pre>
fail_when_enabled(<a href="#fail_when_enabled-name">name</a>, <a href="#fail_when_enabled-flag">flag</a>)
</pre>

A rule that will fail analysis when a flag is enabled.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="fail_when_enabled-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="fail_when_enabled-flag"></a>flag |  The incompatible flag to check   | String | required |  |


<a id="#incompatible_flag"></a>

## incompatible_flag

<pre>
incompatible_flag(<a href="#incompatible_flag-name">name</a>, <a href="#incompatible_flag-issue">issue</a>)
</pre>

A rule defining an incompatible flag.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="incompatible_flag-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="incompatible_flag-issue"></a>issue |  The link to the github issue associated with this flag   | String | required |  |


