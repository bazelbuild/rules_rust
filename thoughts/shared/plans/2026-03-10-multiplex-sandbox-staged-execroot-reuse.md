# Reusable Staged Execroot Plan For Sandboxed Multiplex Workers

## Context

The current sandboxed pipelining path in `process_wrapper` is correct but expensive:

- each pipelined metadata request creates a fresh worker-owned staged execroot under
  `_pw_state/pipeline/<key>/execroot` — the old directory is unconditionally deleted via
  `remove_dir_all` at the start of every call
  [[worker.rs:1031–1035]](#ref-pw-create-staged)],
- every declared input is restaged into that directory
  [[worker.rs:1077, stage_request_inputs]](#ref-pw-stage-inputs)],
- the background rustc keeps running after Bazel tears down the request sandbox
  [[worker.rs:1381–1391, BackgroundRustc stored in PipelineState]](#ref-pw-bg-rustc)],
- outputs are later materialized back into the request sandbox
  [[worker.rs:1506–1510, copy_all_outputs_to_sandbox]](#ref-pw-copy-outputs)].

The measurements collected on 2026-03-10 show three important things:

1. Input staging dominates the remaining sandbox tax.
2. Output materialization is negligible.
3. The top-level `//sdk` slowdown is not just a packaging anomaly; mixed targets like
   `//sdk/sdk_builder:sdk_builder_lib` and `//helium/asset_manager:asset_manager` also lose wall
   time under sandboxed `worker-pipe`.

The failed "real execroot" idea was too risky because it depends on Bazel implementation details
outside the documented worker contract. The failed "preseed top-level entries before staging"
experiment was also not viable: it regressed badly and changed the action mix in a way that likely
allowed stale `bazel-out` visibility to interfere with the pipelined path.

This document proposes the next safe design: keep using worker-owned staged roots, but reuse them
across requests instead of rebuilding them from scratch every time.

## Contract Constraints

This design is derived from:

- Bazel persistent worker docs: <https://bazel.build/remote/persistent>
- Bazel multiplex worker docs: <https://bazel.build/remote/multiplex>
- Bazel sandboxing docs: <https://bazel.build/docs/sandboxing>
- local design doc: [`/home/wgray/Downloads/Sandboxing Multiplex Bazel Workers.md`](/home/wgray/Downloads/Sandboxing%20Multiplex%20Bazel%20Workers.md)

The relevant contract points are:

1. Persistent workers do not run in the main action execroot; they have their own long-lived worker
   directory under Bazel's worker area
   [[WorkerFactory.java:155–161, getMultiplexSandboxedWorkerPath]](#ref-bz-worker-path)].
2. For multiplex sandboxing, the worker receives a `sandbox_dir` and is expected to interpret the
   request's reads and writes relative to that per-request root
   [[worker_protocol.proto:63–72, sandbox_dir field]](#ref-bz-proto-sandbox)].
3. Sandboxed actions are isolated by distinct per-request sandboxes; outputs must be materialized
   back into Bazel-managed output locations
   [[SandboxedWorkerProxy.java:118–122, finishExecution → moveOutputs]](#ref-bz-finish)].
4. The local design doc's implemented model corresponds to Proposal 2a: a per-request sandbox root
   is the source of truth, and worker implementations are responsible for translating tool paths to
   that root
   [[design doc §Proposal 2a; worker_protocol.proto:69, "paths in inputs will not contain this
   prefix"]](#ref-bz-proto-comment)].

Implication:

- We should not depend on Bazel's shared `execroot/_main` as a read source.
- We should not expose worker-private storage as Bazel outputs.
- Any reuse must stay inside worker-owned state and must still be derived from the request's
  declared `sandbox_dir`/`inputs`.

## Goal

Reduce per-request staging overhead for sandboxed pipelined metadata actions while preserving the
 current correctness model:

- request inputs still come from the request sandbox/input list,
- background rustc can outlive the request sandbox,
- outputs are still copied or hardlinked back into the request sandbox before response.

## Non-Goals

- Using Bazel's real shared execroot as the primary input source.
- Changing non-worker Rust actions.
- Changing the worker protocol.
- Solving cancellation or dynamic execution generally.
- Replacing sandboxed worker behavior with a weaker shared-sandbox model.

## Proposed Design

### High-Level Structure

Keep worker-owned staged execroots, but reuse a bounded pool of them:

```text
_pw_state/
  stage_pool/
    slot-000/
      execroot/
      manifest.json
      in_use
    slot-001/
      execroot/
      manifest.json
      in_use
    ...
  pipeline/<key>/
    outputs/
    metadata_request.json
    full_request.json
```

Instead of creating and deleting `_pw_state/pipeline/<key>/execroot` for every metadata request,
the worker borrows an idle stage slot, incrementally updates it to match the new request, runs
rustc there, and returns the slot to the pool once the full request completes.

### Why A Pool Instead Of One Shared Root

Multiplex workers process requests concurrently. A single mutable shared root would violate request
isolation. A small pool gives us:

- one mutable staged root per in-flight pipelined request,
- reuse across sequential requests,
- no cross-request mutation races inside an active root,
- no dependency on Bazel's shared execroot.

The pool size should match the worker's effective multiplex concurrency, not the number of crates in
the graph.

A slot is occupied for the entire pipeline lifetime — from metadata request arrival until the full
request completes — because the background rustc runs in the slot's execroot and must not see
mutations from another request. With 8 concurrent pipelined requests (Bazel default
`DEFAULT_MAX_MULTIPLEX_WORKERS = 8`
[[WorkerPoolImpl.java:55]](#ref-bz-default-multiplex)]), all 8 slots may be occupied simultaneously
with zero reuse opportunity.

Reuse kicks in when a pipeline completes and a new metadata request borrows the freed slot. In a
typical build DAG, this happens naturally: leaf crates finish early, freeing slots that are then
borrowed by mid-graph crates whose dependency sets heavily overlap with the previous occupant. The
benefit grows as the build progresses past the initial fan-out phase, which is exactly when the
dependency overlap is highest.

### Slot Manifest

Each slot keeps a manifest of the staged view:

```json
{
  "request_id": 123,
  "entries": {
    "external/foo/src/lib.rs": {
      "digest": "a1b2c3...",
      "kind": "symlink",
      "resolved_target": "/home/user/.cache/bazel/.../execroot/_main/external/foo/src/lib.rs"
    },
    "bazel-out/k8-fastbuild/bin/lib/math/_pipeline/libmath.rmeta": {
      "digest": "d4e5f6...",
      "kind": "hardlink"
    }
  },
  "seed_entries": [
    "external",
    "bazel-out",
    "rust_linux_x86_64__x86_64-unknown-linux-gnu__stable_raw"
  ]
}
```

Important: `resolved_target` must always be the **canonical dereferenced path** (the real filesystem
location), never a sandbox-relative path. The current staging code in `copy_or_link_path()` already
follows symlinks through the sandbox to the real target before creating entries
[[worker.rs:640–662, symlink resolution and safe_to_preserve check]](#ref-pw-copy-or-link)]. This is
critical because different `SandboxedWorkerProxy` instances send different `sandbox_dir` values
(`__sandbox/<workerId>/<workspace>`)
[[SandboxedWorkerProxy.java:58–65, sandboxName construction]](#ref-bz-sandbox-name)]; if the
manifest stored sandbox paths, entries would always appear "changed" when requests come from
different proxies, defeating the optimization.

Digests are hex-encoded content hashes (typically SHA-256), provided by Bazel via
`WorkRequest.inputs[].digest` for virtually all regular file inputs
[[worker_protocol.proto:22–33, Input message]](#ref-bz-proto-input);
[[WorkerSpawnRunner.java:262–282, digest population from inputFileCache]](#ref-bz-digest)].
The worker parses these as JSON strings
[[worker.rs:1690–1693, extract_inputs digest parsing]](#ref-pw-extract-inputs)].
When absent (rare edge cases like virtual inputs), fall back to the resolved target path or
stat-based fingerprinting.

The manifest has two sections:

- `entries`: per-input staged paths, diffed on every request (see Reuse Algorithm)
- `seed_entries`: top-level symlinks created by sandbox/worker seeding, created once per slot
  lifetime (see Seed Entry Handling)

The key property is that the manifest is keyed by request-visible relative path, not by the worker's
real execroot.

### Structural Change: Decoupling Execroot From Pipeline Dir

Currently, `StagedPipeline` [[worker.rs:482–486]](#ref-pw-staged-pipeline) bundles three sibling
paths under a single pipeline directory:

```text
_pw_state/pipeline/<key>/
  execroot/     ← staged inputs for rustc
  outputs/      ← rustc writes here (via --out-dir rewrite)
  metadata_request.json
```

The new design separates these concerns:

- **Execroot** moves into a pool slot: `_pw_state/stage_pool/slot-N/execroot/`
- **Outputs** remain per-pipeline: `_pw_state/pipeline/<key>/outputs/`
- **Request snapshots** remain per-pipeline: `_pw_state/pipeline/<key>/metadata_request.json`

`StagedPipeline` evolves to hold references to both:

```rust
struct StagedPipeline {
    slot: BorrowedSlot,           // slot-N, released on full completion
    execroot_dir: PathBuf,        // slot-N/execroot/ (canonical)
    outputs_dir: PathBuf,         // pipeline/<key>/outputs/ (canonical)
    pipeline_root_dir: PathBuf,   // pipeline/<key>/
}
```

`BackgroundRustc` [[worker.rs:426–443]](#ref-pw-bg-rustc-struct) must also store the `BorrowedSlot`
(or slot ID) so the full handler can release the slot after collecting outputs. Arg rewriting is
unchanged in intent:

- `rewrite_out_dir_in_expanded()` still points `--out-dir` to `pipeline/<key>/outputs/`
  [[worker.rs:1261–1264, current usage in metadata handler]](#ref-pw-rewrite-outdir)]
- `rewrite_emit_paths_for_execroot()` resolves `--emit` paths relative to the slot's execroot
  (`slot-N/execroot/`) instead of the old `pipeline/<key>/execroot/`
  [[worker.rs:1154–1182, function definition]](#ref-pw-rewrite-emit)]

### Reuse Algorithm

For each pipelined metadata request:

1. Borrow an idle slot from the pool.
2. Build the desired entry map from `WorkRequest.inputs` and `sandbox_dir`.
3. Diff desired entries against the slot manifest.
4. Only touch paths that changed:
   - unchanged path + unchanged digest: leave existing staged entry in place
   - new path: create staged entry
   - changed digest or changed target: replace staged entry
   - removed path: delete staged entry
5. Run rustc in `slot-N/execroot`.
6. Keep outputs in `_pw_state/pipeline/<key>/outputs`.
7. When the full request finishes, release the slot for reuse.

This changes staging cost from "rebuild all declared inputs per request" to "update only the delta
between the previous request and the current one for that slot".

### Seed Entry Handling

The current staging has three phases, not one:

1. `stage_request_inputs()` [[worker.rs:795–821]](#ref-pw-stage-inputs) — iterates `request.inputs`
   (the bulk of the work)
2. `seed_execroot_with_sandbox_symlinks()` [[worker.rs:915–979]](#ref-pw-seed-sandbox) — creates
   top-level symlinks from `sandbox_dir` entries (toolchains, external repos)
3. `seed_execroot_with_worker_entries()` [[worker.rs:981–1022]](#ref-pw-seed-worker) — creates
   top-level symlinks from the worker's CWD (workspace roots)

Phases 2 and 3 produce entries that are stable across the entire build: toolchain paths, external
repository roots, and workspace symlinks do not change between requests. These entries benefit *most*
from reuse because they are identical across all requests.

For seed entries, the manifest tracks only the top-level entry names (the `seed_entries` list). The
reuse rule is simple:

- On first use of a slot: run both seeding phases normally and record the entry names.
- On subsequent uses: skip seeding entirely if the seed entry list is non-empty. These symlinks
  point to stable targets outside the sandbox and do not change within a build.
- On full slot reset: clear the seed entry list, forcing re-seeding on next use.

This avoids iterating the sandbox and worker CWD directories on every request — currently a
meaningful contributor to staging time that is entirely redundant after the first pass.

## Safety Rules

### 1. Never Reuse Bazel Outputs Directly

Do not preseed `bazel-out` from the worker's own working directory. The failed experiment showed
that making top-level worker entries visible before staging can destabilize the pipelined path.

### 2. Sandbox-Derived Inputs Only

All staged entries must still be derived from:

- `request.inputs`
- `request.sandbox_dir`

That keeps the request sandbox as the source of truth for request-visible inputs.

### 3. Slot-Local Mutation Only

Only the slot currently borrowed by a request may be mutated for that request. No cross-slot shared
mutable trees.

### 4. Outputs Stay Worker-Private Until Materialization

The background rustc still writes to `_pw_state/pipeline/<key>/outputs`, and Bazel-visible outputs
are still materialized back into the request sandbox/output tree as regular files
[[worker.rs:745–771, materialize_output_file]](#ref-pw-materialize);
on the Bazel side, outputs are moved from sandbox to execroot via rename with copy fallback
[[SandboxHelpers.java:176–236, moveOutputs]](#ref-bz-move-outputs)].

### 5. Conservative Invalidation

If the worker cannot prove that an entry is unchanged, it restages it. The design should prefer
false misses over false hits.

## Input Identity

Primary key:

- relative input path
- declared digest when Bazel provides one

Fallback when digest is absent:

- symlink target path for preserved symlinks, or
- `symlink_metadata`/`metadata` fingerprint tuple for regular files/directories

The fallback should be treated as best-effort and conservative. If identity is ambiguous, replace
the entry.

## Expected Benefits

This targets the exact bottleneck we measured:

- `//zm_cli:zm_cli_lib`: about 55s total in staging across 280 metadata actions
- profiled `sdk_builder_lib` run: about 30s total in staging across 226 metadata actions

Many Rust graphs repeatedly rebuild roots like:

- `external/...`
- `bazel-out/.../_pipeline/*.rmeta`
- first-party source trees

Across sequential requests, most of those paths should remain identical or change only in a small
subset, especially after the early fan-out phase. Slot reuse should therefore reduce filesystem
work substantially on mixed graphs, where current per-request staging overhead is not paid back by a
shorter critical path.

## Implementation Plan

### Phase 1: Add A Stage Slot Abstraction ✅

Introduce:

- [x] `BorrowedSlot` (plan called it `StageSlot`)
- [x] `StagePool`
- [x] `StageManifest`

Requirements:

- [x] bounded slot count (`STAGE_POOL_SIZE = 8`)
- [x] borrow/release lifecycle with `Mutex<VecDeque<usize>>`; borrow is fallible (returns
  `None` when all slots are busy, triggering one-shot staging fallback)
- [x] manifest load/store in worker-owned state (`_pw_state/stage_pool/slot-N/manifest.json`)
- [x] each `BorrowedSlot` holds an exclusive reference — drop impl returns the slot to the pool

### Phase 2: Move From Rebuild To Diff ✅

Replace `create_staged_pipeline()`'s "delete and recreate execroot" behavior with:

- [x] slot acquisition (`StagePool::try_borrow`)
- [x] manifest diff (`diff_and_stage_request_inputs`)
- [x] targeted create/update/delete of changed paths
- [x] seed phase reuse (`seed_execroot_for_slot`, skips when `seed_entries` non-empty)
- [x] one-shot fallback when all slots busy

Existing path rewrite and output materialization behavior unchanged.

### Phase 3: Instrument Reuse ✅

Pipeline log now emits per-request:

- [x] unchanged entries reused
- [x] entries replaced
- [x] entries removed
- [x] total manifest entries
- [x] stage diff time vs seed time vs total setup time
- [x] seed phase skipped vs executed
- [x] slot ID and reuse_count

Log format: `staging slot=N reuse_count=N reused=N replaced=N added=N removed=N total_manifest=N files=N dirs=N symlinks=N hardlinks=N copies=N seed_skipped=true/false diff_ms=N seed_ms=N total_setup_ms=N`

### Phase 4: Correctness Validation

Validate:

- [ ] metadata/full pipelining still succeeds under multiplex sandboxing
- [ ] no stale `.rmeta` leakage across requests
- [ ] `bazel-out/.../_pipeline` entries are updated when digests change
- [ ] worker restart loses only cached slot state, not correctness

### Phase 5: Benchmark Gates

Acceptance bar:

- [ ] `//zm_cli:zm_cli_lib` must stay at least as good as the current safe path
- [ ] `sdk_builder_lib` and `asset_manager` should show reduced worker preparation overhead
- [ ] `//sdk` must improve or at minimum explain remaining loss via non-worker actions
- [ ] total staging wall time (from Phase 3 instrumentation) must show ≥50% reduction vs baseline
- [ ] comparison against the non-sandboxed worker-pipe path to quantify remaining sandbox overhead

## Benchmark Results (2026-03-11)

### Findings

Full 3-iteration benchmark on `//sdk` with Bazel 9 + `--experimental_worker_multiplex_sandboxing`:

**Cold builds (iters 2-3, mean):**
| config            | wall_s | crit_s | overhead |
|-------------------|--------|--------|----------|
| no-pipeline       | 84.9   | 70.0   | 14.9s    |
| worker-pipe       | 83.3   | 54.3   | 29.0s    |
| worker-pipe+incr  | 104.9  | 81.7   | 23.2s    |

**vs previous benchmark (pre-stage-pool):** overhead was 31.2s → now 29.0s = **2.2s (7%) improvement**.

**Critical path** improved 25% (54.3s vs 70.0s) — unchanged from pre-stage-pool.

### Root Cause: Stage Pool Slot Reuse Never Happens

Manifest analysis confirms: every slot across all 617 used slots has `reuse_count=1`. The diff
mechanism was never triggered even once.

Cause: with `--experimental_worker_multiplex_sandboxing`, Bazel spawns many worker processes
(~72+ per cold build session, one per concurrent-request batch). Each process handles only
~2-8 requests (one concurrent "batch" of pipeline pairs). After those complete, no further
requests arrive, so slots are never reused for a 2nd crate.

Additionally, 8 concurrent pipelining pairs per worker fill all 8 slots simultaneously. After
the batch, slots are freed but the worker is idle. Net result: `reuse_count` stays at 1 for
every slot.

### What Does Work

- **Early .rmeta** still provides 25% critical path improvement (downstream deps start sooner)
- **Builds are correct** (canonicalization fix resolved the doubled-path error from iter 1)
- **Stage pool infrastructure is correct** (manifests written, RAII drop works, pool state
  managed correctly) — it's just that the slot lifetime assumption (one worker handles many
  sequential requests) doesn't match the actual Bazel multiplex sandboxed worker behavior

### What Doesn't Work (Yet)

- Slot reuse: Bazel routes concurrent requests across many workers; each worker sees at most one
  "batch" of concurrent pipeline pairs before going idle
- Phase 5 goal (≥50% staging overhead reduction) is not met (7% actual)
- The stage pool design is correct for a scenario where each worker handles many sequential
  requests over its lifetime; it just needs that scenario to be real

### Next Steps Options

1. **Accept the current state**: early .rmeta still reduces critical path by 25%; document the
   limitation that stage pool reuse only helps in long-lived worker sessions (e.g. warm rebuilds)
2. **Shared pool across workers**: use a shared filesystem directory (e.g.
   `_pw_state_shared/stage_pool/`) accessible from all worker processes, with filesystem-level
   locking. Each slot can then be claimed by whichever worker needs it, regardless of process
   boundaries. The detailed follow-up design now lives in
   [`2026-03-11-cross-process-shared-stage-pool-plan.md`](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-11-cross-process-shared-stage-pool-plan.md).
3. **Reduce staging entirely**: investigate why Bazel's own per-request input staging (in
   `__sandbox/N/_main`) costs ~16s — the worker-side staging may be secondary to Bazel's own
   overhead.

Note on option 3 from follow-up work on 2026-03-11: a broad metadata/toolchain input-pruning
attempt regressed full `//sdk` correctness with `E0463` missing-crate failures. Any future
input-set reduction should be treated as a trace-driven effort, starting from observed file-access
data for individual metadata actions and requiring full-graph validation before landing.

The concrete follow-up benchmark matrix and decision criteria for those options now live in
[`2026-03-11-multiplex-sandbox-overhead-investigation-plan.md`](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-11-multiplex-sandbox-overhead-investigation-plan.md).

## Risks

### Manifest Drift

If the manifest says an entry is valid when it is not, rustc may consume stale inputs. This is the
main correctness risk.

Mitigation:

- trust Bazel digest when present
- replace on uncertainty
- add targeted tests around changed `_pipeline/*.rmeta` inputs

### Slot Contention

If all slots are busy, new requests must wait or fall back.

Mitigation:

- size the pool to worker multiplex concurrency
- optionally fall back to one-shot staging if no slot is available

### Cleanup Complexity

Reused slots can accumulate orphaned paths if removals are buggy.

Mitigation:

- explicit manifest-driven deletes
- automatic full slot reset (`remove_dir_all` + clear manifest) after every N reuses (e.g., N=50) or
  when `removed_entries > total_entries / 2` in a single diff pass, whichever comes first
- this bounds worst-case accumulation without requiring manual flags; the reset cost is amortized
  over many requests and is equivalent to the current one-shot staging cost

## Why This Design Matches The Bazel Contract Better

Compared with the rejected real-execroot idea:

- it does not depend on undocumented Bazel execroot layout,
- it does not read from shared `execroot/_main`,
- it keeps the request sandbox/input list as the authoritative request view,
- it keeps Bazel-visible outputs materialized as real files.

Compared with Proposal 1 (Shared sandboxing) from the local design doc
[[design doc §Proposal 1]](#ref-design-doc-p1)]:

- it borrows the useful optimization idea of stateful reuse across actions (the design doc notes
  "roughly 90% of symlinks are reused from one action to the next"),
- but keeps isolation by reusing a pool of private staged roots rather than a single shared mutable
  sandbox (avoiding the race conditions that led to Proposal 1 being marked as incompatible with
  dynamic execution without cancellation).

That is a stricter and safer fit for current multiplex sandboxing than a shared worker-wide view.

### Precedent: Bazel Already Does This Server-Side

Bazel's own `SandboxedWorkerProxy` implements exactly this optimization on the server side. Each
proxy keeps its `sandboxDir` between requests — it is never deleted in `finishExecution`, only in
`destroy()` [[SandboxedWorkerProxy.java:118–132]](#ref-bz-finish)]. Before each new request,
`prepareExecution()` calls `SandboxHelpers.cleanExisting()` to incrementally update the symlink farm
[[SandboxedWorkerProxy.java:94–100]](#ref-bz-prepare); then `WorkerExecRoot.createInputs()` only
creates what is genuinely missing
[[SandboxedWorkerProxy.java:104; WorkerExecRoot.java:107–128]](#ref-bz-create-inputs)].

The incremental cleanup in `cleanExisting`
[[SandboxHelpers.java:264–328]](#ref-bz-clean-existing) traverses the existing sandbox, removes
stale symlinks that point to the wrong target, and removes entries from the "to create" set that
already exist on disk with the correct target.

This worker-side pool design is the mirror of that server-side pattern, applied to the secondary
staged execroot that the process wrapper creates for background rustc. The fact that Bazel's own
implementation validates the incremental-update approach for sandbox content is strong evidence that
the pattern is correct and effective.

## Required Verification

- `bazel test //util/process_wrapper:process_wrapper_test`
- focused cold comparisons:
  - `//zm_cli:zm_cli_lib`
  - `//sdk/sdk_builder:sdk_builder_lib`
  - `//helium/asset_manager:asset_manager`
- one `//sdk` run with the same benchmark flags used in `thoughts/shared/bench_sdk.sh`

## Source References

All Bazel paths are relative to `/var/mnt/dev/bazel/src/main/java/com/google/devtools/build/lib/`
unless noted otherwise. All process_wrapper paths are relative to
`/var/mnt/dev/rules_rust/util/process_wrapper/`.

### Bazel Source (worker sandboxing implementation)

<a id="ref-bz-proto-sandbox"></a>
- **worker_protocol.proto:63–72** — `WorkRequest.sandbox_dir` field (field 6) and its semantics
  comment: "The paths in inputs will not contain this prefix, but the actual files will be
  placed/must be written relative to this directory."
  (`/var/mnt/dev/bazel/src/main/protobuf/worker_protocol.proto`)

<a id="ref-bz-proto-input"></a>
- **worker_protocol.proto:22–33** — `Input` message definition: `string path = 1; bytes digest = 2`
  (`/var/mnt/dev/bazel/src/main/protobuf/worker_protocol.proto`)

<a id="ref-bz-proto-comment"></a>
- **worker_protocol.proto:69** — "The paths in `inputs` will not contain this prefix"

<a id="ref-bz-sandbox-name"></a>
- **worker/SandboxedWorkerProxy.java:58–65** — `sandboxName` construction:
  `__sandbox/<workerId>/<workerKey.getExecRoot().getBaseName()>`

<a id="ref-bz-prepare"></a>
- **worker/SandboxedWorkerProxy.java:75–105** — `prepareExecution()`: creates sandbox dir (line 84),
  calls `populateInputsAndDirsToCreate` (88–93), `cleanExisting` (94–100),
  `createDirectories` (103), `createInputs` (104)

<a id="ref-bz-finish"></a>
- **worker/SandboxedWorkerProxy.java:118–132** — `finishExecution()` calls `moveOutputs` (line 121)
  but does NOT delete `sandboxDir`; deletion only in `destroy()` (line 128)

<a id="ref-bz-put-request"></a>
- **worker/SandboxedWorkerProxy.java:109–115** — `putRequest()` injects `sandbox_dir` into the
  `WorkRequest` before forwarding to the multiplexer

<a id="ref-bz-worker-path"></a>
- **worker/WorkerFactory.java:155–161** — `getMultiplexSandboxedWorkerPath()`: constructs worker
  work dir as `<workerBaseDir>/<mnemonic>-<workerTypeName>-<multiplexerId>-workdir/<workspace>/`

<a id="ref-bz-worker-factory"></a>
- **worker/WorkerFactory.java:95–108** — `create()` branching: `SandboxedWorkerProxy` instantiated
  when `key.isSandboxed() && key.isMultiplex()`

<a id="ref-bz-create-inputs"></a>
- **worker/WorkerExecRoot.java:107–128** — `createInputs()`: static method creating symlinks for
  each input fragment; `key.createSymbolicLink(fileDest)` at line 117

<a id="ref-bz-clean-existing"></a>
- **sandbox/SandboxHelpers.java:264–328** — `cleanExisting()`: traverses existing sandbox dir,
  removes stale entries, removes already-valid entries from `inputsToCreate`/`dirsToCreate` sets

<a id="ref-bz-move-outputs"></a>
- **sandbox/SandboxHelpers.java:176–236** — `moveOutputs()`: `source.renameTo(target)` at line 204
  (primary); byte-copy fallback at lines 222–233 for cross-device moves

<a id="ref-bz-digest"></a>
- **worker/WorkerSpawnRunner.java:262–282** — `createWorkRequest()` digest population:
  `inputFileCache.getInputMetadata(input).getDigest()` returns digest bytes, encoded to hex string
  via `HashCode.fromBytes(digestBytes).toString()`

<a id="ref-bz-default-multiplex"></a>
- **worker/WorkerPoolImpl.java:55** — `DEFAULT_MAX_MULTIPLEX_WORKERS = 8`

<a id="ref-bz-worker-key"></a>
- **worker/WorkerKey.java:37–65** — Worker key fields: `args` (including executable as first
  element), `env`, `execRoot`, `mnemonic`, `multiplex`, `sandboxed`, etc. Identity defined by
  `equals()` at lines 165–202 and `calculateHashCode()` at lines 210–223.

### Process Wrapper Source (worker pipelining implementation)

<a id="ref-pw-create-staged"></a>
- **worker.rs:1024** — `create_staged_pipeline()` function definition

<a id="ref-pw-teardown"></a>
- **worker.rs:1031–1035** — unconditional `fs::remove_dir_all(&root_dir)` at start of
  `create_staged_pipeline`; only ignores `NotFound`

<a id="ref-pw-stage-inputs"></a>
- **worker.rs:795–821** — `stage_request_inputs()` function; iterates `request.inputs`, resolves
  source paths, calls `copy_or_link_path` per entry

<a id="ref-pw-copy-or-link"></a>
- **worker.rs:630–662** — `copy_or_link_path()`: reads `symlink_metadata` (line 637), follows
  symlinks through sandbox to real target (lines 640–662), `safe_to_preserve` check at 649–650

<a id="ref-pw-seed-sandbox"></a>
- **worker.rs:915–979** — `seed_execroot_with_sandbox_symlinks()`: iterates `sandbox_dir`
  top-level entries, creates symlinks for external/toolchain paths not yet in execroot

<a id="ref-pw-seed-worker"></a>
- **worker.rs:981–1022** — `seed_execroot_with_worker_entries()`: iterates worker CWD entries
  (excluding `_pw_state`), creates symlinks in staged execroot

<a id="ref-pw-metadata"></a>
- **worker.rs:1198–1204** — `handle_pipelining_metadata()` function definition

<a id="ref-pw-full"></a>
- **worker.rs:1464–1470** — `handle_pipelining_full()` function definition

<a id="ref-pw-rewrite-outdir"></a>
- **worker.rs:1261–1264** — `rewrite_out_dir_in_expanded()` and `rewrite_emit_paths_for_execroot()`
  usage in metadata handler (nested call)

<a id="ref-pw-rewrite-emit"></a>
- **worker.rs:1154–1182** — `rewrite_emit_paths_for_execroot()` function definition

<a id="ref-pw-bg-rustc-struct"></a>
- **worker.rs:426–443** — `BackgroundRustc` struct: `child`, `diagnostics_before`, `stderr_drain`,
  `pipeline_root_dir`, `pipeline_output_dir`, `original_out_dir`

<a id="ref-pw-bg-rustc"></a>
- **worker.rs:1381–1391** — `BackgroundRustc` stored in `PipelineState.active` after metadata
  response sent

<a id="ref-pw-staged-pipeline"></a>
- **worker.rs:482–486** — `StagedPipeline` struct: `root_dir`, `execroot_dir`, `outputs_dir`

<a id="ref-pw-pipeline-state"></a>
- **worker.rs:449–451** — `PipelineState` struct with `active: HashMap<String, BackgroundRustc>`

<a id="ref-pw-extract-inputs"></a>
- **worker.rs:1672–1701** — `extract_inputs()`: parses `WorkRequest.inputs` from JSON; digest
  extraction at lines 1690–1693

<a id="ref-pw-input-struct"></a>
- **worker.rs:76–80** — `WorkRequestInput` struct: `path: String`, `digest: Option<String>`

<a id="ref-pw-materialize"></a>
- **worker.rs:745–771** — `materialize_output_file()`: removes existing dest, tries
  `fs::hard_link`, falls back to `fs::copy`

<a id="ref-pw-copy-outputs"></a>
- **worker.rs:1506–1510** — full handler calls `copy_all_outputs_to_sandbox()` (defined at
  worker.rs:1925–1951)

<a id="ref-pw-cleanup"></a>
- **worker.rs:894–909** — `maybe_cleanup_pipeline_dir()`: calls `remove_dir_all` when
  `should_preserve_pipeline_dir` returns false

<a id="ref-pw-preserve"></a>
- **worker.rs:911–913** — `should_preserve_pipeline_dir()`: preserves on non-zero exit or when no
  `.rlib` in staged outputs

### Design Doc

<a id="ref-design-doc-p1"></a>
- **Sandboxing Multiplex Bazel Workers §Proposal 1** — Shared sandboxing: reference-counted
  symlinks in worker CWD, "roughly 90% of symlinks are reused from one action to the next".
  Marked incompatible with dynamic execution without cancellation.
  (`/home/wgray/Downloads/Sandboxing Multiplex Bazel Workers.md`)

### Settings

<a id="ref-settings"></a>
- **rust/settings/settings.bzl:114–131** — `pipelined_compilation` bool_flag (default False)
- **rust/settings/settings.bzl:134–160** — `experimental_use_cc_common_link` bool_flag (default
  False) with companion config_settings
- **rust/settings/settings.bzl:582–609** — `experimental_worker_pipelining` bool_flag (default
  False)
