# Consolidated Plan: Rust Worker Pipelining and Multiplex Sandboxing

## Status

Canonical reference document.

This is now the only plan file for this design area. Earlier dated working notes were removed after
their still-useful conclusions were merged here.

## Purpose

The original plan stack was useful while the design was moving quickly, but it left multiple
mutually incompatible states reading as if they were all current at once. This document keeps only
what should survive that cleanup:

- what is actually implemented on this branch,
- which approaches failed, were abandoned, or were superseded and why,
- which conclusions still hold,
- and which contract-sensitive questions remain open.

It intentionally preserves the design history without preserving the old file stack as a second
source of truth.

## Current Implementation On This Branch

The current branch has the following behavior:

1. Worker-managed pipelining exists for pipelined `rlib` and `lib` crates.
2. Metadata and full actions are wired to the same worker key by:
   - moving per-request process-wrapper flags into the param file,
   - moving per-crate environment into an env file,
   - suppressing companion `--output-file` artifacts that would otherwise perturb startup args,
   - and aligning the worker-facing action shape so the metadata and full requests can share
     in-process state.
3. In sandboxed mode, rustc now runs with `cwd = sandbox_dir`.
4. The worker still redirects `--out-dir` to worker-owned `_pw_state/pipeline/<key>/outputs/`
   and copies declared outputs back into Bazel-visible output locations later.
5. The background rustc process still spans the metadata response and the later full request.
6. The older two-invocation hollow-rlib path still exists and remains the important fallback /
   compatibility path.
7. Incremental-compilation and dynamic-execution wiring both exist, but the sandboxed
   worker-pipelining path should still be treated as contract-sensitive and experimental rather
   than as a fully settled final architecture.

The important negative statement is:

- the current branch is **not** using staged execroot reuse,
- **not** using cross-process stage pools,
- **not** using resolve-through to the real execroot as the current sandbox story,
- and **not** using the alias-root (`__rr`) design.

## Bazel Contract Constraints That Still Matter

Any future design should continue to treat Bazel's documented worker behavior as the contract:

1. Multiplex sandboxing is rooted at `sandbox_dir`.
2. The worker protocol expects per-request output to be returned through `WorkResponse`.
3. Once a worker has responded to a request, any continued touching of worker-visible files is
   contract-sensitive and should not be hand-waved away by older strace-based reasoning.
4. If cancellation is advertised, the worker must not rely on "best effort" semantics that leave a
   request mutating outputs after the cancel response unless that behavior is intentionally
   documented as a limitation.

This consolidated plan does not try to re-litigate the Bazel documentation. It simply records that
future design work should start from the documented contract, not from superseded assumptions in the
older plan files.

## Sandbox Contract Compliance Analysis

This section records what is known about how the current implementation interacts with the two
primary rules of the Bazel multiplex sandbox contract.

### The Two Rules

From [Creating Persistent Workers](https://bazel.build/remote/creating):

- **Rule 1**: The worker must use `sandbox_dir` as a prefix for all file reads and writes.
- **Rule 2**: "Once a response has been sent for a WorkRequest, the worker must not touch the files
  in its working directory. The server is free to clean up the files, including temporary files."

### How The Current Implementation Addresses Each Rule

**Rule 1 (sandbox_dir for all I/O):**
Satisfied. In sandboxed mode, rustc runs with `cwd = sandbox_dir` (`worker_pipeline.rs`,
`create_pipeline_context`). All relative paths in rustc args (`--extern`, `-Ldependency`, source
files) resolve against `sandbox_dir`. Outputs are redirected to `_pw_state/pipeline/<key>/outputs/`
(a persistent worker-owned directory outside the sandbox).

**Rule 2 (no file access after response):**
The metadata `WorkResponse` is sent as soon as `.rmeta` is emitted. The background rustc continues
doing codegen. The safety argument has three layers:

1. **Rustc architecture**: metadata is encoded at the boundary between analysis and codegen
   (`rustc_interface/src/passes.rs`, `start_codegen` → `encode_and_write_metadata` →
   `codegen_crate`). All parsing, type checking, borrow checking, and MIR passes complete before
   metadata. Source files are read once during parsing into `Arc<String>` in the `SourceMap` (no
   re-reads). Dependency `.rmeta` files are memory-mapped once during name resolution into
   `CrateMetadata` in the `CStore`. Proc macros are fully expanded during parsing.

2. **Empirical verification**: strace on rustc 1.94.0 across three cases (simple deps,
   `include_str!`, serde derive proc macro) confirmed zero input file reads after `.rmeta` emission.
   FDs to input files are fully closed before the `.rmeta` write, not just unused.

3. **Output isolation**: `--out-dir` is redirected to `_pw_state/pipeline/<key>/outputs/`, so all
   codegen writes (`.o`, `.rlib`, `.d`) go to a persistent worker-owned directory outside
   `sandbox_dir`.

### Strength of the Evidence

The practical safety story is strong: rustc's compilation pipeline architecture guarantees input I/O
is complete before metadata emission, the strace evidence confirms it, and Linux mmap semantics
provide an additional safety net (mmap survives `unlink`).

The contractual story is weaker: we rely on undocumented rustc implementation details (the
compilation pipeline ordering is not a stable API), and we operate outside the documented Bazel
worker contract (no precedent for background work spanning two requests). The strace evidence covers
sampled rustc versions and crate shapes, not all possible configurations.

### Known Caveats

1. **Incremental compilation**: `-C incremental=<path>` causes reads and writes to the incremental
   cache during codegen. The incremental directory must be outside `sandbox_dir` (currently placed
   in `_pw_state/pipeline/<key>/`).

2. **mmap page faults**: dependency metadata is mmap'd. On Linux, mmap holds an inode reference so
   file deletion doesn't break access. Cross-platform behavior is less well characterized.

3. **Cancellation**: the cancel handler must kill the background rustc to prevent wasted CPU and
   ensure no further file mutation after a cancel response. The full-phase cancellation gap (where
   the full handler has taken the `BackgroundRustc` from `PipelineState`) is addressed by the
   request-ID index design in the "Cancellation Direction" section below.

### Sources

- [rustc compilation pipeline — passes.rs](https://github.com/rust-lang/rust/blob/master/compiler/rustc_interface/src/passes.rs) — `encode_and_write_metadata` called before `codegen_crate`
- [Libraries and metadata — Rustc Dev Guide](https://rustc-dev-guide.rust-lang.org/backend/libs-and-metadata.html) — "As early as it can, rustc will save the rmeta file to disk before it continues to the code generation phase"
- [Pipelining stabilization — rust-lang/rust#60988](https://github.com/rust-lang/rust/issues/60988) — "metadata is now generated right at the start of code generation"
- [SourceMap — rustc_span](https://github.com/rust-lang/rust/blob/main/compiler/rustc_span/src/source_map.rs) — source files read via `read_to_string` into `Arc<String>`, no re-reads
- [Mmap for rmeta — rust-lang/rust#55556](https://github.com/rust-lang/rust/pull/55556) — dependency metadata mmap'd once
- [Creating Persistent Workers — Bazel](https://bazel.build/remote/creating) — "must not touch the files in its working directory" after response
- [Multiplex Workers — Bazel](https://bazel.build/remote/multiplex) — sandbox_dir contract
- [SandboxedWorkerProxy.java — bazelbuild/bazel](https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/worker/SandboxedWorkerProxy.java) — sandbox_dir lifecycle (cleaned before next request, not deleted after response)

## Aborted, Failed, And Superseded Approaches

| Approach | Outcome | Why It Stopped | What To Keep |
| --- | --- | --- | --- |
| Initial worker-managed one-rustc pipelining | Partially landed | The core model was useful, but later plan layers overstated how settled the sandboxed form was | Keep the worker-managed metadata-to-full handoff, the worker protocol handling, and the hollow-rlib fallback |
| Per-worker staged execroot reuse | Abandoned | Measured reuse was effectively nonexistent under actual multiplex-sandbox worker lifetimes, so the added slot and manifest machinery optimized the wrong boundary | Keep the evidence that worker-side restaging was real overhead and that early `.rmeta` still helped the critical path |
| Cross-process shared stage pool | Abandoned before a prototype landed | It added even more leasing and invalidation complexity, and part of the motivation was later explained by worker-key fragmentation rather than a fundamentally shared-pool-sized problem | Keep the lesson that stable worker keys matter more than elaborate pool sharing |
| Resolve-through via the real execroot | Partially landed, then superseded | It materially reduced worker-side staging cost, but it reads outside `sandbox_dir` and therefore does not match Bazel's documented multiplex-sandbox contract | Keep the performance insight that removing worker-side restaging matters; do not treat the contract story as settled |
| Broad metadata input pruning as a cheap sandbox fix | Failed investigation | A broad pruning attempt regressed real builds with `E0463` missing-crate failures | Keep the rule that any future input narrowing must be trace-driven and validated against full graphs |
| Alias-root strict-sandbox alternative | Explored, not landed | It matched the `sandbox_dir` contract better, but its viability relied on strace-based reasoning about post-`.rmeta` rustc I/O and would require a larger rewrite and validation pass than justified so far | Keep the stricter contract framing and explicit kill criteria; do not treat the provisional Gate 0 reasoning as final product guidance |
| Promotion of sandboxed worker pipelining to a stable, final story | Deferred | Benchmark improvements arrived before cancellation, teardown, and background-lifetime questions were settled strongly enough | Keep the reminder that good local benchmark numbers are not enough to claim the sandboxed path is fully supported |

## Historical Evidence Worth Keeping

These points are worth preserving even though the documents that first recorded them are gone:

1. Stable worker keys were a prerequisite, not a detail.
   Earlier measurements that looked like proof of inherently short-lived workers were partly
   distorted by per-action process-wrapper flags living in startup args. Moving those request-
   specific flags into per-request files was necessary for metadata and full requests to share one
   worker process and one in-process pipeline state. The key offenders were per-action
   `--output-file`, `--env-file`, `--arg-file`, `--rustc-output-format`, and stamped-action
   status-file flags. Earlier measurements that showed roughly one worker process per action were
   therefore mixing a real worker-lifetime problem with avoidable worker-key fragmentation.

2. The staged-execroot family failed for measured reasons, not just taste.
   On the representative `//sdk` benchmarks, stage-pool reuse effectively stayed at one use per
   slot, so the added reuse machinery delivered only weak overall improvement. The critical-path
   win was coming from early metadata availability, not from successful staged-root reuse. One
   benchmark pass recorded reuse staying at `1` across all 617 used slots, only about 7% overhead
   improvement versus the pre-stage-pool baseline, and an unchanged critical-path win from early
   `.rmeta`.

3. Bazel-side sandbox preparation may still dominate some runs, but that conclusion is not
   universal enough to carry as a standing benchmark narrative.
   One investigation captured Bazel-side prep at materially higher cost than worker-side staging,
   which is worth remembering as a clue. It was not stable enough across later runs to keep as a
   canonical result.

4. The alias-root strict-sandbox investigation did produce real evidence, but only sampled
   evidence.
   In the sampled strace runs that motivated the alias-root work, rustc did not read inputs after
   `.rmeta` emission for simple dependency, include-file, and proc-macro cases. That is useful
   context for why the idea was explored, but it is still not strong enough to override Bazel's
   documented contract or to serve as product-level proof.

5. Shutdown and teardown behavior was a real investigation thread, not just a generic testing gap.
   Earlier debugging found reproducible multiplex-worker teardown trouble around `bazel clean`,
   including `SIGTERM`-driven worker death and Bazel-side "Could not parse json work request
   correctly" storms. Even though that investigation did not fully settle the root cause, it is
   part of why worker shutdown and cancellation coverage remain explicit open items.

## Surviving Conclusions

The following conclusions still appear sound and should survive the cleanup:

1. Worker-key stabilization matters.
   Metadata and full actions only share in-process pipeline state if their worker-facing startup
   shape is intentionally normalized.

2. The staged-execroot / stage-pool family is not the preferred direction.
   It was useful as a diagnostic step, but too much of its complexity was compensating for
   worker-side restaging cost rather than removing the real source of overhead.

3. Broad analysis-time metadata input pruning is still too risky to treat as a cheap fix.
   Earlier iterations recorded real regressions here. Any future narrowing should be
   evidence-driven.

4. The hollow-rlib path remains strategically important.
   It is still the stable fallback when the single-rustc worker-managed handoff is not acceptable
   for a particular execution mode.

5. Benchmark data should live in benchmark docs and raw data, not in the plan.
   The plan files became stale in part because they mixed architecture decisions with quickly
   changing measurement narratives.

## Conclusions That Should No Longer Be Treated As Current

The cleanup is specifically intended to stop the following stale conclusions from reading as live
guidance:

1. "Resolve-through to the real execroot is the current sandboxed design."
   This is no longer true on this branch.

2. "The stage-pool or cross-process pool work is likely the path forward."
   It is not.

3. "Alias-root is implemented or is the active next step."
   It is not implemented on this branch.

4. "Strace-based evidence settled the background-rustc lifetime question for product purposes."
   It did not. At most it provided an empirical clue about sampled rustc behavior.

5. "Sandboxed worker pipelining is already the fully supported, final hermetic story."
   The current branch still has contract-sensitive behavior here and should be documented that way.

## Current Open Questions

The plan surface is now much smaller. The remaining questions are concrete:

1. What support level should sandboxed worker pipelining have right now?
   - keep it experimental and document the contract caveats clearly,
   - or split supported unsandboxed worker-pipelining from a stricter sandbox-safe mode.

2. If strict sandbox compliance is required, what replaces the current one-rustc / two-request
   handoff in sandboxed mode?
   Candidate directions are:
   - fall back to the hollow-rlib / two-invocation model for sandboxed and dynamic modes,
   - or develop a new strict-sandbox design without relying on post-response background work.

3. What cancellation and shutdown coverage is still missing?
   Current state:
   - metadata-phase pipelined cancellation exists,
   - full-phase pipelined cancellation still needs an atomic ownership-transfer fix so a full
     request never becomes cancel-acknowledgeable before a kill path is registered,
   - and non-pipelined worker requests still use acknowledge-only cancellation semantics and must
     remain documented as such.
   At minimum:
   - cancellation during metadata phase with a live background rustc,
   - cancellation during full phase across the metadata-to-full ownership handoff,
   - worker shutdown with active pipeline entries,
   - explicit `bazel clean` / teardown behavior for multiplex workers,
   - metadata-cache-hit / full-request-fallback paths,
   - dynamic execution with a real remote executor and explicit worker cancellation behavior.

4. Which public docs should be downgraded from recommendation to experiment?
   The settings docs and code comments should reflect the actual maturity of the sandboxed path.

## Cancellation Direction

Cancellation should be tightened using an atomic request-ownership design rather than treated as
fully settled.

Goal:

- every cancellable pipelined request ID must have a kill target installed before Bazel can receive
  `wasCancelled=true` for that request.

Design invariants:

- a pipelined request must not become cancel-acknowledgeable until its cancel target is registered,
- ownership transfer from metadata request ID to full request ID must be atomic,
- and after a cancel response is sent, the worker must have either:
  - killed the background rustc,
  - or proven that the request already completed and no further file mutation can occur.

Data model:

- keep pipeline state keyed by pipeline key,
- add a second index from active request ID to pipeline key / phase,
- and avoid a bare PID as the primary abstraction so cancellation remains tied to owned process
  state rather than to a reusable kernel identifier.

Flow:

1. Metadata phase:
   - when storing `BackgroundRustc`, register the metadata request ID in the request-ID index in
     the same critical section.
2. Full phase:
   - when the full request takes ownership of the background rustc, atomically rewrite the
     request-ID index from metadata request ID to full request ID before releasing the state lock.
3. Cancel:
   - resolve request ID through the request-ID index,
   - if it maps to a live pipelined entry, kill that entry before sending `wasCancelled=true`,
   - if no mapping exists, treat the request as already completed and ignore the cancel.
4. Cleanup:
   - remove the request-ID mapping when the full handler finishes or when cancellation reaps the
     child.

Why this shape:

- it closes the metadata-to-full handoff race,
- it avoids acknowledging cancellation for a full request that still has no kill path,
- and it keeps cancellation semantics tied to worker-owned process state instead of a raw PID.

## Implementation: Contract Documentation, Strace Test, and Cancellation Fix

This section contains concrete implementation tasks for the three workstreams described above.

### Task 1: Add design documentation to worker_pipeline.rs

Replace the module-level doc comment in `worker_pipeline.rs` (line 15) with a comprehensive doc
covering the single-rustc pipelining architecture, sandbox contract compliance rationale (Rule 1
and Rule 2), caveats (incremental, mmap, experimental status), and cancellation design. Include
links to the rustc dev guide, passes.rs, SourceMap, and Bazel worker docs.

### Task 2: Extend PipelineState with request_index and active_pids

Add two new fields to `PipelineState` in `worker_pipeline.rs`:

- `request_index: HashMap<i64, String>` — maps active request IDs to pipeline keys.
- `active_pids: HashMap<String, u32>` — maps pipeline keys to child PIDs, retained after the full
  handler takes ownership of `BackgroundRustc`.

Change `store()` to accept `request_id` and populate all three maps atomically. Add
`take_and_transfer(key, full_request_id)` that removes from `active`, rewrites `request_index`
(using `bg.metadata_request_id` for O(1) removal), and keeps `active_pids`. Add `pre_register()`,
`cleanup()`, and `kill_by_request_id()`.

`kill_by_request_id` checks `active` first (metadata phase: `child.kill()` + `child.wait()`), then
falls back to `active_pids` (full phase: `libc::kill(pid, SIGKILL)`). The PID fallback has a
theoretical PID-reuse race (documented with a SAFETY comment); the window is microseconds because
`cleanup()` removes the PID immediately after `child.wait()` returns. If this becomes a concern,
upgrade to a shared `Child` handle.

### Task 3: Update handle_pipelining_metadata

Pass `request.request_id` to the new `store()` signature. No other changes needed — the metadata
handler already stores `BackgroundRustc` in a single critical section.

### Task 4: Update handle_pipelining_full

Replace `take(&key)` with `take_and_transfer(&key, request.request_id)`. Add
`cleanup(&key, request.request_id)` to all exit paths in the `Some(bg)` arm (success, error) and
to the `None` arm (fallback one-shot compilation). The `None` arm cleanup is required because
`pre_register()` from Task 5 will have inserted a `request_index` entry even when no
`BackgroundRustc` is found.

### Task 5: Pre-register on main thread and early-cancel check in worker thread

In `worker.rs`, on the main thread:

1. After the cancel handler block and before `in_flight.insert()`, call
   `pipeline_state.pre_register(request.request_id, key)` for pipelined requests. This ensures the
   cancel target exists before the request becomes cancel-acknowledgeable.

In the worker thread:

2. After `detect_pipelining_mode()` and before `match pipelining`, check
   `claim_flag.load(Ordering::SeqCst)`. If the flag is already set (cancel won the race), call
   `cleanup()` and return early without starting rustc. This prevents wasted CPU and satisfies the
   invariant: "after cancel response, the worker must have killed the background rustc or proven
   that no further file mutation can occur."

### Task 6: Replace kill_pipelined_request

Replace the standalone `kill_pipelined_request` function with a thin wrapper that delegates to
`PipelineState::kill_by_request_id()`.

### Task 7: Unit tests for PipelineState cancel tracking

Add tests to `worker.rs`'s test module:

- `test_pipeline_state_store_and_kill_metadata_phase` — store + kill via metadata request ID
- `test_pipeline_state_take_and_transfer_then_kill_full_phase` — store + transfer + kill via full
  request ID (PID path)
- `test_pipeline_state_kill_nonexistent_request` — returns false
- `test_pipeline_state_pre_register` — pre-register + kill returns false (no process)
- `test_pipeline_state_cleanup_removes_all_entries` — cleanup after pre-register

### Task 8: Strace regression test

Add `test/unit/pipelined_compilation/strace_rustc_post_metadata_test.sh` as an `sh_test` tagged
`manual` and `local`, Linux-only. The test:

1. Compiles a small crate (with a dependency and `include_str!`) under
   `strace -f -e trace=openat,read,close`.
2. Finds the `.rmeta` write boundary in the strace log.
3. Asserts zero `openat()` calls referencing input files after the boundary.
4. Asserts all input FDs are closed before the boundary.
5. Prints the rustc version for traceability.

This test is not part of the normal CI suite. Run manually per rustc version:
```
bazel test //test/unit/pipelined_compilation:strace_rustc_post_metadata_test --test_output=streamed
```

### Task 9: Full test suite verification

Run `cargo test` in `util/process_wrapper/` and
`bazel test //test/unit/pipelined_compilation:pipelined_compilation_test_suite` to confirm no
regressions.

## Recommended Next Steps

1. Keep this file as the single current plan.
2. Do not recreate a parallel dated plan stack for the same topic unless the problem scope changes
   materially.
3. Move future benchmark updates into benchmark docs or raw-data summaries rather than back into
   the plan stack.
4. Implement the tasks in the "Implementation" section above.
5. Make one explicit product decision about sandboxed worker pipelining:
   - either narrow the supported scope and document the current limitations,
   - or start a fresh strict-sandbox design from the remaining open questions above.
6. Update code comments and user-facing settings docs so they do not overstate the sandboxed
   contract story.

## Benchmark And Artifact References

The following files remain useful and should not be collapsed into this plan:

- `thoughts/shared/bench_sdk_analysis.md`
- `thoughts/shared/benchmark_analysis.md`
- `thoughts/shared/bench_sdk_raw.csv`
- `thoughts/shared/bench_cargo_raw.csv`
- `thoughts/shared/benchmark_raw_data.csv`

Those files contain raw or summarized measurements. This file is only for architecture and status.
