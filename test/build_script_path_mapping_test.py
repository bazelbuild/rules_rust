#!/usr/bin/env python3

import json
import sys


CRATE_NAME_ARGUMENT = "--crate-name=dep_of_a_build_script"


def path_for_fragment(path_fragments, fragment_id):
    labels = []
    while fragment_id:
        fragment = path_fragments[fragment_id]
        labels.append(fragment["label"])
        fragment_id = fragment.get("parentId")
    return "/".join(reversed(labels))


def artifact_paths(action_graph, artifact_ids):
    artifacts = {artifact["id"]: artifact for artifact in action_graph["artifacts"]}
    path_fragments = {
        fragment["id"]: fragment
        for fragment in action_graph["pathFragments"]
    }
    return sorted(
        path_for_fragment(path_fragments, artifacts[artifact_id]["pathFragmentId"])
        for artifact_id in artifact_ids
    )


def strip_config_segment(path):
    segments = path.split("/")
    if len(segments) > 2 and segments[0] in ("bazel-out", "blaze-out"):
        segments[1] = "cfg"
    return "/".join(segments)


def input_paths(action_graph, dep_set_ids):
    dep_sets = {dep_set["id"]: dep_set for dep_set in action_graph["depSetOfFiles"]}
    artifact_ids = set()
    pending = list(dep_set_ids)
    while pending:
        dep_set = dep_sets[pending.pop()]
        artifact_ids.update(dep_set.get("directArtifactIds", []))
        pending.extend(dep_set.get("transitiveDepSetIds", []))
    return artifact_paths(action_graph, artifact_ids)


def normalized_action(action_graph, action):
    # aquery's actionKey preserves the unmodified configuration segments. Compare
    # the fields used to construct the path-mapped spawn instead.
    return {
        "arguments": action.get("arguments", []),
        "environmentVariables": sorted(
            action.get("environmentVariables", []),
            key=lambda variable: (variable["key"], variable.get("value", "")),
        ),
        "executionInfo": sorted(
            action.get("executionInfo", []),
            key=lambda entry: (entry["key"], entry.get("value", "")),
        ),
        "executionPlatform": action.get("executionPlatform"),
        "inputs": sorted(
            strip_config_segment(path)
            for path in input_paths(action_graph, action.get("inputDepSetIds", []))
        ),
        "outputs": sorted(
            strip_config_segment(path)
            for path in artifact_paths(action_graph, action.get("outputIds", []))
        ),
        "paramFiles": action.get("paramFiles", []),
    }


def process_wrapper_inputs(action_graph, action):
    return [
        path
        for path in input_paths(action_graph, action.get("inputDepSetIds", []))
        if path.endswith("/util/process_wrapper/process_wrapper")
    ]


def fail(message, details=None):
    if details is not None:
        message += "\n" + json.dumps(details, indent=2, sort_keys=True)
    raise AssertionError(message)


def main():
    action_graph = json.load(sys.stdin)
    crate_actions = [
        action
        for action in action_graph.get("actions", [])
        if CRATE_NAME_ARGUMENT in action.get("arguments", [])
    ]
    # rust_binary adds each dependency to deps and proc_macro_deps so filter_deps
    # can select the dependency with the required provider. The proc_macro_deps
    # action remains in aquery but is not an input to the build script binary.
    actions = [
        action
        for action in crate_actions
        if "--codegen=opt-level=0" in action.get("arguments", [])
    ]
    if len(actions) != 2:
        fail("Expected two fastbuild dep_of_a_build_script Rustc actions", crate_actions)

    configuration_ids = {action.get("configurationId") for action in actions}
    if len(configuration_ids) != 2:
        fail("Expected target and exec configurations", actions)

    normalized_actions = [
        normalized_action(action_graph, action)
        for action in actions
    ]
    execution_info = normalized_actions[0]["executionInfo"]
    if not any(entry["key"] == "supports-path-mapping" for entry in execution_info):
        fail("Expected supports-path-mapping execution info", execution_info)

    if normalized_actions[0] != normalized_actions[1]:
        fail(
            "Expected identical path-mapped target and build-script dependency spawns",
            normalized_actions,
        )

    process_wrappers = [
        process_wrapper_inputs(action_graph, action)
        for action in actions
    ]
    if process_wrappers[0] != process_wrappers[1]:
        fail(
            "Expected target and build-script dependencies to use the same process_wrapper",
            process_wrappers,
        )


if __name__ == "__main__":
    main()
