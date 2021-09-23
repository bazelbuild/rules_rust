//! A cli utility that's used to replace format strings in a file with
//! Bazel volatile status info. For more details, see the [Bazel workspace-status][ws]
//! documentation.
//!
//! [ws]: https://docs.bazel.build/versions/main/user-manual.html#workspace_status

use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::Path;

// These constants must match those found in
// `@rules_rust//rust/private:rustc.bzl%__stamp_rustc_env_file`.
const VERSION_INFO_TXT: &str = "VERSION_INFO_TXT";
const ENV_TEMPLATE: &str = "ENV_TEMPLATE";
const ENV_OUTPUT: &str = "ENV_OUTPUT";

fn parse_version_info_file<T: AsRef<Path>>(version_file: T) -> HashMap<String, String> {
    let content = fs::read_to_string(version_file.as_ref())
        .expect("The info file provided by the `RustcEnvStamp` is either missing or malformed");

    content
        .trim()
        .split('\n')
        .into_iter()
        .map(|line| {
            let mut split = line.splitn(2, ' ');

            // "Workspace status is always expected to be `KEY VALUE`. Thus the split should return 2 items"
            let key = split.next().expect("Failed to parse workspace status line");
            let value = split.next().expect("Failed to parse workspace status line");

            (key.to_owned(), value.to_owned())
        })
        .collect()
}

fn read_template<T: AsRef<Path>>(template_file: T) -> String {
    fs::read_to_string(template_file)
        .expect("The template file provided by the `RustcEnvStamp` is either missing or malformed")
}

fn render_stamps(mut template: String, stamps: &HashMap<String, String>) -> String {
    for (stamp, data) in stamps {
        template = template.replace(&format!("{{{}}}", stamp), data);
    }
    template
}

fn write_stamp_file<T: AsRef<Path>>(template_file: T, content: String) {
    fs::write(template_file.as_ref(), content).expect("Failed to write stamped env file");
}

fn main() {
    // Gather the `volatile-status.txt` contents
    let version_file = env::var(VERSION_INFO_TXT)
        .expect("This environment variable is expected to be set by the `RustcEnvStamp` action");
    let stamps = parse_version_info_file(&version_file);

    // Locate the user provided template file
    let template_file = env::var(ENV_TEMPLATE)
        .expect("This environment variable is expected to be set by the `RustcEnvStamp` action");
    let template = read_template(template_file);

    // Resolve stamps within the template
    let stamped_template = render_stamps(template, &stamps);

    // Write the results to indicated location
    let output = env::var(ENV_OUTPUT)
        .expect("This environment variable is expected to be set by the `RustcEnvStamp` action");
    write_stamp_file(output, stamped_template);
}
