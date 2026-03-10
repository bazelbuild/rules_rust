# Reusable Staged Execroot Plan For Sandboxed Multiplex Workers

## Context

The current sandboxed pipelining path in `process_wrapper` is correct but expensive:

- each pipelined metadata request creates a fresh worker-owned staged execroot under
  `_pw_state/pipeline/<key>/execroot`,
- every declared input is restaged into that directory,
- the background rustc keeps running after Bazel tears down the request sandbox,
- outputs are later materialized back into the request sandbox.

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
   directory under Bazel's worker area.
2. For multiplex sandboxing, the worker receives a `sandbox_dir` and is expected to interpret the
   request's reads and writes relative to that per-request root.
3. Sandboxed actions are isolated by distinct per-request sandboxes; outputs must be materialized
   back into Bazel-managed output locations.
4. The local design doc's implemented model corresponds to Proposal 2a: a per-request sandbox root
   is the source of truth, and worker implementations are responsible for translating tool paths to
   that root.

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

### Slot Manifest

Each slot keeps a manifest of the staged view:

```json
{
  "request_id": 123,
  "entries": {
    "external/foo/src/lib.rs": {
      "digest": "abc...",
      "kind": "symlink",
      "resolved_target": "/.../sandbox/.../external/foo/src/lib.rs"
    },
    "bazel-out/k8-fastbuild/bin/lib/math/_pipeline/libmath.rmeta": {
      "digest": "def...",
      "kind": "symlink",
      "resolved_target": "/.../sandbox/.../_pipeline/libmath.rmeta"
    }
  }
}
```

The key property is that the manifest is keyed by request-visible relative path, not by the worker's
real execroot.

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
are still materialized back into the request sandbox/output tree as regular files.

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

### Phase 1: Add A Stage Slot Abstraction

Introduce:

- `StageSlot`
- `StagePool`
- `StageManifest`

Requirements:

- bounded slot count
- borrow/release lifecycle
- manifest load/store in worker-owned state

### Phase 2: Move From Rebuild To Diff

Replace `create_staged_pipeline()`'s "delete and recreate execroot" behavior with:

- slot acquisition
- manifest diff
- targeted create/update/delete of changed paths

Keep the existing path rewrite and output materialization behavior unchanged at first.

### Phase 3: Instrument Reuse

Add counters to pipeline logs:

- unchanged entries reused
- entries replaced
- entries removed
- total manifest entries
- stage diff time vs actual filesystem mutation time

This is required to prove the design is helping for the mixed-target regressions.

### Phase 4: Correctness Validation

Validate:

- metadata/full pipelining still succeeds under multiplex sandboxing
- no stale `.rmeta` leakage across requests
- `bazel-out/.../_pipeline` entries are updated when digests change
- worker restart loses only cached slot state, not correctness

### Phase 5: Benchmark Gates

Acceptance bar:

- `//zm_cli:zm_cli_lib` must stay at least as good as the current safe path
- `sdk_builder_lib` and `asset_manager` should show reduced worker preparation overhead
- `//sdk` must improve or at minimum explain remaining loss via non-worker actions

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
- periodic full slot reset under debug/flag

## Why This Design Matches The Bazel Contract Better

Compared with the rejected real-execroot idea:

- it does not depend on undocumented Bazel execroot layout,
- it does not read from shared `execroot/_main`,
- it keeps the request sandbox/input list as the authoritative request view,
- it keeps Bazel-visible outputs materialized as real files.

Compared with Proposal 1 from the local design doc:

- it borrows the useful optimization idea of stateful reuse across actions,
- but keeps isolation by reusing a pool of private staged roots rather than a single shared mutable
  sandbox.

That is a stricter and safer fit for current multiplex sandboxing than a shared worker-wide view.

## Required Verification

- `bazel test //util/process_wrapper:process_wrapper_test`
- focused cold comparisons:
  - `//zm_cli:zm_cli_lib`
  - `//sdk/sdk_builder:sdk_builder_lib`
  - `//helium/asset_manager:asset_manager`
- one `//sdk` run with the same benchmark flags used in `thoughts/shared/bench_sdk.sh`
