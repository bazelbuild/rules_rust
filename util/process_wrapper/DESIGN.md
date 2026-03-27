# Process Wrapper Worker Design

## Overview

`process_wrapper` has two execution modes:

- Standalone mode executes one subprocess and forwards output.
- Persistent-worker mode speaks Bazel's JSON worker protocol and can keep
  pipelined Rust compilations alive across two worker requests.

The worker entrypoint is `worker::worker_main()`. It:

- reads one JSON `WorkRequest` per line from stdin
- classifies the request as non-pipelined, metadata, or full
- registers the request in `PipelineState` before it becomes cancelable
- dispatches multiplex requests onto background threads
- serializes `WorkResponse` writes to stdout

## Request Kinds

Rust pipelining uses two request kinds keyed by `--pipelining-key=<key>`:

- Metadata request: starts rustc, waits until `.rmeta` is emitted, returns
  success early, and leaves the child running in the background.
- Full request: either takes ownership of the background rustc and waits for
  completion, or claims the key for a one-shot fallback compile.

Request classification must use the same rules in the main thread and the worker
thread. Relative `@paramfile` paths are resolved against the request's effective
execroot:

- `sandboxDir` when Bazel multiplex sandboxing is active
- the worker's current directory otherwise

This avoids the earlier split where pre-registration and execution could
disagree about whether a request was pipelined.

## Pipeline State Machine

`PipelineState` tracks three data structures:

- `entries`: pipeline key to active phase
- `request_index`: request id to pipeline key
- `claim_flags`: request id to atomic "response already claimed" flag

The important phases are:

- `PreRegistered`: metadata request is known but rustc has not been stored yet
- `MetadataRunning`: background rustc is alive and owned by the metadata path
- `FullWaiting`: full request has taken the child and is waiting for exit
- `FallbackRunning`: full request claimed the key for standalone fallback, so
  late metadata stores must be rejected

The critical invariant is that ownership transfers happen under the
`PipelineState` mutex. Two cases matter:

1. Metadata to full handoff:
   `MetadataRunning -> FullWaiting`
2. Missing background child:
   `PreRegistered|Absent -> FallbackRunning`

That second transition prevents the old race where a full request started a
fallback compile and a late metadata thread stored a background rustc at the
same time.

## Retry and Cancellation

Metadata retries use per-request output directories under:

`_pw_state/pipeline/<key>/outputs-<request_id>/`

This avoids deleting a shared `outputs/` directory before ownership of the key
has changed.

Cancellation is best-effort:

- non-pipelined requests only suppress duplicate responses
- pipelined requests can kill the owned background child or signal the PID held
  by `FullWaiting`

`claim_flags` are the response-level guard. `request_index` is the lookup table
that lets cancellation find the current pipeline entry.

## Sandbox Contract

When Bazel provides `sandboxDir`, the worker runs rustc with that directory as
its current working directory. Relative reads then stay rooted inside the
sandbox. Outputs that must survive across the metadata/full split are redirected
into `_pw_state/pipeline/<key>/...` and copied back into the sandbox before the
worker responds.

The worker also makes prior outputs writable before each request because Bazel
and the disk cache can leave action outputs read-only.

This satisfies the straightforward part of the multiplex-sandbox contract:
request-time reads and declared output writes stay rooted under `sandboxDir`.
The harder part is response lifetime: the metadata response returns before the
background rustc has finished codegen. The current safety argument is that rustc
has already consumed its inputs by `.rmeta` emission and that later codegen
writes go only into worker-owned `_pw_state`, but that depends on rustc
implementation details rather than on a Bazel-guaranteed contract. For that
reason, sandboxed worker pipelining should still be treated as
contract-sensitive, and the hollow-rlib path remains the compatibility fallback.

## Standalone Full-Action Optimization

Outside worker mode, a `--pipelining-full` action may be redundant. If the
metadata action already produced the final `.rlib` as a side effect and that
file still exists, standalone mode skips the second rustc invocation and only
performs the normal post-success actions (`touch_file`, `copy_output`).

If the `.rlib` is missing, the wrapper falls back to a normal standalone rustc
run and prints guidance about disabling worker pipelining when the execution
strategy cannot preserve the side effect.

## Determinism Contract

Bazel persistent workers are expected to produce the same outputs as standalone
execution. For Rust pipelining this becomes a hard requirement under dynamic
execution: a local worker leg and a remote standalone leg may race, so the
resulting `.rlib` and `.rmeta` artifacts must be byte-for-byte identical.

There are two relevant worker paths:

- Non-pipelined requests re-exec `process_wrapper` via `run_request()`, so they
  share the standalone path by construction.
- Pipelined requests diverge: `handle_pipelining_metadata()` spawns rustc
  directly, rewrites output locations into `_pw_state`, and
  `handle_pipelining_full()` later joins that background compile and
  materializes artifacts.

That second path is where determinism matters most. The same rustc flags used by
the worker must be preserved in standalone comparisons, including
`--error-format=json` and `--json=artifacts`, because those flags affect the
metadata rustc emits and therefore the crate hash embedded in downstream-facing
artifacts.

## Determinism Test Strategy

`process_wrapper_test` uses the real toolchain rustc from Bazel runfiles
(`RUSTC_RLOCATIONPATH`) together with `current_rust_stdlib_files`, so the test
compares the worker against the production compiler instead of a fake binary.

The test harness relies on a few implementation hooks:

- `run_standalone(&Options)` factors the standalone execution path out of
  `main()` so tests can invoke it without exiting the process.
- `worker::{pipeline, protocol, sandbox, types}` are `pub(crate)` so unit tests
  can drive the pipelined handlers directly.
- `RUST_TEST_THREADS=1` is set for `process_wrapper_test` because the pipelined
  determinism test temporarily changes the process current working directory.

The core regression test is `test_pipelined_matches_standalone()` in
`main.rs`. It:

1. compiles a trivial crate twice with standalone rustc to prove the baseline is
   itself deterministic for the chosen flags
2. runs the same crate through `handle_pipelining_metadata()` and
   `handle_pipelining_full()`
3. compares both `.rlib` and `.rmeta` bytes between standalone and worker

The `.rmeta` comparison is as important as the `.rlib` comparison because
downstream crates compile against metadata first; a metadata mismatch can expose
different SVH or type information even if the final archive happens to link.

Current coverage splits across layers:

- no pipelining: asserted as the baseline precondition inside the determinism
  test
- hollow-rlib pipelining: covered by analysis tests that verify consistent flag
  selection
- worker pipelining: covered by the byte-for-byte artifact comparison described
  above

## Historical Notes

The following conclusions came from the older `thoughts/` design notes and are
worth keeping even though the plan file itself is gone:

- Stable worker keys were a prerequisite, not a detail. Metadata and full
  requests only share one worker process and one in-process pipeline state if
  request-specific process-wrapper flags are moved out of startup args and into
  per-request files.
- The staged-execroot and stage-pool family was explored and rejected. Measured
  reuse stayed too low to justify the extra machinery; the meaningful win came
  from early `.rmeta` availability, not from worker-side restaging.
- Cross-process shared stage pools were rejected for the same reason: they add
  leasing and invalidation complexity without addressing the main bottleneck.
- "Resolve through the real execroot" is not the current sandbox design. It did
  reduce worker-side staging cost, but it violates the documented `sandboxDir`
  contract and should not be treated as the supported direction.
- The alias-root strict-sandbox idea was explored but not landed. It had useful
  investigative value, especially around post-`.rmeta` rustc behavior, but it
  would require a larger rewrite and stronger validation than the current
  branch justified.
- Broad metadata-input pruning was investigated and rejected after real
  `E0463` missing-crate regressions. Any future pruning has to be trace-driven
  and validated against full dependency graphs.
- Teardown and shutdown behavior deserves explicit skepticism. Earlier
  investigations saw multiplex-worker cleanup trouble around `bazel clean`, so
  worker shutdown and cancellation behavior should continue to be validated as a
  first-class part of the design.

To avoid stale guidance, the following should be treated as explicitly not
current on this branch:

- staged execroot reuse as the active architecture
- cross-process stage pools as the preferred next step
- resolve-through reads outside `sandboxDir` as the supported sandbox story
- alias-root (`__rr`) as an implemented or imminent design

## Open Questions

The implementation is substantially more complete than the old plan, but a few
design questions remain open:

- What support level should sandboxed worker pipelining have in public docs:
  experimental with clear caveats, or supported only under a narrower set of
  execution modes?
- If strict post-response sandbox compliance is required, should sandboxed and
  dynamic modes fall back to the hollow-rlib two-invocation path, or should a
  different strict-sandbox design replace the current one-rustc handoff?
- How much teardown and cancellation validation is enough to treat the
  background-rustc lifetime as operationally solid under `bazel clean`,
  cancellation races, and dynamic execution?
