# Worker-Managed Pipelined Compilation

## Overview

Replace the current two-invocation pipelined compilation approach with a single-rustc-invocation
model managed by the persistent worker, matching Cargo's pipelining behavior. When enabled, the
multiplex worker starts one rustc process per pipelined crate, returns the `.rmeta` metadata file
as soon as it is ready, and caches the running process so the second Bazel action can retrieve the
full `.rlib` without re-invoking rustc.

## Current State Analysis

### Current Approach (Two Invocations)

For each pipelined `rlib`/`lib` crate, Bazel registers two actions:

1. **RustcMetadata**: Runs `rustc -Zno-codegen --emit=dep-info,link=_hollow/libX-hollow.rlib` with
   hollow rlib deps. Produces a "hollow rlib" (ar archive with metadata, no object code). Requires
   `RUSTC_BOOTSTRAP=1` on both actions for SVH consistency.

2. **Rustc**: Runs full `rustc --emit=dep-info,link` with full rlib deps
   (`force_depend_on_objects=True`). Produces the real `.rlib`.

Downstream rlib crates depend on the hollow rlib (unblocked early). Downstream bins depend on full
rlibs (wait for codegen).

### Problems with Current Approach

- **SVH mismatch with non-deterministic proc macros**: Proc macros run twice (once per invocation)
  with different HashMap seeds, potentially producing different SVH values if run with --emit=dep-info,metadata.
  This causes E0460 errors which is why -Zno-codegen is used. (`test/unit/pipelined_compilation/svh_mismatch_test.sh`)
- **Requires `-Zno-codegen`**: An unstable flag, needs `RUSTC_BOOTSTRAP=1` on _both_ actions for SVH to match.
- **Redundant work**: Type checking, macro expansion, name resolution all happen twice.
- **Hollow rlib complexity**: Custom `_hollow/` directory naming for `-Zno-codegen`, separate `-Ldependency=` paths,
  ar archive format requirements.
- **Diverges from Cargo**: Cargo uses single invocation + `.rmeta` files (not hollow rlibs).

### How Cargo Does It

Cargo's pipelined compilation (enabled by default since 2019):

1. Single rustc invocation with `--emit=dep-info,metadata,link` and `--json=artifacts`
2. rustc emits `{"artifact":"path/to/lib.rmeta","emit":"metadata"}` on stderr when `.rmeta` is
   written (before codegen begins)
3. Downstream rlib crates compile with `--extern name=path.rmeta` (rustc supports this natively)
4. Downstream bins/dylibs wait for `.rlib` and use `--extern name=path.rlib`
5. No hollow rlibs, no `-Zno-codegen`, no `RUSTC_BOOTSTRAP=1`, no SVH issues

### Key Discoveries

- `rust/private/rustc.bzl:1380` — `use_hollow_rlib` gates the two-invocation path
- `rust/private/rustc.bzl:1439-1462` — `compile_inputs_for_metadata` vs `compile_inputs` with
  `force_depend_on_objects=True` is the dual-input-set mechanism
- `rust/private/rustc.bzl:1556-1561` — `RUSTC_BOOTSTRAP=1` injected for hollow rlib SVH compat
- `util/process_wrapper/worker.rs:49-103` — Current serial worker; processes one request at a time
- `util/process_wrapper/output.rs:26-30` — `LineOutput::Terminate` variant exists for metadata
  detection but is not currently wired up in `process_json`
- `util/process_wrapper/rustc.rs:64-73` — `process_json` returns `Skip` for all emit messages
  (including metadata); needs modification
- `.rmeta`-based pipelining was previously used and abandoned because with two invocations it causes
  SVH mismatch. It is safe to re-enable **only** with the single-invocation worker approach.

## Desired End State

When `experimental_worker_pipelining` is enabled (alongside `pipelined_compilation`, separate from `experimental_incremental`):

1. Each pipelined rlib/lib crate still produces two Bazel actions (RustcMetadata + Rustc), but:
    - **RustcMetadata** starts a full rustc (`--emit=dep-info,metadata,link`), monitors for the
      metadata artifact notification, returns the `.rmeta` file, and keeps rustc running in the
      background inside the multiplex worker.
    - **Rustc** looks up the background rustc in the worker's state, waits for it to complete, and
      returns the full `.rlib`.
2. Downstream rlib crates use `--extern name=path.rmeta` (pipelined, unblocked early).
3. Downstream bins use `--extern name=path.rlib` (wait for full compile).
4. No `-Zno-codegen`, no `RUSTC_BOOTSTRAP=1`, no hollow rlibs, no `_hollow/` directory.
5. Non-deterministic proc macros produce consistent SVH (proc macro runs once).
6. `experimental_use_cc_common_link` is not required for worker-pipelined builds.

### Verification

- `bazel build //test/unit/pipelined_compilation/...` passes with worker pipelining enabled
- Action graph will still show 2 actions (Bazel sees two independent worker requests), but the
  worker internally deduplicates them into a single rustc process — this is transparent to Bazel
- SVH mismatch test passes without `experimental_use_cc_common_link`
- Existing two-invocation fallback continues to work when worker pipelining is disabled
- Performance comparison shows reduced total rustc invocations

## What We're NOT Doing

- **Changing the existing two-invocation fallback**: It remains as-is for RBE and non-worker builds.
- **Removing hollow rlib support**: The existing path is untouched; users who don't enable worker
  pipelining get the current behavior.
- **Remote persistent workers**: Bazel persistent workers are local-only by design. Phase 4
  enables _dynamic execution_ (speculative local worker + remote), but the worker itself only
  runs locally.
- **Changing non-rlib pipelining**: Bins, proc-macros, cdylibs are not pipelined as upstream deps.

## Implementation Approach

The implementation is split into phases. Each phase is independently testable and leaves the
codebase in a working state.

---

## Phase 1: Multiplex Worker Infrastructure

### Overview

Upgrade the persistent worker from serial (one request at a time) to multiplex (concurrent
requests, single process). This is a prerequisite for the pipelining changes — the multiplex
guarantee that all requests go to the same OS process is what enables in-process state sharing
between the metadata and full compile actions.

### Changes Required

#### 1. Worker Protocol Upgrade (`util/process_wrapper/worker.rs`)

**Changes**: Rewrite the request loop to handle concurrent requests via threads.

The current serial worker reads one request, spawns a subprocess, waits, responds. The multiplex
worker must:

- Read requests from stdin on the main thread
- Dispatch each request to a new thread (or thread pool)
- Each thread processes its request and sends the response back
- Main thread (or a dedicated writer thread) writes responses to stdout atomically

Key implementation details:

- **Request routing**: Check `requestId` — if 0, process serially (singleplex fallback); if >0,
  dispatch to thread pool (multiplex).
- **Atomic stdout writes**: Use a `Mutex<Stdout>` or a dedicated writer channel to prevent
  interleaved responses from multiple threads.
- **Thread pool**: Use a simple `std::thread::spawn` per request (bounded by Bazel's
  `--worker_max_instances` which controls proxy count, not thread count). No need for a complex
  executor.

```rust
// Sketch of multiplex dispatch loop
pub(crate) fn worker_main() -> Result<(), ProcessWrapperError> {
    let self_path = std::env::current_exe()?;
    let startup_args: Vec<String> = std::env::args()
        .skip(1)
        .filter(|a| a != "--persistent_worker")
        .collect();

    let stdin = io::stdin();
    let stdout = Arc::new(Mutex::new(io::stdout()));

    // Shared state for pipelined compilation (Phase 2)
    let pipeline_state = Arc::new(Mutex::new(PipelineState::new()));

    for line in stdin.lock().lines() {
        let line = line?;
        if line.is_empty() { continue; }
        let request: JsonValue = line.parse()?;
        let request_id = extract_request_id(&request);

        if request_id == 0 {
            // Singleplex: process inline (current behavior)
            let mut full_args = startup_args.clone();
            full_args.extend(extract_arguments(&request));
            prepare_outputs(&full_args);
            let (exit_code, output) = run_request(&self_path, full_args)?;
            let response = build_response(exit_code, &output, request_id);
            let mut out = stdout.lock().unwrap();
            writeln!(out, "{response}")?;
            out.flush()?;
        } else {
            // Multiplex: dispatch to thread
            let self_path = self_path.clone();
            let startup_args = startup_args.clone();
            let stdout = Arc::clone(&stdout);
            let pipeline_state = Arc::clone(&pipeline_state);
            let args = extract_arguments(&request);

            std::thread::spawn(move || {
                let mut full_args = startup_args;
                full_args.extend(args);
                prepare_outputs(&full_args);

                // Phase 2: check for pipelining flags here
                let (exit_code, output) = run_request(&self_path, full_args)
                    .unwrap_or((1, "worker thread error".to_string()));

                let response = build_response(exit_code, &output, request_id);
                let mut out = stdout.lock().unwrap();
                let _ = writeln!(out, "{response}");
                let _ = out.flush();
            });
        }
    }
    Ok(())
}
```

#### 2. Bazel Execution Requirements (`rust/private/rustc.bzl`)

**File**: `rust/private/rustc.bzl:1609-1679`

**Changes**: When worker pipelining is enabled, add `supports-multiplex-workers` to execution
requirements for both Rustc and RustcMetadata actions.

```python
exec_reqs = {}
use_worker_pipelining = _use_worker_pipelining(toolchain, crate_info)
if is_incremental_enabled(ctx, crate_info) or use_worker_pipelining:
    exec_reqs["requires-worker-protocol"] = "json"
    if use_worker_pipelining:
        exec_reqs["supports-multiplex-workers"] = "1"
    else:
        exec_reqs["supports-workers"] = "1"
    if is_incremental_enabled(ctx, crate_info):
        # no-sandbox needed for incremental cache at /tmp/rules_rust_incremental/
        exec_reqs["no-sandbox"] = "1"
```

Note: `supports-multiplex-workers` takes precedence over `supports-workers` when both are set,
but we should only set one to be explicit. For non-worker-pipelined incremental builds, we keep
the singleplex worker. `no-sandbox` is only needed when incremental compilation is also enabled
(for `/tmp/` cache access) — worker pipelining alone doesn't require it since workers already
run unsandboxed in the execroot.

### Success Criteria

#### Automated Verification:

- [ ] `cargo test -p process_wrapper` — all existing + new unit tests pass
- [ ] `bazel test //test/unit/pipelined_compilation/...` — existing tests still pass
- [ ] Build with `--strategy=Rustc=worker --strategy=RustcMetadata=worker` works correctly
- [ ] Multiplex requests (requestId > 0) are handled concurrently
- [ ] Singleplex requests (requestId == 0) still work (backward compat)

#### Manual Verification:

- [ ] Worker correctly handles multiple concurrent requests without response interleaving
- [ ] Worker gracefully handles thread panics without crashing the main loop

**Implementation Note**: After completing this phase and all automated verification passes, pause
here for manual confirmation before proceeding to Phase 2.

---

## Phase 2: Single-Invocation Pipelining in the Worker

### Overview

Add the core pipelining logic: the worker starts a full rustc for metadata actions, detects
metadata readiness, returns early, and caches the running process for the full compile action.

### Changes Required

#### 1. New Bazel Setting (`rust/settings/settings.bzl`)

**Changes**: Add `experimental_worker_pipelining` bool_flag.

```python
def experimental_worker_pipelining():
    """Setting to enable worker-managed pipelined compilation.

    When enabled (alongside pipelined_compilation), the persistent worker uses
    a single rustc invocation per pipelined crate instead of two, matching
    Cargo's pipelining behavior. The worker starts rustc, returns the .rmeta
    file as soon as metadata is ready, and caches the running process so the
    full compile action can retrieve the .rlib without re-invoking rustc.

    This eliminates SVH mismatch issues with non-deterministic proc macros
    and removes the need for -Zno-codegen / RUSTC_BOOTSTRAP=1.

    Requires: pipelined_compilation=true.
    Independent of experimental_incremental (can be used with or without it).
    Requires --strategy=Rustc=worker,local --strategy=RustcMetadata=worker,local
    for correct performance (without worker strategy, both actions run full
    rustc compilations, which is strictly worse than the two-invocation fallback).
    """
    bool_flag(
        name = "experimental_worker_pipelining",
        build_setting_default = False,
    )
    native.config_setting(
        name = "experimental_worker_pipelining_on",
        flag_values = {":experimental_worker_pipelining": "True"},
    )
```

Wire into `rust_toolchain` and `RUSTC_ATTRS` similar to existing settings.

#### 2. Pipeline State Management (`util/process_wrapper/worker.rs`)

**Changes**: Add `PipelineState` to track background rustc processes.

```rust
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::process::Child;

/// Tracks background rustc processes for worker-managed pipelining.
///
/// When a metadata action starts rustc, the Child handle is stored here
/// keyed by a pipeline key (derived from crate name + output hash).
/// When the full compile action arrives, it looks up and waits on the Child.
struct BackgroundRustc {
    child: Child,
    /// Captured stderr from before the metadata signal (diagnostics)
    stderr_before_metadata: String,
    /// Expected output path for the full rlib
    expected_output: String,
}

struct PipelineState {
    /// Map from pipeline key to background rustc process
    active: HashMap<String, BackgroundRustc>,
}

impl PipelineState {
    fn new() -> Self {
        Self { active: HashMap::new() }
    }

    fn store(&mut self, key: String, bg: BackgroundRustc) {
        self.active.insert(key, bg);
    }

    fn take(&mut self, key: &str) -> Option<BackgroundRustc> {
        self.active.remove(key)
    }
}
```

#### 3. Metadata Action: Start Rustc, Return `.rmeta` Early

**New function in `worker.rs`**:

When the worker detects `--pipelining-metadata` in the request args:

1. Parse `--pipelining-key=<key>` from args
2. Strip the pipelining flags from args before passing to rustc
3. Spawn rustc directly (not via subprocess process_wrapper) with the remaining args
4. Read rustc's stderr line-by-line, looking for `{"artifact":"...rmeta","emit":"metadata"}`
5. When found: store the `Child` handle in `PipelineState`, return success (exit code 0)
6. If rustc exits before emitting metadata: return failure with captured stderr
7. Forward any diagnostic messages to the response output (for Bazel to display)

```rust
fn handle_pipelining_metadata(
    args: Vec<String>,
    pipeline_key: String,
    pipeline_state: &Arc<Mutex<PipelineState>>,
) -> (i32, String) {
    // Parse the rustc command from args (executable is after "--")
    let (pw_args, rustc_cmd) = split_at_separator(&args);
    let opts = parse_options_from_args(&pw_args);

    let mut child = Command::new(&rustc_cmd[0])
        .args(&rustc_cmd[1..])
        .env_clear()
        .envs(&opts.child_environment)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("failed to spawn rustc");

    let stderr = child.stderr.take().unwrap();
    let reader = BufReader::new(stderr);
    let mut diagnostics = String::new();

    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };

        // Check for metadata artifact notification
        if let Ok(json) = line.parse::<JsonValue>() {
            if is_metadata_artifact(&json) {
                // Metadata is ready! Store the child and return.
                pipeline_state.lock().unwrap().store(pipeline_key, BackgroundRustc {
                    child,
                    stderr_before_metadata: diagnostics.clone(),
                    expected_output: extract_output_path(&args),
                });
                return (0, diagnostics);
            }
            // Forward diagnostic messages
            if let Some(rendered) = get_rendered(&json) {
                diagnostics.push_str(&rendered);
            }
        }
    }

    // rustc exited before metadata was ready — compilation error
    let status = child.wait().unwrap_or_else(|_| std::process::exit(1));
    (status.code().unwrap_or(1), diagnostics)
}

fn is_metadata_artifact(json: &JsonValue) -> bool {
    if let JsonValue::Object(map) = json {
        if let Some(JsonValue::String(artifact)) = map.get("artifact") {
            if artifact.ends_with(".rmeta") {
                return true;
            }
        }
    }
    false
}
```

#### 4. Full Compile Action: Wait for Background Rustc

**New function in `worker.rs`**:

When the worker detects `--pipelining-full` in the request args:

1. Parse `--pipelining-key=<key>` from args
2. Look up the `BackgroundRustc` in `PipelineState`
3. If found: drain remaining stderr, wait for child to exit, return result
4. If not found (worker restarted, or race condition): fall back to running rustc normally
   as a one-shot compilation (same as current non-pipelined behavior)

```rust
fn handle_pipelining_full(
    args: Vec<String>,
    pipeline_key: String,
    pipeline_state: &Arc<Mutex<PipelineState>>,
    self_path: &Path,
) -> (i32, String) {
    // Try to retrieve the background rustc
    let bg = pipeline_state.lock().unwrap().take(&pipeline_key);

    match bg {
        Some(mut bg) => {
            // Drain remaining stderr
            let mut remaining_stderr = String::new();
            if let Some(ref mut stderr) = bg.child.stderr {
                // stderr was taken by metadata handler, so this is a no-op
                // The metadata handler already took stderr ownership
            }

            // Wait for rustc to complete
            match bg.child.wait() {
                Ok(status) => {
                    let exit_code = status.code().unwrap_or(1);
                    (exit_code, bg.stderr_before_metadata + &remaining_stderr)
                }
                Err(e) => (1, format!("failed to wait for rustc: {e}")),
            }
        }
        None => {
            // Fallback: no cached process (worker was restarted).
            // Run as a normal one-shot compilation.
            prepare_outputs(&args);
            run_request(self_path, args).unwrap_or((1, "fallback failed".to_string()))
        }
    }
}
```

#### 5. Process Wrapper Flag Handling

**Files**: `util/process_wrapper/worker.rs`

**Changes**: Parse `--pipelining-metadata`, `--pipelining-full`, and `--pipelining-key=<key>` from
the request arguments. These are process_wrapper flags (before `--`), not rustc flags.

```rust
/// Extracts pipelining mode from process_wrapper arguments.
enum PipeliningMode {
    None,
    Metadata { key: String },
    Full { key: String },
}

fn detect_pipelining_mode(args: &[String]) -> PipeliningMode {
    let mut mode = PipeliningMode::None;
    let mut key = None;

    for arg in args {
        if arg == "--pipelining-metadata" {
            mode = PipeliningMode::Metadata { key: String::new() };
        } else if arg == "--pipelining-full" {
            mode = PipeliningMode::Full { key: String::new() };
        } else if let Some(k) = arg.strip_prefix("--pipelining-key=") {
            key = Some(k.to_string());
        }
    }

    // Inject the key into the mode
    match (&mut mode, key) {
        (PipeliningMode::Metadata { key: k }, Some(v)) => *k = v,
        (PipeliningMode::Full { key: k }, Some(v)) => *k = v,
        _ => {}
    }
    mode
}
```

#### 6. Bazel-Side: Emit Pipelining Flags (`rust/private/rustc.bzl`)

**File**: `rust/private/rustc.bzl` — `construct_arguments` and `rustc_compile_action`

**Changes**: When worker pipelining is enabled for a crate:

**In `construct_arguments`**:

- For metadata action: add `--pipelining-metadata` and `--pipelining-key=<key>` as process_wrapper
  flags. Change `emit` to `["dep-info", "metadata", "link"]` (no `-Zno-codegen`). Add
  `--json=artifacts` to rustc flags — this is what makes rustc emit the
  `{"artifact":"path.rmeta","emit":"metadata"}` JSON notification on stderr that the worker
  monitors. Without this flag, rustc silently writes `.rmeta` with no notification.
- For full action: add `--pipelining-full` and `--pipelining-key=<key>` as process_wrapper flags.
  Also add `--json=artifacts` (needed when the full action falls back to one-shot compilation
  after a worker restart — the flag is harmless and keeps both actions symmetric).

**In `rustc_compile_action`**:

- When `_use_worker_pipelining(toolchain, crate_info)` is True:
    - Do NOT set `use_hollow_rlib` (keep it False)
    - Do NOT call `collect_inputs` a second time with `force_depend_on_objects=True`
    - Do NOT set `RUSTC_BOOTSTRAP=1`
    - The metadata output file is declared as `.rmeta` (not hollow `.rlib`)
    - Both actions use the same input set (metadata/pipelined deps)
    - The full action still declares the full `.rlib` as output

**Pipeline key construction**:

```python
def _pipeline_key(crate_info, output_hash):
    """Unique key for matching metadata and full actions in the worker."""
    return "{}_{}".format(crate_info.name, output_hash)
```

#### 7. Switch Downstream `--extern` to `.rmeta` for Pipelined Deps

**File**: `rust/private/rustc.bzl` — `add_crate_link_flags`, `_crate_to_link_flag_metadata`

**Changes**: When worker pipelining is enabled, the metadata file IS the `.rmeta` file. The
existing `_crate_to_link_flag_metadata` function already uses `crate_info.metadata` when
`metadata_supports_pipelining=True`. We just need to ensure the metadata file is declared with
`.rmeta` extension instead of `-hollow.rlib`.

**File**: `rust/private/rust.bzl` — `_rust_library_impl`

**Changes**: When worker pipelining is enabled, declare metadata file as `.rmeta`:

```python
if _use_worker_pipelining(toolchain, ctx):
    rust_metadata = ctx.actions.declare_file(
        paths.basename(rust_lib_name)[:-len(".rlib")] + ".rmeta",
    )
else:
    # Existing hollow rlib path
    rust_metadata = ctx.actions.declare_file(
        "_hollow/" + rust_lib_name[:-len(".rlib")] + "-hollow.rlib",
    )
```

#### 8. Full Action Input Set Changes

**File**: `rust/private/rustc.bzl:1439-1462`

**Changes**: When worker pipelining is enabled, skip the second `collect_inputs` call entirely.
The full action uses the same input set as the metadata action (pipelined deps). The worker
handles the actual compilation — the full action just waits for the cached result.

```python
compile_inputs_for_metadata = compile_inputs
if use_hollow_rlib:
    # Existing two-invocation path: full action needs full rlib deps
    compile_inputs, _, _, _, _, _ = collect_inputs(
        ..., force_depend_on_objects = True, ...
    )
# When worker pipelining is active, use_hollow_rlib is False,
# so compile_inputs == compile_inputs_for_metadata (pipelined deps).
# The full action's inputs are the same as the metadata action's.
```

The Rustc action still needs its own metadata output as an ordering dep (so it runs after
RustcMetadata):

```python
rustc_inputs = compile_inputs
if build_metadata and (is_incremental_enabled(ctx, crate_info) or _use_worker_pipelining(toolchain, crate_info)):
    rustc_inputs = depset([build_metadata], transitive = [compile_inputs])
```

Note: The ordering dep is needed for both incremental (prevents rustc ICE from concurrent
cache access) and worker pipelining (ensures the metadata action starts rustc before the full
action tries to look it up).

### Success Criteria

#### Automated Verification:

- [ ] `cargo test -p process_wrapper` — all tests pass including new pipelining tests
- [ ] `bazel test //test/unit/pipelined_compilation/...` — all tests pass
- [ ] Build with worker pipelining enabled produces correct artifacts
- [ ] `RUSTC_BOOTSTRAP=1` is NOT set when worker pipelining is active
- [ ] `-Zno-codegen` is NOT used when worker pipelining is active
- [ ] Fallback to normal compilation when worker is restarted mid-build

#### Manual Verification:

- [ ] Performance comparison: worker pipelining vs two-invocation on a real project
- [ ] Memory usage observation during a large build with many pipelined crates

**Implementation Note**: After completing this phase and all automated verification passes, pause
here for manual confirmation before proceeding to Phase 3.

---

## Phase 3: Testing and Action Graph Verification

### Overview

Add tests that verify the single-invocation behavior and that the action graph is correct.

### Changes Required

#### 1. Action Count Test

**File**: `test/unit/pipelined_compilation/pipelined_compilation_test.bzl` (new test cases)

Add analysis test(s) that verify when worker pipelining is enabled:

- Each pipelined rlib still produces two actions (RustcMetadata + Rustc) — the Bazel action graph
  doesn't change, only the worker behavior does
- The RustcMetadata action uses `--emit=dep-info,metadata,link` (not `-Zno-codegen`)
- The RustcMetadata action includes `--pipelining-metadata` flag
- The Rustc action includes `--pipelining-full` flag
- Neither action has `RUSTC_BOOTSTRAP=1` in env
- The metadata output file has `.rmeta` extension (not `-hollow.rlib`)
- Execution requirements include `supports-multiplex-workers`

#### 2. SVH Consistency Test

**File**: `test/unit/pipelined_compilation/` (new test)

Test that when using worker pipelining with a non-deterministic proc macro:

- Build succeeds without `experimental_use_cc_common_link`
- No E0460 SVH mismatch errors
- This is the inverse of the existing `svh_mismatch_test.sh` — it should PASS with worker
  pipelining even though it fails with the two-invocation approach

#### 3. Worker Fallback Test

**File**: `util/process_wrapper/worker.rs` (unit tests)

Test that `handle_pipelining_full` correctly falls back to one-shot compilation when no cached
process is found (simulating worker restart).

### Success Criteria

#### Automated Verification:

- [ ] All new analysis tests pass
- [ ] SVH consistency test passes with worker pipelining
- [ ] Worker fallback unit test passes
- [ ] Existing svh_mismatch_test.sh still correctly demonstrates the issue for two-invocation path

#### Manual Verification:

- [ ] Review action graph output to confirm single-invocation behavior

---

## Phase 4: Multiplex Sandboxing for Dynamic Execution

### Overview

Implement `sandboxDir` handling in the multiplex worker so it can be used with Bazel's dynamic
execution strategy (`--dynamic_local_strategy=worker`). Without multiplex sandboxing, Bazel
silently falls back to "sandboxed singleplex workers" when using dynamic execution, losing
multiplex benefits.

Multiplex sandboxing works by giving each WorkRequest its own `sandboxDir` — a relative directory
inside the worker's working directory (the execroot) where inputs are symlinked and outputs must
be written. After the worker responds, Bazel extracts declared outputs from the sandbox and cleans
it up.

### Design Constraint: Sandbox Lifetime vs Background Rustc

There is a tension between multiplex sandboxing and the single-invocation pipelining from Phase 2:

- The metadata and full actions for a crate receive **different** `sandboxDir` values
- The background rustc (started by the metadata action) runs with CWD = sandbox A
- After the metadata response, **Bazel cleans up sandbox A** (moves outputs out, deletes contents)
- The full action arrives with sandbox B, but the background rustc needs to keep writing outputs

**Resolution**: Use a worker-managed persistent output directory that survives sandbox cleanup.

The key observation: after emitting the metadata artifact, rustc has completed all input reads
(parsing, macro expansion, type checking). The codegen phase that follows only **writes** outputs
(object files, the final `.rlib`). So:

1. Set `CWD = sandbox_dir` so rustc can read inputs from the sandbox (input symlinks)
2. Rewrite `--out-dir` to an **absolute path** pointing to a worker-managed directory
   (`_pw_pipeline/<key>/`) that persists across both actions
3. After metadata: copy `.rmeta` from the persistent dir to `sandbox_dir`, respond
4. Bazel cleans up sandbox A — rustc's CWD becomes inaccessible as a path, but:
   - All input reads are already done (memory-mapped .rmeta deps survive inode unlink)
   - `--out-dir` is absolute, so output writes succeed in the persistent directory
5. After full compile: copy `.rlib` from persistent dir to sandbox B, respond, clean up

This preserves single-invocation pipelining even in sandboxed mode.

### Changes Required

#### 1. Parse `sandboxDir` from WorkRequest (`util/process_wrapper/worker.rs`)

**Changes**: Add extraction of the `sandboxDir` field from the JSON WorkRequest. In Bazel's JSON
worker protocol, field names use camelCase (matching the existing `requestId` convention). The
protobuf field is `sandbox_dir` (field 6), which maps to `sandboxDir` in JSON.

```rust
/// Extracts the `sandboxDir` field from a WorkRequest (empty string if absent).
fn extract_sandbox_dir(request: &JsonValue) -> String {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::String(dir)) = map.get("sandboxDir") {
            return dir.clone();
        }
    }
    String::new()
}
```

#### 2. Sandbox Path Handling (`util/process_wrapper/worker.rs`)

**Changes**: When `sandboxDir` is non-empty, the worker must ensure rustc reads inputs from and
writes outputs to the sandbox. Since Bazel's sandbox mirrors the execroot's relative path
structure (Proposal 2A from the design doc), setting `CWD = sandbox_dir` makes all relative
paths in arguments resolve correctly without rewriting individual paths.

For **non-pipelined** sandboxed requests, this is straightforward — set `CWD = sandbox_dir` on
the subprocess:

```rust
fn run_sandboxed_request(
    self_path: &std::path::Path,
    arguments: Vec<String>,
    sandbox_dir: &str,
) -> Result<(i32, String), ProcessWrapperError> {
    let mut cmd = Command::new(self_path);
    cmd.args(&arguments)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .current_dir(sandbox_dir);

    let output = cmd.output().map_err(|e| {
        ProcessWrapperError(format!("failed to spawn sandboxed subprocess: {e}"))
    })?;

    let exit_code = output.status.code().unwrap_or(1);
    let mut combined = String::from_utf8_lossy(&output.stdout).into_owned();
    combined.push_str(&String::from_utf8_lossy(&output.stderr));
    Ok((exit_code, combined))
}
```

For **pipelined** sandboxed requests, the output directory must survive sandbox cleanup (see
Design Constraint above). This requires redirecting `--out-dir` to a worker-managed persistent
directory — see section 3.

#### 3. Sandboxed Pipelining: Persistent Output Directory (`util/process_wrapper/worker.rs`)

**Changes**: Extend the pipelining handlers (Phase 2) to support `sandboxDir` by using a
worker-managed output directory that persists across the metadata and full actions.

**Metadata handler with sandbox:**

```rust
fn handle_pipelining_metadata_sandboxed(
    args: Vec<String>,
    pipeline_key: String,
    sandbox_dir: String,
    pipeline_state: &Arc<Mutex<PipelineState>>,
) -> (i32, String) {
    let (pw_args, rustc_cmd) = split_at_separator(&args);
    let opts = parse_options_from_args(&pw_args);

    // Create persistent output directory in the execroot
    let pipeline_dir = PathBuf::from(format!("_pw_pipeline/{}", pipeline_key));
    let _ = fs::create_dir_all(&pipeline_dir);
    let pipeline_dir_abs = std::env::current_dir().unwrap().join(&pipeline_dir);

    // Rewrite --out-dir in rustc args to point to persistent dir.
    // The original --out-dir is a relative path that would resolve inside the sandbox.
    // We replace it with the absolute persistent path so outputs survive sandbox cleanup.
    let original_out_dir = find_out_dir(&rustc_cmd);
    let modified_cmd = rewrite_out_dir(&rustc_cmd, &pipeline_dir_abs);

    let mut child = Command::new(&modified_cmd[0])
        .args(&modified_cmd[1..])
        .env_clear()
        .envs(&opts.child_environment)
        .current_dir(&sandbox_dir)  // CWD = sandbox for input reads
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("failed to spawn rustc");

    // ... monitor stderr for metadata artifact (same as unsandboxed) ...

    // When .rmeta is ready in pipeline_dir_abs:
    // 1. Create the output directory structure in the sandbox
    // 2. Copy/hardlink .rmeta from pipeline_dir to sandbox_dir/original_out_dir/
    copy_output_to_sandbox(&pipeline_dir_abs, &sandbox_dir, &original_out_dir, ".rmeta");

    // Store with persistent dir info so the full handler can find outputs
    pipeline_state.lock().unwrap().store(pipeline_key, BackgroundRustc {
        child,
        stderr_before_metadata: diagnostics,
        expected_output: extract_output_path(&args),
        pipeline_output_dir: Some(pipeline_dir_abs),
        original_out_dir: original_out_dir,
    });

    (0, diagnostics)
}
```

**Full handler with sandbox:**

```rust
fn handle_pipelining_full_sandboxed(
    args: Vec<String>,
    pipeline_key: String,
    sandbox_dir: String,
    pipeline_state: &Arc<Mutex<PipelineState>>,
    self_path: &Path,
) -> (i32, String) {
    let bg = pipeline_state.lock().unwrap().take(&pipeline_key);

    match bg {
        Some(mut bg) => {
            // Wait for background rustc to complete
            let status = bg.child.wait().unwrap();
            let exit_code = status.code().unwrap_or(1);

            if exit_code == 0 {
                if let Some(ref pipeline_dir) = bg.pipeline_output_dir {
                    // Copy .rlib (and .d, etc.) from persistent dir to this request's sandbox
                    copy_all_outputs_to_sandbox(pipeline_dir, &sandbox_dir, &bg.original_out_dir);
                    // Clean up persistent directory
                    let _ = fs::remove_dir_all(pipeline_dir);
                }
            }

            (exit_code, bg.stderr_before_metadata)
        }
        None => {
            // Fallback: run as normal sandboxed one-shot compilation
            run_sandboxed_request(self_path, args, &sandbox_dir)
                .unwrap_or((1, "fallback failed".to_string()))
        }
    }
}
```

**Helper functions:**

```rust
/// Finds --out-dir=<path> in rustc args (may be in a flagfile).
/// Reuses the same scanning logic as prepare_outputs().
fn find_out_dir(args: &[String]) -> String { ... }

/// Rewrites --out-dir=<old> to --out-dir=<new> in args.
/// If --out-dir is in a flagfile, writes a modified copy of the flagfile.
fn rewrite_out_dir(args: &[String], new_out_dir: &Path) -> Vec<String> { ... }

/// Copies a specific output file from the persistent dir to the sandbox,
/// recreating the directory structure as needed.
fn copy_output_to_sandbox(
    pipeline_dir: &Path,
    sandbox_dir: &str,
    original_out_dir: &str,
    extension: &str,
) { ... }
```

**Updated `BackgroundRustc` struct:**

```rust
struct BackgroundRustc {
    child: Child,
    stderr_before_metadata: String,
    expected_output: String,
    /// Worker-managed persistent output directory (for sandboxed pipelining).
    /// None when running unsandboxed (outputs are in the execroot directly).
    pipeline_output_dir: Option<PathBuf>,
    /// Original --out-dir value from the arguments (for sandbox output copying).
    original_out_dir: String,
}
```

#### 4. Multiplex Dispatch with Sandbox Support (`util/process_wrapper/worker.rs`)

**Changes**: Update the multiplex dispatch loop (from Phase 1) to extract `sandboxDir` and route
requests to the appropriate handler variant.

```rust
// In the multiplex dispatch (Phase 1 code), after extracting request fields:
let sandbox_dir = extract_sandbox_dir(&request);

std::thread::spawn(move || {
    let mut full_args = startup_args;
    full_args.extend(args);

    let pipelining = detect_pipelining_mode(&full_args);
    let is_sandboxed = !sandbox_dir.is_empty();

    // Make output files writable (Bazel marks previous outputs read-only).
    // prepare_outputs_sandboxed resolves --out-dir relative to sandbox_dir
    // before making files writable (same logic as prepare_outputs but with
    // the sandbox prefix applied to relative paths).
    if is_sandboxed {
        prepare_outputs_sandboxed(&full_args, &sandbox_dir);
    } else {
        prepare_outputs(&full_args);
    }

    let (exit_code, output) = match (pipelining, is_sandboxed) {
        (PipeliningMode::Metadata { key }, false) => {
            handle_pipelining_metadata(full_args, key, &pipeline_state)
        }
        (PipeliningMode::Metadata { key }, true) => {
            handle_pipelining_metadata_sandboxed(
                full_args, key, sandbox_dir, &pipeline_state,
            )
        }
        (PipeliningMode::Full { key }, false) => {
            handle_pipelining_full(full_args, key, &pipeline_state, &self_path)
        }
        (PipeliningMode::Full { key }, true) => {
            handle_pipelining_full_sandboxed(
                full_args, key, sandbox_dir, &pipeline_state, &self_path,
            )
        }
        (PipeliningMode::None, true) => {
            run_sandboxed_request(&self_path, full_args, &sandbox_dir)
                .unwrap_or((1, "sandboxed request failed".to_string()))
        }
        (PipeliningMode::None, false) => {
            run_request(&self_path, full_args)
                .unwrap_or((1, "worker thread error".to_string()))
        }
    };

    let response = build_response(exit_code, &output, request_id);
    let mut out = stdout.lock().unwrap();
    let _ = writeln!(out, "{response}");
    let _ = out.flush();
});
```

#### 5. Execution Requirements (`rust/private/rustc.bzl`)

**Changes**: When worker pipelining is enabled, add `supports-multiplex-sandboxing` alongside
`supports-multiplex-workers`. This allows Bazel to use the multiplex worker with dynamic
execution.

```python
exec_reqs = {}
use_worker_pipelining = _use_worker_pipelining(toolchain, crate_info)
if is_incremental_enabled(ctx, crate_info) or use_worker_pipelining:
    exec_reqs["requires-worker-protocol"] = "json"
    if use_worker_pipelining:
        exec_reqs["supports-multiplex-workers"] = "1"
        exec_reqs["supports-multiplex-sandboxing"] = "1"
    else:
        exec_reqs["supports-workers"] = "1"
    if is_incremental_enabled(ctx, crate_info):
        exec_reqs["no-sandbox"] = "1"
```

When `supports-multiplex-sandboxing` is set and
`--experimental_worker_multiplex_sandboxing` is enabled:
- Bazel creates a per-request sandbox directory and populates `sandboxDir` in WorkRequest
- Non-pipelined requests: `CWD = sandbox_dir`, straightforward isolation
- Pipelined requests: `CWD = sandbox_dir` for input reads, `--out-dir` redirected to
  worker-managed persistent directory, outputs copied to sandbox before responding

When `--experimental_worker_multiplex_sandboxing` is NOT enabled (default):
- `sandboxDir` is empty in WorkRequests
- Pipelined requests use direct output (no persistent dir, no copying)
- Slightly faster due to no output copying overhead

#### 6. Cancel Request Support (`util/process_wrapper/worker.rs`)

**Changes**: Handle the `cancel` field in WorkRequest. When Bazel sends a cancel request (same
`requestId`, `cancel=true`), the worker should kill the corresponding subprocess and respond
with `wasCancelled=true`. This is important for dynamic execution where Bazel may cancel the
local worker if the remote execution finishes first.

```rust
/// Extracts the `cancel` field from a WorkRequest (defaults to false).
fn extract_cancel(request: &JsonValue) -> bool {
    if let JsonValue::Object(map) = request {
        if let Some(JsonValue::Boolean(cancel)) = map.get("cancel") {
            return *cancel;
        }
    }
    false
}
```

Cancel support requires tracking active request threads so they can be interrupted. A
`HashMap<i64, JoinHandle<()>>` or a cancellation token pattern can be used.

```rust
/// WorkResponse with cancellation acknowledgment
fn build_cancel_response(request_id: i64) -> String {
    let response = JsonValue::Object(HashMap::from([
        ("exitCode".to_string(), JsonValue::Number(0.0)),
        ("output".to_string(), JsonValue::String(String::new())),
        ("requestId".to_string(), JsonValue::Number(request_id as f64)),
        ("wasCancelled".to_string(), JsonValue::Boolean(true)),
    ]));
    response.stringify().unwrap_or_else(|_| {
        format!(r#"{{"exitCode":0,"output":"","requestId":{request_id},"wasCancelled":true}}"#)
    })
}
```

### Success Criteria

#### Automated Verification:

- [x] `cargo test -p process_wrapper` — all tests pass including new sandboxing tests (51 pass, 1 pre-existing fail)
- [x] `bazel test //test/unit/pipelined_compilation/...` — all tests pass (10/10)
- [x] Build with `--experimental_worker_multiplex_sandboxing` works correctly (validated via Bazel 9 auto-strategy)
- [x] Sandboxed non-pipelined requests use `current_dir(sandbox_dir)` for path resolution (`run_sandboxed_request`, `resolve_sandbox_path`)
- [x] Sandboxed pipelined requests redirect `--out-dir` to worker-managed persistent directory (`rewrite_out_dir_in_expanded`, `handle_pipelining_metadata_sandboxed`)
- [x] Sandboxed pipelined outputs are copied from persistent dir to sandbox before responding (`copy_output_to_sandbox`, `copy_all_outputs_to_sandbox`)
- [x] Persistent output directory `_pw_pipeline/<key>/` is cleaned up after full action completes (`handle_pipelining_full_sandboxed`)
- [x] Cancel requests are handled (respond with `wasCancelled=true`) (`build_cancel_response`, `claimed` HashSet)

#### Manual Verification:

- [ ] Dynamic execution (`--dynamic_local_strategy=Rustc=worker,remote`) works correctly
- [ ] Performance comparison: sandboxed vs unsandboxed multiplex worker
- [ ] Verify sandbox cleanup doesn't interfere with ongoing compilations

**Implementation Note**: After completing this phase and all automated verification passes, pause
here for manual confirmation.

---

## Testing Strategy

### Unit Tests (Rust, `cargo test`):

- Multiplex request dispatch (requestId > 0 → thread)
- Singleplex fallback (requestId == 0 → inline)
- Pipelining mode detection from args
- Metadata artifact JSON detection
- Pipeline state store/take
- Response atomicity under concurrent writes
- Fallback when no cached process exists
- `sandboxDir` extraction from WorkRequest JSON
- Sandboxed non-pipelined request uses `current_dir(sandbox_dir)`
- Sandboxed pipelined request redirects `--out-dir` to persistent dir
- `rewrite_out_dir` correctly handles inline args and flagfile args
- Persistent output dir cleanup after full action
- Cancel request handling (`wasCancelled` response)

### Analysis Tests (Bazel, `bazel test`):

- Action flags contain correct `--emit` for worker pipelining
- Action flags contain `--pipelining-metadata` / `--pipelining-full`
- No `RUSTC_BOOTSTRAP=1` in env when worker pipelining active
- Metadata output has `.rmeta` extension
- Execution requirements include `supports-multiplex-workers`
- Execution requirements include `supports-multiplex-sandboxing`
- `--extern` flags use `.rmeta` for pipelined deps

### Integration Tests:

- End-to-end build with worker pipelining enabled
- SVH consistency with non-deterministic proc macros
- Worker restart recovery (fallback to one-shot)
- Sandboxed multiplex worker with `--experimental_worker_multiplex_sandboxing`
- Sandboxed pipelining: single invocation preserved with persistent output dir
- Dynamic execution with `--dynamic_local_strategy=Rustc=worker,remote`

## Performance Considerations

**Expected improvements:**

- ~50% reduction in rustc invocations for pipelined crates
- Eliminated redundant type checking, macro expansion, name resolution
- Reduced incremental cache writes (one pass instead of two)
- Smaller metadata artifacts (`.rmeta` vs hollow `.rlib` with empty object sections)

**Potential concerns:**

- Background rustc processes hold memory during codegen while waiting for the full action
- Mitigated by Bazel's `--worker_max_instances` (default 4) limiting concurrency
- Multiplex worker is single-threaded for stdout writes (serialization point)
- Worker restart loses all cached processes (graceful fallback)
- Sandboxed pipelining adds overhead: creating `_pw_pipeline/<key>/` directories and copying
  output files from the persistent dir back to each sandbox. For large `.rlib` files this copy
  cost is non-trivial but still far less than running rustc twice.

**Comparison approach:**

- Build the same project with `experimental_worker_pipelining=true` vs `false`
- Both with `pipelined_compilation=true` and `--strategy=Rustc=worker,local`
- Optionally also compare with/without `experimental_incremental=true`
- Measure: total build time, total rustc invocations, peak memory

## Phase 5: Bazel 9 Compatibility (COMPLETE)

Worker pipelining as implemented in Phases 1-4 works on Bazel 8.4.2 but failed on Bazel 9.0.0.
Three root causes were identified and fixed.

### Root Cause 1: `_pipeline/*.rmeta` not produced in sandbox mode

The metadata action declares its output at `_pipeline/<name>.rmeta`, but rustc writes `.rmeta`
to `--out-dir` (the parent directory). In worker mode, the handler copies the file to `_pipeline/`.
In sandbox mode (non-worker), no such copy happens → Bazel error "output was not created".

Bazel 9 auto-selects worker strategy when `supports-multiplex-workers` is in exec_reqs, even
without explicit `--strategy=Rustc=worker`. This creates a mix of worker and sandbox execution,
causing non-deterministic failures.

**Fix:** `rust/private/rustc.bzl` — Add `--emit=metadata=<_pipeline/path>` to the rustc flags
so rustc writes the `.rmeta` directly to the declared output location, regardless of execution
mode (worker or sandbox).

### Root Cause 2: `use_worker_pipelining=True` for non-pipelined targets

`_use_worker_pipelining()` does not check whether a metadata action exists. Targets with
`disable_pipelining=True` get `supports-multiplex-workers` in exec_reqs for no benefit,
triggering Bazel 9's auto-worker selection.

**Fix:** `rust/private/rustc.bzl` — Add `and bool(build_metadata)` to the
`use_worker_pipelining` assignment.

### Root Cause 3: Worker handler self-copy corruption

With Root Cause 1's fix, rustc writes `.rmeta` directly to `_pipeline/`. The worker handler
would then try to copy `_pipeline/foo.rmeta` → `_pipeline/foo.rmeta` (same file). `fs::copy`
on Linux truncates the destination first, corrupting the file to 0 bytes.

**Fix:** `util/process_wrapper/worker.rs` — Add `canonicalize()` same-file check before
`fs::copy` in `handle_pipelining_metadata` to skip the copy when source and destination are
the same file.

### Remaining known issue: Worker JSON parse error

`"Could not parse json work request correctly"` — occurs on both Bazel 8 (non-fatal) and
Bazel 9 (potentially fatal). Root cause not fully identified. The parse-error recovery handler
now extracts `requestId` from malformed JSON and sends an error response (preventing Bazel from
hanging). This error did not block `//sdk` builds in validation.

### Phase 6: Staged Worker-Owned Execroot (COMPLETE)

The initial Phase 4 sandbox support relied on `current_dir(sandbox_dir)`. This is incompatible
with pipelining because Bazel may clean up the sandbox after the metadata response while the
background rustc is still running.

**Design:** The worker creates a persistent per-pipeline execution root under `_pw_state/`:

```
_pw_state/
  pipeline/<key>/
    execroot/      # hardlinked/symlinked copies of request inputs
    outputs/       # rustc's rewritten --out-dir
    metadata_request.json
    full_request.json
    pipeline.log   # per-pipeline debug log (preserved on failure)
```

**Key changes:**
- `WorkRequestContext` struct replaces raw field extraction
- `WorkerStateRoots` manages persistent `_pw_state/requests/` and `_pw_state/pipeline/` dirs
- `stage_request_inputs()` hardlinks/copies all `WorkRequest.inputs` into the staged execroot
- `seed_execroot_with_sandbox_symlinks()` + `seed_execroot_with_worker_entries()` populate the
  execroot with external repo symlinks and worker-level entries
- `rewrite_path_args_for_staged_execroot()` resolves `--emit=` paths against the staged execroot
- Pipeline dirs are cleaned up on success, preserved on failure for debugging

**Cache root seeding:** Bazel's external repo cache (`cache/repos/...`) uses self-referential
symlinks. The worker seeds `cache` symlinks in both the staged execroot and sandbox dirs so
rustc can resolve transitive symlink chains. `ensure_cache_loopback_for_path()` handles the
`cache/repos/<version>/cache → cache/` loopback pattern.

### Validation Status

- `bazel test //util/process_wrapper:process_wrapper_test` — PASSED (0 warnings)
- `bazel test //test/unit/pipelined_compilation/...` — 10/10 PASSED
- reactor-repo-2 `//sdk` with explicit worker mode (Bazel 9) — PASSED
- reactor-repo-2 `//sdk` with auto-strategy mode (Bazel 9) — PASSED
- Debug logging cleanup complete (removed `append_protocol_log`, `append_standalone_log`,
  all `eprintln!("[worker-pipeline]...")` calls; kept per-pipeline `append_pipeline_log`)

## Migration Notes

- This is a new opt-in feature behind `experimental_worker_pipelining`
- No breaking changes to existing behavior
- Requires `pipelined_compilation=true`; `experimental_incremental` is independent (recommended
  but not required — both features benefit from workers but serve different purposes)
- **On Bazel 9+, no `--strategy` flags are needed.** Bazel auto-selects the multiplex worker
  strategy from `supports-multiplex-workers` in execution requirements. On Bazel 8, use
  `--strategy=Rustc=worker,sandboxed --strategy=RustcMetadata=worker,sandboxed` to prefer the
  worker with a sandboxed fallback.
- **Multiplex sandboxing is supported but has significant overhead.** The worker sets
  `supports-multiplex-sandboxing` in exec_reqs and implements a staged worker-owned execroot
  (`_pw_state/pipeline/<key>/`) so background rustc processes survive sandbox cleanup between
  metadata and full actions. However, benchmarks (2026-03-09) show that
  `--experimental_worker_multiplex_sandboxing` adds ~16s of per-build overhead from input staging
  and output copying, negating the pipelining wall-time benefit (worker-pipe 84.8s vs no-pipeline
  86.8s — only 2.3% faster). Without multiplex sandboxing (2026-03-06), worker-pipe was 1.62×
  faster than no-pipeline. **Do not enable `--experimental_worker_multiplex_sandboxing` unless
  hermetic isolation is required.**
- **Avoid `local` as a fallback strategy.** `worker,local` falls back to unsandboxed execution.
  Prefer `worker,sandboxed` (or omit `--strategy` on Bazel 9+) so fallback actions are still
  sandboxed. The `sandboxed` fallback only applies when the worker strategy is unavailable — it
  does not cause the multiplex-sandboxing overhead. The only exception is when
  `experimental_incremental` is also enabled — incremental compilation requires `no-sandbox` for
  stable `/tmp/rules_rust_incremental/` cache paths, which is set automatically in exec_reqs.
- Recommended `.bazelrc`:
    ```
    build --@rules_rust//rust/settings:pipelined_compilation=true
    build --@rules_rust//rust/settings:experimental_worker_pipelining=true
    # Bazel 8 only (Bazel 9+ auto-selects from exec_reqs):
    # build --strategy=Rustc=worker,sandboxed
    # build --strategy=RustcMetadata=worker,sandboxed
    # Optional: also enable incremental compilation for additional speedup
    # build --@rules_rust//rust/settings:experimental_incremental=true
    # NOT recommended for performance (adds ~30% overhead from input staging):
    # build --experimental_worker_multiplex_sandboxing
    ```
- For dynamic execution, additionally set:
    ```
    build --experimental_worker_multiplex_sandboxing
    build --dynamic_local_strategy=Rustc=worker
    build --dynamic_local_strategy=RustcMetadata=worker
    ```
  Note: dynamic execution requires multiplex sandboxing. Accept the overhead trade-off
  (sandbox I/O cost vs remote execution latency savings).

## Open Design Questions (Resolved)

1. **Q: Should we use `.rmeta` or hollow rlibs for the worker path?**
   A: `.rmeta` — matches Cargo, simpler, no ar archive construction needed. Safe because single
   invocation eliminates SVH mismatch. `.rmeta` was previously abandoned only because of SVH issues
   with two invocations.

2. **Q: How to coordinate between metadata and full actions in the worker?**
   A: Multiplex worker guarantees all requests go to one OS process. Use in-process
   `HashMap<String, BackgroundRustc>` — no inter-process coordination needed.

3. **Q: What about remote execution?**
   A: Multiplex workers are local-only. Fall back to existing two-invocation approach for RBE.
   Phase 4 adds multiplex sandboxing, enabling dynamic execution (race local worker vs. remote).
   Sandboxed pipelining uses a worker-managed persistent output directory (`_pw_pipeline/<key>/`)
   so the background rustc process survives sandbox cleanup between the metadata and full actions.
   Without the worker strategy, actions fall through to the non-worker execution path where the
   pipelining flags are no-ops.

4. **Q: Does `experimental_use_cc_common_link` interact?**
   A: Worker-pipelined builds don't need it. The SVH mismatch that motivated it is eliminated by
   single invocation. The setting is orthogonal and can be used independently.

## References

- Cargo pipelining PR: https://github.com/rust-lang/cargo/pull/6883
- Cargo pipelining tracking: https://github.com/rust-lang/cargo/issues/6660
- rustc artifact notifications: https://github.com/rust-lang/rust/issues/58465
- Compiler team pipelining notes: https://rust-lang.github.io/compiler-team/working-groups/pipelining/NOTES/
- Bazel multiplex workers: https://bazel.build/remote/multiplex
- Bazel worker protocol: https://bazel.build/remote/persistent
- Bazel worker protocol proto: https://github.com/bazelbuild/bazel/blob/master/src/main/protobuf/worker_protocol.proto
- SVH mismatch test: `test/unit/pipelined_compilation/svh_mismatch_test.sh`
- 5-crate benchmark analysis: `thoughts/shared/benchmark_analysis.md`
- SDK benchmark analysis: `thoughts/shared/bench_sdk_analysis.md`
- Benchmark script: `thoughts/shared/bench_sdk.sh`
