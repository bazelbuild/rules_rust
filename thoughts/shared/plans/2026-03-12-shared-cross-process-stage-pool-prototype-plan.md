> **SUPERSEDED** by `2026-03-13-dynamic-execution-worker-pipelining.md`

# Shared Cross-Process Stage Pool Prototype Plan

## Goal

Prototype a shared staged-execroot pool that survives Rust worker process boundaries.

The benchmark results now make the problem concrete:

- full `//sdk` still shows about one Rust worker workdir per metadata action
- `max_reuse_count=1`
- worker-topology tuning did not materially change that

So the prototype should answer one question: can staged execroot reuse become real once slot
ownership moves from "inside one worker process" to "shared across equivalent workers"?

## Bazel Precedent

Bazel already uses the same general optimization pattern in its sandboxing machinery: preserve
sandbox state and update it incrementally instead of rebuilding everything every action.

Relevant precedent:

1. `--reuse_sandbox_directories`
   Bazel explicitly supports reusing sandbox directories to reduce setup and teardown cost.

2. `--experimental_inmemory_sandbox_stashes`
   Bazel keeps sandbox stash tracking in memory to reduce filesystem overhead for reused
   sandboxes.

3. `--experimental_worker_sandbox_inmemory_tracking`
   Bazel has worker-specific sandbox reuse tracking, which is direct precedent that worker
   sandbox lifecycle is worth optimizing separately from generic sandbox execution.

4. `WorkerExecRoot`
   Bazel's worker execroot setup removes stale paths, preserves still-valid entries, and creates
   only what is missing instead of rebuilding the full tree every time.

5. Sandbox docs and `sandboxfs`
   Bazel documents symlink-forest creation as expensive enough to justify a dedicated
   optimization path, which is strong precedent that input projection cost is a first-order
   performance concern.

Useful references:

- https://bazel.build/docs/sandboxing
- https://bazel.build/docs/sandboxing#sandboxfs
- https://bazel.build/reference/command-line-reference#flag--reuse_sandbox_directories
- https://bazel.build/reference/command-line-reference#flag--experimental_inmemory_sandbox_stashes
- https://bazel.build/reference/command-line-reference#flag--experimental_worker_sandbox_inmemory_tracking
- https://bazel.build/remote/persistent
- https://bazel.build/versions/8.0.0/remote/worker

## Scope

Keep the prototype narrow.

Implement only:

1. shared pool root outside worker-local `_pw_state`
2. namespace derivation so only equivalent workers share slots
3. file-lock-based slot leasing
4. atomic manifest writes
5. persistent metrics for acquisition, fallback, hold time, and reuse

Do not combine this prototype with new input-pruning logic.

## Shared Pool Design

Create a shared pool root under Bazel output base:

```text
<output_base>/rules_rust_shared_stage_pool/
  <namespace-hash>/
    slot-000/
      lock
      lease.json
      manifest.json
      execroot/
    slot-001/
    ...
```

Namespace inputs should include:

- workspace / execroot identity
- Rust toolchain identity
- target triple
- startup-arg shape that affects staged contents

Do not share slots across namespaces.

## Slot Ownership Model

Use one slot per in-flight pipelined metadata/full pair.

Rules:

1. Metadata action scans slots in namespace order.
2. It tries a non-blocking exclusive lock on `slot-N/lock`.
3. On success, it loads `manifest.json`, diff-stages the request, and records `lease.json`.
4. It keeps the lock for the entire metadata-to-full lifetime.
5. Full action releases the slot after background rustc is done and manifest is atomically saved.

If no slot is available quickly, fall back to one-shot staging and log that explicitly.

This preserves the current safety property: no other request can mutate an execroot while the
background rustc process is still using it.

## Implementation Phases

### Phase 1: Shared Root And Namespace

1. Move pool root out of worker-local `_pw_state/stage_pool`.
2. Derive a stable namespace key.
3. Keep the current manifest format initially.

### Phase 2: Atomic Manifest Persistence

1. Write manifest to a temp file.
2. Rename over `manifest.json`.
3. Treat parse errors as reset conditions.

### Phase 3: Cross-Process Leasing

1. Add per-slot lock files.
2. Add `lease.json` for diagnostics.
3. Replace in-process availability queue with lock-based acquisition.
4. Keep one-shot fallback when no slot is available quickly.

### Phase 4: Metrics

Add persistent log lines for:

1. `slot_acquire ... wait_ms=...`
2. `slot_release ... hold_ms=...`
3. `slot_fallback reason=...`
4. `slot_reset reason=...`
5. existing staging metrics plus manifest-before/after counts

### Phase 5: Benchmark Gates

Run on:

1. `//sdk/sdk_builder:sdk_builder_lib`
2. `//sdk`

Compare against the current best control configuration:

- `--sandbox_base=/dev/shm`

## Success Criteria

Continue only if the prototype shows all of these:

1. `max_reuse_count > 1` on full `//sdk`
2. fallback rate low enough that shared slots are actually being used
3. materially lower `avg_setup_ms` on full `//sdk`
4. correctness on the full graph

If reuse still does not appear, stop. At that point the likely bottleneck is Bazel-side sandbox
preparation or the fundamental cost of request-sandbox materialization, not worker-local staging.

## Recommended Next Context

Suggested prompt:

> Prototype Phase 1 and Phase 2 of the shared cross-process stage pool in
> `util/process_wrapper/worker.rs`: shared pool root keyed by namespace, atomic manifest writes,
> and per-slot file-lock leasing with one-shot fallback. Add persistent metrics for slot
> acquire/release/fallback. Do not change input declaration logic.

## Related Local Docs

- [2026-03-11-cross-process-shared-stage-pool-plan.md](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-11-cross-process-shared-stage-pool-plan.md)
- [2026-03-11-multiplex-sandbox-overhead-investigation-plan.md](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-11-multiplex-sandbox-overhead-investigation-plan.md)
- [2026-03-10-multiplex-sandbox-staged-execroot-reuse.md](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-10-multiplex-sandbox-staged-execroot-reuse.md)
