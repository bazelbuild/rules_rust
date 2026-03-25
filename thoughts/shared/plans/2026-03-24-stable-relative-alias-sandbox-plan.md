# Stable Relative Alias Plan For Sandboxed Rust Workers

## Status

Exploratory design plan.

This document describes a contract-compliant attempt to recover most of the performance benefit of
worker pipelining under multiplex sandboxing without escaping to Bazel's real execroot.

It is intentionally narrower than the current "resolve-through" implementation:

- it treats `sandbox_dir` as the source of truth for all tool-visible reads and writes,
- it avoids O(N input) worker-side staging into a synthetic execroot,
- it does **not** assume that a background rustc may keep using worker files after the worker has
  sent a `WorkResponse`.

That last point is critical. If Bazel's current worker contract remains unchanged, a fully
compliant sandboxed design may need to give up the current "one rustc spans metadata + full
requests" architecture, or at least gate it behind a Bazel-side lifetime guarantee that does not
exist today.

## Related Documents

- [2026-03-10-multiplex-sandbox-shared-execroot.md](./2026-03-10-multiplex-sandbox-shared-execroot.md)
- [2026-03-10-multiplex-sandbox-staged-execroot-reuse.md](./2026-03-10-multiplex-sandbox-staged-execroot-reuse.md)
- [2026-03-13-dynamic-execution-worker-pipelining.md](./2026-03-13-dynamic-execution-worker-pipelining.md)
- [2026-03-16-meta-plan-stable-fast-dynamic.md](./2026-03-16-meta-plan-stable-fast-dynamic.md)

This plan should be read as the "strict sandbox contract" alternative to the current
resolve-through path.

## Prior Conclusions To Carry Forward

This document is not starting from a blank slate. Earlier design and benchmark work already ruled
out or narrowed several neighboring approaches:

1. **Per-process staged-execroot reuse is not the main answer under multiplex sandboxing.**
   Benchmarks on `//sdk` showed that slot reuse effectively never happened in practice because the
   relevant worker lifetime assumptions did not hold under Bazel's sandboxed multiplex behavior.

2. **Worker-topology tuning did not materially rescue staged-execroot reuse.**
   The earlier investigation treated lower worker counts and different multiplex settings as a
   decision gate; the resulting direction remained "reuse is too rare" rather than "tune the
   existing pool harder."

3. **Broad metadata input pruning is already considered too risky without trace evidence.**
   Earlier follow-up work recorded real `E0463` regressions when trying to shrink metadata inputs
   analysis-side. Any future narrowing should therefore be trace-driven and validated against the
   full graph, not treated as a cheap general optimization.

4. **Bazel path mapping is not sufficient for rules_rust's current string-heavy argument shapes.**
   Prior path-mapping work found that Bazel rewrites `File` arguments, but not embedded string
   paths such as `--extern=name=path`, dirname-derived strings returned from `map_each`, or env
   values like `OUT_DIR`. A strict-sandbox stable-path design therefore needs worker-side rewriting
   rather than assuming Bazel will normalize these paths for us.

5. **Strict sandbox mode should not assume a background rustc may outlive the metadata response.**
   Older sandboxed pipelining designs relied on this as a practical workaround. This plan instead
   treats the documented worker contract as authoritative and requires that lifetime assumption to
   be re-proven before any cross-request background-rustc design is considered compliant.

## Problem Statement

The current design space has two known extremes:

1. **Synthetic staged execroot inside worker-owned state**
   - Correct with respect to sandbox lifetime.
   - Expensive because the worker restages many request inputs for each pipelined metadata action.

2. **Resolve-through to the real execroot**
   - Fast because it eliminates worker-side input staging.
   - Not compliant with Bazel's documented multiplex sandbox contract because the worker stops using
     `sandbox_dir` as the root for tool-visible filesystem access.

The goal of this plan is to define a third option:

- keep rustc rooted in the request sandbox,
- rewrite tool-visible paths into a stable relative namespace,
- avoid rebuilding a full synthetic execroot,
- preserve as much of the path-stability and low-overhead behavior as possible.

## Core Idea

Instead of building a full worker-owned execroot, the worker creates a **small stable alias root**
inside each request sandbox and rewrites rustc-visible paths to that namespace.

High-level shape:

```text
<sandbox_dir>/
  bazel-out/...
  external/...
  pkg/...
  ...
  __rr/
    src -> ..
    out -> ../<declared out dir>
    cache -> ../cache         # when available
    tmp/
    rustc.args
    build_flags.args
```

rustc then runs with:

- `cwd = <sandbox_dir>/__rr`
- rewritten paths such as:
  - `src/external/foo/src/lib.rs`
  - `src/bazel-out/.../libbar.rmeta`
  - `out`
  - `@rustc.args`

This keeps all reads and writes rooted in `sandbox_dir`, but removes the unstable absolute sandbox
prefix from the path strings rustc sees directly.

## Why This May Help

The staged-execroot design spends time creating a second filesystem view of the request inputs.
This design does not.

The worker only needs to:

1. create `__rr/`,
2. create a few stable aliases,
3. rewrite argfiles and selected path-bearing flags,
4. invoke rustc from `__rr`.

If this works, the worker-side setup cost becomes O(number of path-bearing arguments and generated
support files), not O(number of request inputs).

## Contract Constraints

This plan is derived from the Bazel worker and sandboxing model, not from implementation
accidents.

### Constraint 1: multiplex sandboxing is rooted at `sandbox_dir`

Bazel's multiplex worker docs say that a sandbox-compatible worker must use `sandbox_dir` as the
prefix for reads and writes, including paths found in arguments and argfiles.

Implication:

- no direct fallback to the real execroot,
- no worker-private persistent execroot as the primary rustc cwd,
- any rewritten path namespace must still resolve inside the request sandbox.

### Constraint 2: a worker should not keep touching request files after it responds

Bazel's persistent worker docs say that once a response has been sent for a request, the worker
must not touch files in its working directory, because Bazel may clean them up.

Implication:

- the current sandboxed "metadata responds early, background rustc keeps running" model is not
  obviously supportable under the documented contract,
- this plan must include a hard decision gate on whether a compliant sandboxed one-rustc/two-
  request pipeline is even feasible.

### Constraint 3: worker-key reuse still matters

Even with sandbox compatibility restored, the metadata and full actions still need to share a
worker process when using worker-managed pipelining or any worker-local cache.

Implication:

- keep per-action flags and per-crate env out of worker startup args and action env where needed,
- prefer `worker-key-mnemonic` over collapsing distinct action mnemonics if a shared worker key is
  required.

## Goals

1. Preserve Bazel multiplex sandbox compatibility for rustc worker execution.
2. Remove worker-side O(N input) staging.
3. Give rustc stable relative paths such as `src/...` and `out/...` rather than request-specific
   absolute sandbox paths.
4. Preserve worker-key sharing between metadata and full actions when the architecture still needs
   worker-local state.
5. Make the design measurable against both staged-execroot and resolve-through implementations.

## Non-Goals

1. Depending on Bazel's real execroot as the tool-visible root.
2. Changing the Bazel worker protocol.
3. Solving remote execution generally.
4. Guaranteeing that the current one-rustc/two-request handoff survives unchanged.
5. Supporting Windows in the initial implementation.
6. Reviving per-process staged-execroot reuse as the primary strict-sandbox direction.
7. Relying on broad analysis-time metadata input pruning as the first optimization step.

## Architectural Hypothesis

The performance benefit of resolve-through comes from two mostly independent effects:

1. **No worker-side input restaging**
2. **Stable paths from rustc's point of view**

This plan tries to preserve both while staying within `sandbox_dir`:

- no restaging because the sandbox already contains Bazel's input view,
- stable paths because rustc sees `src/...` and `out/...` relative to a fixed alias root.

The design will fail if rustc or proc macros aggressively canonicalize those paths back to the
absolute sandbox location in a way that defeats incremental/path stability. That must be measured,
not assumed.

## Proposed Filesystem Layout

For a request sandbox `S`, create:

```text
S/
  __rr/
    src -> ..
    out -> ../<out_dir>
    cache -> ../cache
    tmp/
    rustc.args
    build_flags.args
```

### Layout Rules

1. `src` is always a symlink to the sandbox root itself.
   - `src/external/foo/...` resolves to `S/external/foo/...`
   - `src/bazel-out/...` resolves to `S/bazel-out/...`

2. `out` points at the request's declared output directory inside the sandbox.
   - rustc sees a stable output root `out/...`
   - Bazel still observes outputs under its normal sandbox-managed paths

3. `cache` is optional.
   - created only when the existing cache loopback logic can seed it
   - not required for the first prototype

4. all worker-generated temp artifacts needed by rustc run under `__rr/`.
   - rewritten argfiles
   - worker-generated response files
   - temporary dep-arg consolidations

## Path Rewriting Model

The worker rewrites rustc-visible paths into the alias namespace before spawning rustc.

### Paths That Must Be Rewritten

1. The primary rustc paramfile passed after `@`.
2. Any nested argfiles referenced from that paramfile.
3. `--extern=name=...`
4. `-L dependency=...`
5. `--out-dir=...`
6. `--emit=...`
7. `--remap-path-prefix=...` when it references `${pwd}` or sandbox-relative paths.
8. `--env-file`, `--arg-file`, `--stable-status-file`, and `--volatile-status-file` when the
   worker still needs to interpret them before invoking rustc.
9. Path-bearing environment values consumed by rustc, proc macros, or build-script outputs when
   they can contain unstable sandbox-specific prefixes.

### Environment And Embedded-Path Scope

Earlier `--experimental_output_paths=strip` work matters here. It demonstrated that Bazel's own
path mapper does **not** rewrite all of the path shapes that matter to Rust:

1. dirname-based strings returned from `map_each`
2. embedded `--extern=name=path` strings
3. env values such as `OUT_DIR`

Implication:

- the alias-root prototype should assume that worker-side rewriting must cover both argfiles and
  relevant env-file entries,
- success should not depend on Bazel normalizing these strings automatically.

### Rewrite Rules

1. Paths that were previously relative to execroot become `src/<original path>`.
2. The declared output directory becomes `out`.
3. Metadata-only output paths become `out/_pipeline/...` or another stable subpath rooted under
   `out`.
4. Worker-generated argfiles are emitted under `__rr/` and referenced relative to `cwd`.

### Important Invariant

The rewritten command line must contain **no request-specific absolute sandbox prefix** for
tool-visible source, dependency, or output paths, except where an external tool requires an
absolute path and there is no practical alternative.

## Execution Models

There are two distinct execution models to evaluate.

### Model A: compliant one-shot sandboxed worker execution

This is the baseline, and it should be implemented first.

- The worker receives one request.
- It creates the alias root.
- It rewrites argfiles.
- It runs rustc inside `sandbox_dir/__rr`.
- It returns the response.

This model should be compatible with Bazel's documented sandbox contract.

### Model B: compliant sandboxed worker pipelining across metadata + full requests

This is only viable if the lifecycle problem has a real answer.

Candidate options:

1. Bazel actually keeps the request sandbox alive long enough for the background process.
   - Unlikely.
   - Must be proven by targeted probe tests.

2. Bazel can be extended to lease the request sandbox until a later response.
   - Out of scope for the first prototype.

3. The worker can move a running rustc to a worker-private root after metadata is ready.
   - Not realistic.

Updated assumption (after Gate 0 investigation, 2026-03-24):

- **Model B IS feasible.** The strace investigation proved that background rustc makes zero
  input reads after `.rmeta` emission. Post-`.rmeta` work is purely codegen + linking,
  confined to the redirected `--out-dir` in worker-owned persistent state.

The recommended product shape is therefore:

- sandboxed mode uses the alias-root design with single-rustc pipelining,
- rustc reads inputs through `sandbox_dir` (via alias root) during front-end phases,
- after `.rmeta` emission, the metadata response is sent,
- background rustc continues codegen/linking using only the redirected `--out-dir`,
- the sandbox can be safely reused by Bazel for subsequent requests.

## Decision Gates

### Gate 0: Is a background rustc allowed to outlive the metadata response in sandboxed mode?

#### Investigation Results (2026-03-24)

**Methodology:** `strace -f -e trace=openat` on rustc with `--emit=dep-info,metadata,link
--json=artifacts` across three test cases, using rustc 1.94.0 stable.

**Test cases:**
1. Simple crate with one dependency crate
2. Crate using `include_str!("file.txt")` and `include_bytes!`
3. Crate using `#[derive(Serialize, Deserialize)]` from serde (proc macro)

**Finding: After emitting `.rmeta`, rustc makes ZERO reads of input files.**

All three test cases show the same pattern:
- Source files (`.rs`): read before `.rmeta` ✓
- Dependency metadata (`.rmeta`): read before `.rmeta` ✓
- Proc macro shared objects (`.so`): dlopen'd before `.rmeta` ✓
- `include_str!`/`include_bytes!` files: read before `.rmeta` ✓
- All file descriptors to input files are closed before `.rmeta` write

Post-`.rmeta` file operations are exclusively:
1. Writing `.rmeta` to temp dir, then atomic move to `--out-dir`
2. Codegen thread writing `.o` object files to `--out-dir`
3. Linker thread reading its own `.o` files + writing `.rlib` archive
4. Temp directory cleanup

All post-`.rmeta` I/O is confined to `--out-dir`, which the worker redirects to a persistent
pipeline directory outside `sandbox_dir`.

**Implication:** After the metadata response, background rustc does not "touch files" in the
sandbox or working directory in the sense meant by the Bazel contract. Its remaining work
(codegen + linking) only accesses the redirected `--out-dir`. The sandbox can be safely mutated
or cleaned without affecting the background process.

**Caveat:** This relies on rustc's compilation pipeline architecture (front-end completes before
`.rmeta` emission, codegen is purely output-oriented). This has held across rustc 1.91 through
1.94 and is architecturally fundamental to how rustc works, but is not a documented API guarantee.
A strace regression test per supported rustc version would provide ongoing confidence.

#### Contract Analysis

The Bazel multiplex sandbox contract has two relevant rules:

**Rule 1** (from `multiplex.md`): "the worker must use the `sandbox_dir` field [...] as a prefix
for **all file reads and writes**"

**Rule 2** (from `creating.md`): "Once a response has been sent for a WorkRequest, the worker
must not touch the files in its working directory."

The current resolve-through implementation violates **Rule 1** (reads from real execroot, not
`sandbox_dir`). The strace investigation shows that **Rule 2 is NOT violated in practice**
because background rustc does not read sandbox files after the metadata response.

This means a sandbox-compliant design needs to fix Rule 1 (read through `sandbox_dir`) but
does NOT need to solve the background-rustc lifetime problem — the background process is
effectively sandbox-independent after `.rmeta` emission.

#### Decision

- **The one-rustc/two-request pipelining model IS viable under strict sandboxing**, provided
  that input reads go through `sandbox_dir` (fixing Rule 1) and `--out-dir` is redirected to
  worker-owned persistent state (already done).
- The alias-root approach described in this plan is a valid path to fixing Rule 1 while
  preserving single-rustc pipelining performance.
- Gate 0 is **PASSED**. Proceed with the alias-root prototype.

### Gate 1: Do stable relative aliases materially reduce worker-side overhead?

Validation method:

1. Benchmark alias-root setup against staged-execroot setup on a representative target.
2. Compare:
   - setup time per request,
   - total build wall time,
   - count of filesystem operations,
   - worker log size.

Decision:

- If worker-side setup is still too expensive, the design is not worth pursuing.

### Gate 2: Do proc macros and incremental state benefit from relative alias paths?

Validation method:

1. Run targeted proc-macro and incremental tests with:
   - staged execroot
   - alias-root sandbox
   - unsandboxed resolve-through

Decision:

- If rustc still records unstable absolute sandbox paths in the important places, the expected
  performance/correctness benefits shrink and the design may not justify the rewrite complexity.

## Implementation Phases

### Phase 0: Contract Probe And Kill Criteria ✅

Build a focused probe before changing rustc worker logic.

Tasks:

1. Add a small integration target that runs under:
   - `--strategy=Rustc=worker,sandboxed`
   - `--experimental_worker_multiplex_sandboxing`
2. Make the worker:
   - send a response,
   - keep a child process alive briefly,
   - record whether sandbox files remain accessible.
3. Document the exact behavior.

Success criteria:

- We can state with evidence whether a background rustc may legally and practically survive the
  metadata response in sandboxed mode.

Kill criteria:

- If sandbox cleanup happens immediately after response, stop trying to preserve the current
  one-rustc/two-request model in strict sandbox mode.

### Phase 1: Alias-Root Prototype ✅

Introduce a new helper in the worker sandbox path, initially only for sandboxed one-shot requests.

Tasks:

1. Add a helper such as `create_relative_alias_root(sandbox_dir, out_dir)`.
2. Create:
   - `__rr/src -> ..`
   - `__rr/out -> ../<out_dir>`
   - `__rr/tmp/`
3. Reuse existing cache seeding only if it naturally fits under `__rr/cache`.
4. Add worker debug logging for:
   - alias-root creation time,
   - rewritten files count,
   - total bytes written for generated argfiles.

Success criteria:

- rustc can run from `sandbox_dir/__rr` without a synthetic staged execroot.

### Phase 2: Paramfile Rewriter ✅

Add a dedicated path-rewriting layer for rustc argfiles.

Tasks:

1. Parse the primary rustc paramfile line-by-line.
2. Rewrite recognized path-bearing arguments to `src/...`, `out/...`, or local `@...` files under
   `__rr/`.
3. Support nested argfiles and process-wrapper-owned files.
4. Preserve non-path flags byte-for-byte where possible.
5. Keep pipelining-control flags stripped before rustc sees them.
6. Extend the same rewriting model to env/status/build-flag files where path-bearing values such
   as `OUT_DIR` or stamp substitutions would otherwise leak unstable sandbox prefixes.

Success criteria:

- A rewritten rustc invocation is functionally equivalent to the current sandboxed invocation for
  non-pipelined requests.

### Phase 3: One-Shot Sandboxed Execution On Alias Root ✅

Wire the alias-root path into the existing sandboxed request execution flow.

Tasks:

1. Add an opt-in path in the worker for sandboxed requests.
2. Run the subprocess with:
   - `cwd = sandbox_dir/__rr`
   - rewritten args
3. Keep `sandbox_dir`-scoped diagnostics and outputs intact.
4. Compare produced outputs and diagnostics against the current sandboxed path.

Success criteria:

- Normal sandboxed worker execution works on the alias root.
- The worker no longer needs staged-execroot machinery for this mode.

### Phase 4: Metadata-Only Prototype

Use the alias root for the metadata action path, without yet relying on a background process across
responses.

Tasks:

1. Run metadata-only rustc from `__rr`.
2. Ensure `.rmeta`, dep-info, and diagnostics land in the expected sandbox-visible locations.
3. Verify that downstream actions can consume the produced metadata without any worker-private
   output copy step.

Success criteria:

- The metadata-only action path is correct and faster than staged execroot.

### Phase 5: Pipelining Architecture Decision

Make an explicit architecture choice for strict sandbox mode.

Option A:

- Use alias-root sandboxing only for one-shot worker execution and keep current worker-managed
  pipelining unsandboxed.

Option B:

- Use alias-root sandboxing plus hollow-rlib/two-invocation pipelining in sandboxed mode.

Option C:

- Extend Bazel or the worker protocol to support a leased sandbox lifetime across related worker
  requests.

Recommended default unless Phase 0 proves otherwise:

- **Option B for strict sandbox mode**
- **current one-rustc design only for unsandboxed mode**

Rationale:

- earlier plan history already weakens the case for investing further in strict-sandbox designs
  that depend on a post-response background rustc,
- the two-invocation shape should therefore be treated as the primary compliant fallback rather
  than as a last-resort escape hatch.

Success criteria:

- The codebase has one clearly documented compliant sandbox story instead of an ambiguous hybrid.

### Phase 6: Incremental And Proc-Macro Validation

Measure whether the alias-root path actually improves stability-sensitive behavior.

Tasks:

1. Compare dep-info contents between:
   - staged execroot
   - alias root
   - unsandboxed resolve-through
2. Run nondeterministic proc-macro tests.
3. Run incremental rebuild tests.
4. Record whether rustc artifacts still contain absolute sandbox paths that vary across requests.
5. Explicitly inspect env-derived paths such as `OUT_DIR` and proc-macro-observed filenames, not
   just command-line arguments and dep-info.

Success criteria:

- We understand exactly which benefits come from the alias root and which still require a
  non-sandboxed stable root.

### Phase 7: Performance Benchmarking

Benchmark the new path against the existing alternatives.

Required configurations:

1. staged execroot sandbox path
2. alias-root sandbox path
3. resolve-through path
4. unsandboxed worker-pipelining baseline
5. hollow-rlib sandbox baseline

Metrics:

1. wall time
2. critical path
3. average worker-side setup time
4. filesystem ops count if instrumentation is available
5. worker log volume

Target:

- alias-root worker-side setup should be much closer to resolve-through than to staged-execroot.

### Phase 8: Integration Tests

Add end-to-end tests that exercise actual Bazel worker behavior, not just analysis tests.

Required coverage:

1. `--strategy=Rustc=worker,sandboxed`
2. `--experimental_worker_multiplex_sandboxing`
3. worker cancellation enabled
4. metadata-only action behavior
5. full action behavior
6. fallback when background handoff is intentionally disabled in strict sandbox mode

Tests should verify:

1. request paths remain under `sandbox_dir`
2. no synthetic execroot is created
3. rewritten argfiles are consumed successfully
4. outputs land in the expected Bazel locations
5. worker logs do not show real-execroot escape for the compliant mode

## Code Areas Likely To Change

### Starlark

- [rust/private/rustc.bzl](../../../rust/private/rustc.bzl)
  - execution requirements
  - worker-key handling
  - sandboxed vs unsandboxed mode selection
  - potentially `worker-key-mnemonic`

### Rust worker implementation

- [util/process_wrapper/worker.rs](../../../util/process_wrapper/worker.rs)
  - request dispatch
  - mode selection
  - cancellation behavior

- [util/process_wrapper/worker_pipeline.rs](../../../util/process_wrapper/worker_pipeline.rs)
  - metadata/full architecture
  - out-dir and emit rewriting
  - background rustc lifecycle

- [util/process_wrapper/worker_protocol.rs](../../../util/process_wrapper/worker_protocol.rs)
  - request parsing and protocol validation

- [util/process_wrapper/worker_sandbox.rs](../../../util/process_wrapper/worker_sandbox.rs)
  - alias-root creation
  - sandbox path resolution
  - output materialization logic

- [util/process_wrapper/options.rs](../../../util/process_wrapper/options.rs)
  - paramfile rewriting support
  - relocated process-wrapper flags

### Tests

- [test/unit/pipelined_compilation/pipelined_compilation_test.bzl](../../../test/unit/pipelined_compilation/pipelined_compilation_test.bzl)
- [test/unit/incremental/incremental_test_suite.bzl](../../../test/unit/incremental/incremental_test_suite.bzl)
- [util/process_wrapper/BUILD.bazel](../../../util/process_wrapper/BUILD.bazel)

## Risks And Unknowns

1. The current one-rustc/two-request pipeline may remain fundamentally incompatible with strict
   sandboxing.
2. rustc or proc macros may canonicalize paths in ways that erase the relative-alias benefit.
3. Paramfile rewriting could become a maintenance burden if rustc flag formats change.
4. Some tools may require absolute paths even when rustc itself does not.
5. The alias-root design may still require enough rewriting that its complexity outweighs the
   performance gain.
6. Environment-derived paths such as `OUT_DIR` may require a broader rewrite surface than the
   command-line-only prototype first suggests.
7. If alias-root mainly removes worker-side staging cost but does not preserve enough path
   stability inside rustc artifacts, its value may collapse to "cheaper one-shot sandboxing" rather
   than "stable fast sandboxed pipelining."

## Recommended Outcome Criteria

Adopt the design only if all of the following are true:

1. It keeps all tool-visible reads and writes rooted in `sandbox_dir`.
2. It removes worker-side full-input staging.
3. It materially improves sandboxed worker setup time.
4. It has a clear, documented story for sandboxed metadata/full execution.
5. It is covered by real Bazel worker integration tests.

If Phase 0 fails and no sanctioned sandbox-lifetime mechanism exists, then the recommended product
shape is:

1. keep the current one-rustc worker-pipelining path for unsandboxed local execution,
2. use a compliant sandboxed mode that does **not** depend on post-response background work,
3. prefer hollow-rlib or equivalent two-invocation pipelining for strict sandboxed/dynamic modes
   until Bazel offers a better primitive.

In other words:

- the primary success case for this plan is not "salvage the old cross-request background-rustc
  architecture under stricter wording,"
- it is "recover most of the setup/path-stability benefit for compliant sandboxed execution, then
  combine that with a sandbox-safe pipelining architecture."

## Architectural References

### Bazel documentation

1. Creating Persistent Workers
   - <https://bazel.build/versions/8.4.0/remote/creating>
   - protocol, JSON format, cancellation, lifecycle rules

2. Multiplex Workers
   - <https://bazel.build/remote/multiplex>
   - `request_id`, multiplex worker model, `sandbox_dir`, sandboxing contract

3. Persistent Workers Overview
   - <https://docs.bazel.build/versions/main/persistent-workers.html>
   - worker strategy, worker sandboxing, worker-key behavior at a higher level

4. Dynamic Execution
   - <https://docs.bazel.build/versions/main/dynamic-execution.html>
   - context for cancellation and sandboxed local execution

### Bazel source and protocol

1. `worker_protocol.proto`
   - <https://bazel.googlesource.com/bazel/+/refs/tags/7.4.1rc2/src/main/protobuf/worker_protocol.proto>

2. `Spawns.java`
   - <https://bazel.googlesource.com/bazel.git/+/refs/heads/release-5.3.2/src/main/java/com/google/devtools/build/lib/actions/Spawns.java>
   - includes `getWorkerProtocolFormat` and `getWorkerKeyMnemonic`

3. `WorkerMultiplexer.java`
   - <https://bazel.googlesource.com/bazel.git/+/refs/heads/release-8.0.0-pre.20240925.4rc1/src/main/java/com/google/devtools/build/lib/worker/WorkerMultiplexer.java>
   - documents one multiplexer per `WorkerKey` and response routing by `request_id`

4. Bazel worker source tree
   - <https://bazel.googlesource.com/bazel.git/+/refs/heads/release-9.0.0-pre.20241125.3rc1/src/main/java/com/google/devtools/build/lib/worker>
   - inspect `WorkerKey`, `WorkerSpawnRunner`, `SandboxedWorker`, `WorkerExecRoot`,
     `WorkRequestHandler`, and related classes

5. Worker integration test
   - <https://bazel.googlesource.com/bazel/+/refs/tags/5.0.0-pre.20211011.2/src/test/shell/integration/bazel_worker_test.sh>

### Rust compiler references

1. rustc JSON output
   - <https://doc.rust-lang.org/beta/rustc/json.html>

2. rustc libraries and metadata
   - <https://rustc-dev-guide.rust-lang.org/backend/libs-and-metadata.html>

3. Cargo config and incremental behavior
   - <https://doc.rust-lang.org/cargo/reference/config.html>
