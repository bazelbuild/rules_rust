# Real Execroot Plan For Multiplex Sandboxing

## Context

The current sandboxed multiplex-worker implementation stages a fresh worker-owned execroot under
`_pw_state/pipeline/<key>/execroot` for each pipelined metadata request. This preserves correctness
when the request sandbox is cleaned up before the background rustc completes, but it adds
substantial per-request filesystem overhead.

The benchmark summary in `thoughts/shared/bench_sdk_analysis.md` shows that:

- sandboxed `worker-pipe` loses most of the wall-time benefit from pipelining,
- the overhead is dominated by input staging into `_pw_state/pipeline/<key>/execroot`,
- small link-oriented optimizations are not enough to recover the regression.

The earlier shared-execroot proposal tried to amortize staging with a worker-level cache and a thin
overlay. After reviewing the current implementation and Bazel's worker sandbox model, that appears
to optimize the wrong layer. The worker already runs from the real execroot, and sandbox inputs are
symlinks back into that execroot. The simpler path is to stop rebuilding a synthetic execroot for
background rustc and instead run it from the real execroot directly.

## Goal

Eliminate per-request execroot staging for sandboxed multiplex worker pipelining by running the
background rustc from the real worker execroot, while keeping outputs in worker-owned persistent
directories until they are materialized back into the sandbox.

## Non-Goals

- Changing the unsandboxed worker-pipelining path.
- Changing non-worker Rust actions.
- Building a shared input cache, digest store, or invalidation layer.
- Enabling the new design by default before correctness and performance are proven.
- Solving remote execution or dynamic execution generally.

## Current Design Summary

Today the worker does the following for each pipelined metadata request:

1. Creates `_pw_state/pipeline/<key>/execroot`.
2. Copies, hardlinks, or preserves symlinks for every entry in `WorkRequest.inputs`.
3. Seeds sandbox symlinks and worker-level entries into the staged execroot.
4. Rewrites rustc paths so the background rustc runs from that staged execroot.
5. Copies or links outputs back into the request sandbox when metadata/full actions complete.

This is correct but too expensive when repeated for ~1000+ inputs across ~1000+ worker requests.

## Proposed Design

### High-Level Structure

Move from:

```text
_pw_state/
  pipeline/<key>/
    execroot/
    outputs/
```

To:

```text
_pw_state/
  pipeline/<key>/
    outputs/
```

### Core Idea

- Use the real worker execroot as the rustc current working directory.
- Keep `--out-dir` redirected to `_pw_state/pipeline/<key>/outputs/`.
- Keep `--emit=` path rewriting only where needed so metadata/full outputs land in the persistent
  outputs directory instead of the Bazel-managed output tree.
- Continue materializing `.rmeta`, `.rlib`, `.d`, and similar outputs back into the request
  sandbox before returning the worker response.
- Remove staged-execroot creation entirely for sandboxed pipelined metadata actions.

This changes the per-request setup cost from O(N inputs) filesystem work to O(1) setup around the
persistent outputs directory.

## Why This Should Work

- Bazel's worker sandbox contains symlinks back into the real execroot rather than independent
  copies of the inputs.
- The real execroot persists for the duration of the build; the request sandbox is what gets
  cleaned up between actions.
- Relative rustc inputs such as `@paramfile`, `--extern`, and `-L dependency=...` are already
  expressed relative to the execroot. With `CWD = real_execroot`, they should resolve directly.
- Background rustc writes can stay isolated by continuing to redirect `--out-dir` to a unique
  worker-owned path under `_pw_state/pipeline/<key>/outputs/`.
- The existing output-copying step is already small compared with input staging and can remain in
  place.

## Implementation Phases

### Phase 1: Instrument The Existing Path

Add timing and count instrumentation around:

- staged execroot creation,
- input staging,
- sandbox/worker-entry seeding,
- metadata output materialization,
- full-output materialization.

Capture at least:

- total files and directories staged,
- elapsed milliseconds per phase,
- whether the request was pipelined metadata, pipelined full, or fallback.

Success criteria:

- Per-phase timings are visible in worker logs or a structured debug file.
- We can quantify how much of sandbox overhead is input staging vs output materialization.

### Phase 2: Introduce Real-Execroot Metadata Execution

Refactor the metadata path so sandboxed pipelined rustc runs from the real worker execroot instead
of `_pw_state/pipeline/<key>/execroot`.

Requirements:

- Determine the worker execroot once from the worker process current directory.
- Create only `_pw_state/pipeline/<key>/outputs/` for each metadata request.
- Preserve the existing persistent pipeline bookkeeping and background process storage.

Success criteria:

- No request inputs are staged into a synthetic execroot.
- Metadata rustc starts successfully with `current_dir(real_execroot)`.

### Phase 3: Rebase Path Resolution

Update path handling that currently assumes a staged execroot.

This includes:

- `@paramfile` expansion,
- `--arg-file` resolution,
- `--env-file` resolution,
- `${pwd}` substitution values used for process-wrapper substitutions,
- `--emit=` rewriting,
- any helper that currently prefixes relative paths with the staged execroot.

Requirements:

- Resolve rustc inputs against the real execroot.
- Keep `--output-file` behavior for sandboxed requests pointed at the sandbox, since Bazel expects
  diagnostics there.
- Preserve the current `--out-dir` rewrite into the persistent pipeline outputs directory.

Success criteria:

- rustc sees the same effective inputs as the non-staged worker path.
- No staged-execroot-specific path rewrites remain in the metadata path.

### Phase 4: Remove Staged Execroot Machinery

Delete code that only exists to construct and maintain the synthetic execroot for pipelined
metadata actions.

Expected removals:

- `stage_request_inputs()`,
- `seed_execroot_with_sandbox_symlinks()`,
- `seed_execroot_with_worker_entries()`,
- staged-execroot creation in `create_staged_pipeline()`,
- staged-execroot-specific path rewriting helpers.

Success criteria:

- The sandboxed pipelining path no longer performs O(N) input staging work.
- The codepath is smaller and easier to reason about than the current staged design.

### Phase 5: Verify Cache And Symlink Edge Cases

Validate the path-layout assumptions that were previously papered over by staging.

Specific checks:

- external-repo cache loopback symlinks still resolve correctly with `CWD = real_execroot`,
- cache seeding helpers are either still needed and correct or can be removed,
- request sandbox cleanup no longer affects background rustc reads,
- dep-info output paths remain acceptable to Bazel when emitted from the real execroot.

Success criteria:

- No regressions for external repository layouts or cache loopback behavior.
- The remaining cache/symlink helpers have a clear justification.

### Phase 6: Guard Behind A Flag

Introduce a new opt-in flag for the real-execroot design.

Requirements:

- existing sandboxed worker behavior remains available,
- benchmarks can compare old vs new behavior directly,
- failures can be bisected by turning the feature off.

Success criteria:

- All new behavior is isolated behind a dedicated setting.

### Phase 7: Verification

Add tests for:

- sandboxed pipelined metadata requests succeeding without staged input materialization,
- param-file, arg-file, and env-file resolution from the real execroot,
- diagnostics file placement for sandboxed requests,
- external-repo/cache-loopback behavior,
- output copying back into the sandbox for metadata and full actions,
- fallback behavior when the background rustc is missing.

Required commands:

- `bazel test //util/process_wrapper:process_wrapper_test`
- existing pipelining unit tests

Success criteria:

- correctness is established before performance tuning.

### Phase 8: Benchmarking

Benchmark in two tiers:

1. focused process-wrapper or small crate-graph workload,
2. `reactor-repo-2 //sdk` with sandboxed worker pipelining.

Primary metrics:

- wall time,
- critical path,
- wall minus critical path overhead,
- per-phase staging/output timings from Phase 1 instrumentation.

Success criteria:

- sandboxed `worker-pipe` overhead drops materially relative to the current staged-execroot design,
- improvement is repeatable across stable iterations, not just iteration-1 noise.

## Key Risks

### Hidden Path Assumptions

Some process-wrapper helpers currently bake in the staged-execroot model. Those assumptions must be
removed carefully so param files, env files, diagnostics, and emitted outputs continue to land in
the correct places.

### Cache Loopback Behavior

External repo cache loopbacks are subtle today. The real-execroot design may make some helpers
unnecessary, but we should prove that with tests rather than assume it.

### Bazel Integration Mismatches

Even if rustc itself is happy with `CWD = real_execroot`, Bazel may still expect specific output
locations for diagnostics and declared artifacts. Those expectations must remain unchanged.
