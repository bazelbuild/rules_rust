//! Command line tool invoked by Bazel to read metadata out of a `Cargo.toml` file.
//!
//! This tool should _not_ be used to determine dependencies, features, or generally any build
//! information for a crate, that should live in crate_universe. This tool is intended to read
//! non-build related Cargo metadata like lints, authors, or badges.

use cargo_toml::{Lint, LintLevel, Manifest};

use std::borrow::Cow;
use std::collections::BTreeMap;
use std::error::Error;
use std::fs::File;
use std::io::{LineWriter, Write};
use std::path::PathBuf;

pub fn main() -> Result<(), Box<dyn Error>> {
    let Args {
        manifest_toml,
        workspace_toml,
        command,
    } = Args::try_from(std::env::args())?;

    let manifest_contents = std::fs::read_to_string(&manifest_toml)?;
    let mut crate_manifest = Manifest::from_str(&manifest_contents)?;
    let mut workspace_manifest = None;

    // Optionally populate the manifest with info from the parent workspace, if one is provided.
    if let Some(workspace_path) = workspace_toml {
        let manifest = Manifest::from_path(&workspace_path)?;
        let workspace_details = Some((&manifest, workspace_path.as_path()));

        // TODO(parkmycar): Fix cargo_toml so we inherit lints from our workspace.
        crate_manifest.complete_from_path_and_workspace(&manifest_toml, workspace_details)?;
        workspace_manifest = Some(manifest);
    }

    match command {
        Command::Lints(args) => {
            generate_lints_info(&crate_manifest, workspace_manifest.as_ref(), args)?
        }
    }

    Ok(())
}

#[derive(Debug)]
struct LintsArgs {
    output_rustc_lints: PathBuf,
    output_clippy_lints: PathBuf,
    output_rustdoc_lints: PathBuf,
    // TODO(parkmycar): Support Rust's new --check-cfg once cargo-toml is updated.
    #[allow(dead_code)]
    output_rustc_check_cfg: PathBuf,
}

enum LintGroup {
    Rustc,
    RustCheckCfg,
    Clippy,
    RustDoc,
}

impl LintGroup {
    pub fn key(&self) -> &'static str {
        match self {
            LintGroup::Rustc => "rust",
            LintGroup::RustCheckCfg => "check-cfg",
            LintGroup::Clippy => "clippy",
            LintGroup::RustDoc => "rustdoc",
        }
    }

    /// Format a lint `name` and `level` for this [`LintGroup`].
    pub fn format_cli_arg(&self, name: &str, level: LintLevel) -> String {
        let level = match level {
            LintLevel::Allow => "allow",
            LintLevel::Warn => "warn",
            LintLevel::Forbid => "forbid",
            LintLevel::Deny => "deny",
        };

        match self {
            LintGroup::Rustc => format!("--{level}={name}"),
            LintGroup::Clippy => format!("--{level}=clippy::{name}"),
            LintGroup::RustDoc => format!("--{level}=rustdoc::{name}"),
            // TODO: Support check-cfg once cargo_toml supports it.
            LintGroup::RustCheckCfg => "".to_string(),
        }
    }
}

/// Generates space seperated <lint name> <lint level> files that get read back in by Bazel.
fn generate_lints_info(
    crate_manifest: &Manifest,
    workspace_manifest: Option<&Manifest>,
    args: LintsArgs,
) -> Result<(), Box<dyn Error>> {
    fn format_lint_set<'g, 'l: 'g>(
        lints: &'l BTreeMap<String, BTreeMap<String, Lint>>,
        group: &'g LintGroup,
    ) -> Option<impl Iterator<Item = String> + 'g> {
        let lints = lints.get(group.key())?;

        let formatted = lints.iter().map(|(name, lint)| {
            let level = match lint {
                cargo_toml::Lint::Detailed { level, priority: _ } => level,
                cargo_toml::Lint::Simple(level) => level,
            };
            group.format_cli_arg(name, *level)
        });

        Some(formatted)
    }

    let LintsArgs {
        output_rustc_lints,
        output_rustc_check_cfg,
        output_clippy_lints,
        output_rustdoc_lints,
    } = args;

    let groups = [
        (LintGroup::Rustc, output_rustc_lints),
        (LintGroup::Clippy, output_clippy_lints),
        (LintGroup::RustDoc, output_rustdoc_lints),
        (LintGroup::RustCheckCfg, output_rustc_check_cfg),
    ];

    let lints = match &crate_manifest.lints {
        Some(lints) if lints.workspace => {
            let workspace = workspace_manifest
                .as_ref()
                .and_then(|manifest| manifest.workspace.as_ref())
                .ok_or_else(|| {
                    "manifest inherits lints from the workspace, but no workspace manifest provided"
                })?;
            workspace.lints.as_ref()
        }
        Some(lints) => Some(&lints.groups),
        None => None,
    };
    let Some(lints) = lints else {
        return Ok(());
    };

    for (group, path) in groups {
        let file = File::create(&path)?;
        let mut writer = LineWriter::new(file);

        if let Some(args) = format_lint_set(&lints, &group) {
            for arg in args {
                writeln!(&mut writer, "{arg}")?;
            }
        };

        writer.flush()?;
    }

    Ok(())
}

#[derive(Debug)]
struct Args {
    manifest_toml: PathBuf,
    workspace_toml: Option<PathBuf>,
    command: Command,
}

impl TryFrom<std::env::Args> for Args {
    type Error = Cow<'static, str>;

    fn try_from(mut args: std::env::Args) -> Result<Self, Self::Error> {
        let _binary_path = args
            .next()
            .ok_or_else::<Cow<'static, str>, _>(|| "provided 0 arguments?".into())?;

        let mut args = args.peekable();

        // We get at least 'manifest-toml', and optionally a 'workspace-toml'.
        let manifest_raw_arg = args
            .next()
            .ok_or(Cow::Borrowed("expected at least one arg"))?;
        let manifest_toml =
            try_parse_named_arg(&manifest_raw_arg, "manifest_toml").map(PathBuf::from)?;
        let workspace_toml = args
            .peek()
            .and_then(|arg| try_parse_named_arg(&arg, "workspace_toml").ok())
            .map(PathBuf::from);
        // If we got a workspace_toml arg make sure to consume it.
        if workspace_toml.is_some() {
            args.next();
        }

        // Use the remaining arguments to parse our command.
        let command = Command::try_from(RemainingArgs(args))?;

        Ok(Args {
            manifest_toml,
            workspace_toml,
            command,
        })
    }
}

/// Tries to parse the value from a named arg.
fn try_parse_named_arg<'a, 'n>(arg: &'a str, name: &'n str) -> Result<&'a str, String> {
    arg.strip_prefix(&format!("--{name}="))
        .ok_or_else(|| format!("expected --{name}=<value>, found '{arg}'"))
}

/// Arguments that are remaining after parsing the path to the `Cargo.toml`.
struct RemainingArgs(std::iter::Peekable<std::env::Args>);

#[derive(Debug)]
enum Command {
    /// Expects 4 filesystem paths in this order:
    ///
    /// 1. output for rustc lints
    /// 2. output for rust check-cfg lints
    /// 3. output for clippy lints
    /// 4. output for rustdoc lints
    ///
    Lints(LintsArgs),
}

impl TryFrom<RemainingArgs> for Command {
    type Error = Cow<'static, str>;

    fn try_from(args: RemainingArgs) -> Result<Self, Self::Error> {
        let RemainingArgs(args) = args;
        let mut args = args.peekable();

        let action = args
            .next()
            .ok_or_else::<Cow<'static, str>, _>(|| "expected an action".into())?;

        match action.to_lowercase().as_str() {
            "lints" => {
                let output_rustc_lints = args
                    .next()
                    .map(PathBuf::from)
                    .ok_or(Cow::Borrowed("expected output path for rustc lints"))?;
                let output_rustc_check_cfg = args
                    .next()
                    .map(PathBuf::from)
                    .ok_or(Cow::Borrowed("expected output path for rustc check-cfg"))?;
                let output_clippy_lints = args
                    .next()
                    .map(PathBuf::from)
                    .ok_or(Cow::Borrowed("expected output path for clippy lints"))?;
                let output_rustdoc_lints = args
                    .next()
                    .map(PathBuf::from)
                    .ok_or(Cow::Borrowed("expected output path for rustdoc lints"))?;

                if args.peek().is_some() {
                    let remaining: Vec<String> = args.collect();
                    let msg = format!("expected end of arguments, found: {remaining:?}");
                    return Err(Cow::Owned(msg));
                }

                Ok(Command::Lints(LintsArgs {
                    output_rustc_lints,
                    output_rustc_check_cfg,
                    output_clippy_lints,
                    output_rustdoc_lints,
                }))
            }
            other => Err(format!("unknown action: {other}").into()),
        }
    }
}
