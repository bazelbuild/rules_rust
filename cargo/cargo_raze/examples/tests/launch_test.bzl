"""This file contains a helper used for testing example targets"""

_bash_script = """\
#!/bin/bash

if [[ -f "{target}" ]]; then
    exec "{target}"
else
    exec "external/{target}"
fi
"""

# buildifier: disable=unnamed-macro
def launch_test(target):
    """Helper for creating tests meant only to launch an executable target

    Args:
        target (str): The label or package of the target to test. In the case
            of the package being passed, the target is assumed to have the
            same name.
    Returns:
        string: The name of the generated test target.
    """

    # Account for a missing target (since Buildifier will remove it if it matches the package name)
    if ":" not in target:
        target_label = Label(target + ":{}".format(target.split("/")[-1]))
    else:
        target_label = Label(target)

    name = "remote_" + target_label.name if "remote" in target else "vendored_" + target_label.name

    native.genrule(
        name = name + "_launcher",
        outs = [name + "_launcher.sh"],
        srcs = [target_label],
        cmd = "echo '{}' > $@".format(
            _bash_script.format(
                target = str(target_label).lstrip("@/").replace("//", "/").replace(":", "/"),
            ),
        ),
        tags = ["manual"],
    )

    native.sh_test(
        name = name + "_launch_test",
        size = "small",
        srcs = [
            name + "_launcher",
        ],
        data = [
            target_label,
        ],
    )

    return name + "_launch_test"
