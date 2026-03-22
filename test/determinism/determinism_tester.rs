//! A tool for checking if Bazel outputs are deterministic.

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::env;
use std::fs;
use std::io::BufReader;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{anyhow, bail, Context};
use clap::Parser;
use serde::{Deserialize, Serialize};
use tokio::io::AsyncReadExt;
use tokio::task::JoinHandle;
use tracing::{debug, error, info, Level};
use tracing_subscriber::FmtSubscriber;

#[derive(Debug, Serialize, Deserialize)]
struct HashResults {
    pub execution_root: PathBuf,
    pub hashes: BTreeMap<PathBuf, String>,
}

#[derive(Parser, Debug)]
#[clap()]
struct HashArgs {
    /// The location of the Bazel binary to use for locating the `execroot`.
    #[clap(long, env = "BAZEL_REAL")]
    pub bazel: PathBuf,

    /// The location of the output_user_root to use.
    #[clap(long, env = "OUTPUT_BASE")]
    pub output_base: Option<PathBuf>,

    /// The path to the workspace to collect hashes for.
    #[clap(long, env = "BUILD_WORKSPACE_DIRECTORY")]
    pub workspace_dir: PathBuf,

    /// The location to save the output. If unspecified, outputs are logged to stdout.
    #[clap(long)]
    pub output: Option<PathBuf>,

    /// Enable verbose logging.
    #[clap(long)]
    pub verbose: bool,
}

#[derive(Parser, Debug)]
#[clap()]
struct CompareArgs {
    /// The first file to compare.
    #[clap(long)]
    pub left: PathBuf,

    /// The second file to compare against.
    #[clap(long)]
    pub right: PathBuf,

    /// Enable verbose logging.
    #[clap(long)]
    pub verbose: bool,

    /// An optional output file in which to write results.
    #[clap(long)]
    pub output: Option<PathBuf>,
}

#[derive(Parser, Debug)]
#[clap()]
struct TestArgs {
    /// The location of the Bazel binary to use for locating the `execroot`.
    #[clap(long, env = "BAZEL_REAL")]
    pub bazel: Option<PathBuf>,

    /// The url of the repository to test.
    #[clap(long, default_value = "https://github.com/bazelbuild/rules_rust.git")]
    pub url: String,

    /// The commit to test
    #[clap(long, default_value = "main")]
    pub commit: String,

    /// The directory in which to perform the test. A temp directory will be
    /// generated if unspecified
    #[clap(long)]
    pub work_dir: Option<PathBuf>,

    /// An optional output file in which to write results. A file within `work_dir`
    /// will be used if unspecified.
    #[clap(long)]
    pub output: Option<PathBuf>,

    /// Enable verbose logging.
    #[clap(long)]
    pub verbose: bool,
}

#[derive(Parser, Debug)]
enum Args {
    /// Perform a determinism test.
    Test(TestArgs),

    /// Hash all detected files in a Bazel's `execution_root`.
    Hash(HashArgs),

    /// Compare two [Args::Hash] outputs.
    Compare(CompareArgs),
}

fn init_logging(verbose: bool) {
    let subscriber = FmtSubscriber::builder()
        .with_max_level(if verbose { Level::DEBUG } else { Level::INFO })
        .finish();

    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber failed");
}

async fn compare(args: CompareArgs) -> anyhow::Result<()> {
    init_logging(args.verbose);

    let mut success = true;

    let load_results = |path: &Path| -> anyhow::Result<HashResults> {
        let reader = BufReader::new(
            fs::File::open(path)
                .with_context(|| anyhow!("Failed to open file: {}", path.display()))?,
        );
        let results: HashResults = serde_json::from_reader(reader)
            .with_context(|| anyhow!("Failed to deserialize contents at: {}", path.display()))?;
        Ok(results)
    };

    let mut results = Vec::<String>::new();
    let record_error = |container: &mut Vec<String>, error: String| {
        error!("{}", error);
        container.push(error);
    };

    let left = load_results(&args.left)?;
    let right = load_results(&args.right)?;

    // Report any new paths not found on either side
    {
        let left_keys: BTreeSet<&PathBuf> = left.hashes.keys().collect::<BTreeSet<_>>();
        let right_keys = left.hashes.keys().collect::<BTreeSet<_>>();

        let left_extras = left_keys.difference(&right_keys).collect::<BTreeSet<_>>();
        let right_extras = right_keys.difference(&left_keys).collect::<BTreeSet<_>>();

        if !left_extras.is_empty() {
            record_error(
                &mut results,
                format!("left hashes contain additional files: {:#?}", left_extras),
            );
            success = false;
        }
        if !right_extras.is_empty() {
            record_error(
                &mut results,
                format!("right hashes contain additional files: {:#?}", right_extras),
            );
            success = false;
        }
    }

    // Report any path which contains a different hash.
    for (left_path, left_hash) in left.hashes.iter() {
        if let Some(right_hash) = right.hashes.get(left_path) {
            if left_hash != right_hash {
                record_error(
                    &mut results,
                    format!(
                        "`{}` is not deterministic: `{} != {}`",
                        left_path.display(),
                        left_hash,
                        right_hash
                    ),
                );
                success = false;
            }
        }
    }

    // If an output path is provided, save results there but do not
    // cause the process to error.
    if let Some(output) = &args.output {
        let content =
            serde_json::to_string_pretty(&results).context("Failed to serialize results.")?;
        if let Some(parent) = output.parent() {
            fs::create_dir_all(parent)
                .with_context(|| anyhow!("Failed to create directory: {}", parent.display()))?;
        }
        fs::write(output, format!("{}\n", content))
            .with_context(|| anyhow!("Failed to write file: {}", output.display()))?;
    } else if !success {
        bail!("Non deterministic behavior uncovered.");
    }

    Ok(())
}

fn load_bazel_info(
    bazel: &Path,
    workspace_dir: &Path,
    output_base: &Option<PathBuf>,
) -> anyhow::Result<HashMap<String, String>> {
    let mut command = std::process::Command::new(bazel);
    command
        .current_dir(workspace_dir)
        .env_remove("BAZELISK_SKIP_WRAPPER")
        .env_remove("BUILD_WORKING_DIRECTORY")
        .env_remove("BUILD_WORKSPACE_DIRECTORY");

    if let Some(output_base) = output_base {
        command.arg("--output_user_root").arg(output_base);
    }

    command.arg("info");

    // Execute bazel info.
    let output = command
        .output()
        .with_context(|| anyhow!("Failed to spawn bazel command: {:#?}", command))?;
    if !output.status.success() {
        return Err(anyhow!(
            "Failed to run `bazel info` ({:?}): {}",
            output.status,
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    let output = String::from_utf8_lossy(output.stdout.as_slice());
    let bazel_info = output
        .trim()
        .split('\n')
        .map(|line| line.split_at(line.find(':').expect("missing `:` in bazel info output")))
        .map(|(k, v)| (k.to_string(), (v[1..]).trim().to_string()))
        .collect::<HashMap<_, _>>();

    Ok(bazel_info)
}

/// 8K buffer size
const BUFFER_SIZE: usize = 8192;

/// File extensions to exclude.
const IGNORED_EXTENSIONS: [&str; 6] = [
    ".runfiles_manifest",
    "volatile-status.txt",
    "stable-status.txt",
    "MANIFEST",
    ".pdb",
    ".d",
];

async fn hash(args: HashArgs) -> anyhow::Result<()> {
    init_logging(args.verbose);

    let bazel_info = load_bazel_info(&args.bazel, &args.workspace_dir, &args.output_base)
        .context("Failed to query Bazel info.")?;

    let execution_root = PathBuf::from(&bazel_info["execution_root"]);

    debug!("Locating files");
    let mut files = BTreeSet::new();
    for entry in walkdir::WalkDir::new(&execution_root)
        .into_iter()
        .filter_entry(|entry| {
            let file_name = entry.file_name().to_string_lossy();

            // Skip any files that end with a given extension.
            for pattern in IGNORED_EXTENSIONS {
                if file_name.ends_with(pattern) {
                    return false;
                }
            }

            // Skip any file or directory inside a known volatile directory
            if entry.path().ancestors().any(|ancestor| {
                ancestor
                    .file_name()
                    .is_some_and(|name| name == "testlogs" || name == "_tmp")
            }) {
                return false;
            }

            true
        })
    {
        let entry = entry?;
        if entry.path().is_dir() {
            continue;
        }

        // Skip symlinks to avoid hashing files multiple times. The execution_root
        // is where Bazel writes real files so there will be some here.
        if entry.path_is_symlink() {
            continue;
        }

        // Use relative paths for more consistent lookups
        let path = entry
            .path()
            .strip_prefix(&execution_root)
            .with_context(|| {
                anyhow!(
                    "Failed to compute relative path between `{} -> {}`",
                    execution_root.display(),
                    entry.path().display()
                )
            })?
            .to_path_buf();

        files.insert(path);
    }

    if files.is_empty() {
        bail!(
            "No files found in execution_root: {}",
            execution_root.display()
        );
    }

    debug!("Hashing files");
    let threads = files
        .into_iter()
        .map(|path| {
            let abs_path = execution_root.join(&path);
            tokio::spawn(async move {
                debug!("Hashing started: {}", abs_path.display());
                let mut hasher = blake3::Hasher::new();
                let mut buffer = [0u8; BUFFER_SIZE];

                // Failing to read a file may be caused by a dangling symlink.
                // Make sure the execution_root is fully populated.
                let file = tokio::fs::File::open(&abs_path)
                    .await
                    .with_context(|| anyhow!("Failed to read file: {}", abs_path.display()))?;
                let mut reader = tokio::io::BufReader::new(file);

                while let Ok(n) = reader.read(&mut buffer).await {
                    // EOF reached
                    if n == 0 {
                        break;
                    }

                    hasher.update(&buffer[..n]);
                }

                let checksum = hasher.finalize().to_hex().to_string();

                debug!("Hashing compete: {}", abs_path.display());
                Ok((path, checksum))
            })
        })
        .collect::<Vec<JoinHandle<anyhow::Result<(PathBuf, String)>>>>();

    debug!("Waiting for hashing to complete");
    let mut hashes = BTreeMap::<PathBuf, String>::new();
    for thread in threads {
        let (file, checksum) = thread
            .await
            .context("Hasher thread panicked")?
            .context("Failure in Hasher thread")?;
        hashes.insert(file, checksum);
    }

    let results = HashResults {
        execution_root,
        hashes,
    };

    debug!("Serializing output");
    let content = serde_json::to_string_pretty(&results).context("Failed to serialize hashes.")?;

    // Write output
    if let Some(path) = &args.output {
        debug!("Writing output");
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).with_context(|| {
                anyhow!(
                    "Failed to create output parent directory: {}",
                    parent.display()
                )
            })?;
        }

        fs::write(path, format!("{}\n", content))
            .with_context(|| anyhow!("Failed to write output: {}", path.display()))?;
    } else {
        #[allow(clippy::print_stdout)]
        {
            println!("{}", content);
        }
    }

    Ok(())
}

fn clone_at_revision(location: &Path, url: &str, commit: &str) -> anyhow::Result<()> {
    debug!("Cloning {} to {}", url, location.display());

    let output = Command::new("git")
        .arg("clone")
        .arg("--no-checkout")
        .arg(url)
        .arg(location)
        .output()
        .context("Failed to spawn `git clone` command")?;
    if !output.status.success() {
        anyhow::bail!("{}", String::from_utf8(output.stderr).unwrap());
    }

    let output = Command::new("git")
        .arg("checkout")
        .arg(commit)
        .current_dir(location)
        .output()
        .context("Failed to spawn `git clone` command")?;
    if !output.status.success() {
        anyhow::bail!("{}", String::from_utf8(output.stderr).unwrap());
    }

    Ok(())
}

fn bazel_test_and_hash(
    bazel: &Path,
    workspace: &Path,
    output_user_root: &Path,
    hash_output: &Path,
) -> anyhow::Result<()> {
    let status = Command::new(bazel)
        .current_dir(workspace)
        .arg("--output_user_root")
        .arg(output_user_root)
        .arg("build")
        .arg("//...")
        .arg("--config=clippy")
        .arg("--config=rustfmt")
        .status()
        .context("Failed to spawn bazel build command")?;
    if !status.success() {
        anyhow::bail!("Bazel test command failed.")
    }

    let status = Command::new(env::current_exe().unwrap())
        .env("BAZEL_REAL", bazel)
        .env("BUILD_WORKSPACE_DIRECTORY", workspace)
        .env("OUTPUT_BASE", output_user_root)
        .arg("hash")
        .arg("--output")
        .arg(hash_output)
        .status()
        .context("Failed to spawn hash subcommand")?;
    if !status.success() {
        anyhow::bail!("Hash subcommand failed.")
    }

    Ok(())
}

async fn test(args: TestArgs) -> anyhow::Result<()> {
    let main = |args: &TestArgs, bazel: &Path, temp_dir: &Path| -> anyhow::Result<()> {
        let repo_a = temp_dir.join("a");
        let repo_b = temp_dir.join("b");

        info!("Cloning repositories");
        clone_at_revision(&repo_a, &args.url, &args.commit)?;
        clone_at_revision(&repo_b, &args.url, &args.commit)?;

        info!("Processing Repo A");
        let repo_a_hashes = {
            let output = temp_dir.join("a_hashes.json");
            let output_user_root = temp_dir.join("o");
            bazel_test_and_hash(bazel, &repo_a, &output_user_root, &output)
                .with_context(|| anyhow!("Failed to generate hashes for {}", output.display()))?;
            output
        };

        info!("Processing Repo B");
        let repo_b_hashes = {
            let output = temp_dir.join("b_hashes.json");
            let output_user_root = temp_dir.join("o");
            bazel_test_and_hash(bazel, &repo_b, &output_user_root, &output)
                .with_context(|| anyhow!("Failed to generate hashes for {}", output.display()))?;
            output
        };

        let results_file = match &args.output {
            Some(p) => p.clone(),
            None => temp_dir.join("results.json"),
        };

        info!("Comparing results");
        let status = Command::new(env::current_exe().unwrap())
            .arg("compare")
            .arg("--left")
            .arg(repo_a_hashes)
            .arg("--right")
            .arg(repo_b_hashes)
            .arg("--output")
            .arg(results_file)
            .status()
            .context("Failed to spawn compare command")?;
        if status.success() {
            anyhow::bail!("Targets are not deterministic.");
        }

        Ok(())
    };

    init_logging(args.verbose);

    let temp_dir = match &args.work_dir {
        Some(p) => p.clone(),
        None => {
            let tempdir = tempfile::TempDir::with_prefix("determinism-")
                .context("Failed to create temporary directory")?;
            tempdir.keep()
        }
    };

    let bazel = args.bazel.clone().unwrap_or(PathBuf::from("bazel"));

    match main(&args, &bazel, &temp_dir) {
        // If the test succeeds, clean up the workspaces
        Ok(_) => {
            fs::remove_dir_all(&temp_dir).with_context(|| {
                anyhow!(
                    "Failed to delete directory contents: {}",
                    temp_dir.display(),
                )
            })?;
            Ok(())
        }
        // If the test fails, don't delete the temp directory.
        Err(e) => {
            info!("Outputs can be found at: `{}`", temp_dir.display());
            Err(e)
        }
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Parse command line arguments
    let args = Args::parse();

    match args {
        Args::Hash(hash_args) => hash(hash_args).await,
        Args::Compare(compare_args) => compare(compare_args).await,
        Args::Test(test_args) => test(test_args).await,
    }
}
