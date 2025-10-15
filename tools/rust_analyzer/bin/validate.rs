//! Validates a rust-project.json file by invoking rust-analyzer

use clap::Parser;
use runfiles::{rlocation, Runfiles};
use std::env;
use std::path::PathBuf;
use std::process::{exit, Command};

#[derive(Parser, Debug)]
#[command(
    author,
    version,
    about = "Validates a rust-project.json file using rust-analyzer"
)]
struct Args {
    /// Path to the rust-project.json file to validate
    project: PathBuf,

    /// Verbose output from rust-analyzer
    #[arg(short, long)]
    verbose: bool,
}

fn main() {
    let args = Args::parse();

    // Change to workspace directory if running via `bazel run`
    if let Ok(workspace_dir) = env::var("BUILD_WORKSPACE_DIRECTORY") {
        env::set_current_dir(&workspace_dir).unwrap_or_else(|e| {
            eprintln!(
                "Warning: Could not change to workspace directory {}: {}",
                workspace_dir, e
            );
        });
    }

    let project_path = args.project.canonicalize().unwrap_or_else(|e| {
        eprintln!(
            "Error: Could not find rust-project.json at {:?}: {}",
            args.project, e
        );
        eprintln!("Current directory: {:?}", env::current_dir().unwrap());
        exit(1);
    });

    if !project_path.exists() {
        eprintln!("Error: rust-project.json not found at {:?}", project_path);
        exit(1);
    }

    println!("Validating rust-project.json: {}", project_path.display());

    // Use runfiles to locate the rust-analyzer binary
    let r = Runfiles::create().unwrap_or_else(|e| {
        eprintln!("Error: Failed to create runfiles: {}", e);
        exit(1);
    });

    let rust_analyzer_path =
        rlocation!(r, env!("RUST_ANALYZER_RLOCATIONPATH")).unwrap_or_else(|| {
            eprintln!("Error: Could not locate rust-analyzer binary");
            eprintln!("Rlocationpath: {}", env!("RUST_ANALYZER_RLOCATIONPATH"));
            exit(1);
        });

    if !rust_analyzer_path.exists() {
        eprintln!(
            "Error: rust-analyzer binary not found at: {}",
            rust_analyzer_path.display()
        );
        exit(1);
    }

    if args.verbose {
        println!("Using rust-analyzer: {}", rust_analyzer_path.display());
    }

    // Run rust-analyzer diagnostics to validate the project
    let project_dir = project_path.parent().unwrap_or_else(|| {
        eprintln!("Error: Could not determine project directory");
        exit(1);
    });

    let mut cmd = Command::new(&rust_analyzer_path);
    cmd.arg("diagnostics")
        .arg(project_dir)
        .env("RUST_PROJECT_JSON", &project_path);

    if args.verbose {
        cmd.arg("-v");
    }

    if args.verbose {
        println!("Running: {:?}", cmd);
    }

    let output = cmd.output().unwrap_or_else(|e| {
        eprintln!("Error: Failed to execute rust-analyzer: {}", e);
        exit(1);
    });

    // Check stderr for JSON deserialization errors
    let stderr = String::from_utf8_lossy(&output.stderr);

    // Look for specific JSON/deserialization errors
    if stderr.contains("Failed to deserialize")
        || stderr.contains("unknown variant")
        || stderr.contains("Failed to load the project")
    {
        eprintln!("\n✗ rust-project.json has format errors!");
        eprintln!("\nrust-analyzer error:");
        // Only show the relevant error lines
        for line in stderr.lines() {
            if line.contains("Failed to")
                || line.contains("unknown variant")
                || line.contains("ERROR")
            {
                eprintln!("{}", line);
            }
        }
        exit(1);
    }

    // If rust-analyzer ran diagnostics (even with code errors), the JSON is valid
    // We don't care about code analysis errors, only JSON format errors

    if args.verbose {
        let stdout = String::from_utf8_lossy(&output.stdout);
        if !stdout.is_empty() {
            println!("\nrust-analyzer output:");
            println!("{}", stdout);
        }
    }

    println!("\n✓ rust-project.json validation successful!");
    exit(0);
}
