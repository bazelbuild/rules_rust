> **SUPERSEDED** by `2026-03-13-dynamic-execution-worker-pipelining.md`

# Cross-Process Shared Stage Pool Plan

## Context

The current per-process stage pool is not matching actual Bazel worker lifetimes under
`--experimental_worker_multiplex_sandboxing`.

Observed on full `//sdk`:

- about `575` metadata stagings per build
- about `575` distinct Rust worker workdirs
- `max_reuse_count=1`
- worker-side setup remains about `250 ms` per metadata action even after instrumentation

That means the current optimization is attacking the wrong lifetime. Reuse has to survive worker
process boundaries to matter.

## Bazel Precedent

Bazel already uses the same general strategy in several places: preserve sandbox state and update it
incrementally instead of rebuilding from scratch every action.

1. `processwrapper-sandbox` builds a symlink forest under a per-action directory, and Bazel docs call
   out `sandboxfs` as a way to avoid the large number of filesystem calls needed to materialize that
   tree. This is direct precedent that symlink creation cost is a first-order bottleneck, not an
   implementation detail.
   Sources:
   - https://bazel.build/docs/sandboxing
   - https://bazel.build/docs/sandboxing#sandboxfs

2. Bazel has an explicit `--reuse_sandbox_directories` flag for sandbox reuse. More recently, Bazel
   added in-memory sandbox stash tracking and a matching worker-sandbox tracking mode
   (`--experimental_inmemory_sandbox_stashes`,
   `--experimental_worker_sandbox_inmemory_tracking`) specifically to reduce sandbox setup and
   cleanup overhead.
   Sources:
   - https://bazel.build/reference/command-line-reference#flag--reuse_sandbox_directories
   - https://bazel.build/reference/command-line-reference#flag--experimental_inmemory_sandbox_stashes
   - https://bazel.build/reference/command-line-reference#flag--experimental_worker_sandbox_inmemory_tracking
   - https://github.com/bazelbuild/bazel/pull/23773

3. Sandboxed persistent worker inputs already carry digests. Bazel’s worker protocol and worker
   sandboxing docs explicitly support checking whether a staged input is still valid instead of
   blindly rebuilding the tree. That is exactly the contract a shared manifest-based slot pool needs.
   Sources:
   - https://bazel.build/remote/persistent
   - https://bazel.build/versions/8.0.0/remote/worker

4. Bazel’s worker execroot setup already uses an incremental model internally: `WorkerExecRoot`
   removes stale paths, preserves valid ones, and creates only missing inputs. The current
   `process_wrapper` stage pool mirrors that idea, but only within one process. Cross-process reuse
   extends the same approach to the lifetime that the benchmark data says matters.
   Local source references:
   - [2026-03-10-multiplex-sandbox-staged-execroot-reuse.md](/var/mnt/dev/rules_rust/thoughts/shared/plans/2026-03-10-multiplex-sandbox-staged-execroot-reuse.md)

## Proposed Design

### Goal

Reuse a staged execroot across different Rust worker processes while preserving the same correctness
boundary as the current per-process design:

- request-visible inputs still come only from `WorkRequest.inputs` plus `sandbox_dir`
- outputs remain worker-materialized files in the request-local pipeline directory
- any uncertain manifest state falls back to restaging, not optimistic reuse

### Shared Pool Layout

Create a shared pool root outside any single worker workdir, keyed by a namespace that is stable
across equivalent Rust workers:

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

Proposed namespace inputs:

- workspace / execroot identity
- rust toolchain identity (`rustc` path, sysroot path, target triple)
- startup-arg shape that affects execroot contents
- platform / compilation mode if it affects staged toolchain or outputs

Do not share slots across namespaces.

### Slot Ownership

Each slot is leased exclusively from metadata request start until the matching full action finishes,
just like today. The difference is that ownership is enforced with a filesystem lock rather than an
in-process queue.

Proposed mechanism:

1. Scan slots in namespace order.
2. Try `LOCK_EX | LOCK_NB` on `slot-N/lock`.
3. On success:
   - load `manifest.json`
   - record `lease.json` for debugging and stale-owner diagnosis
   - diff-stage into `execroot/`
4. Hold the lock for the full pipeline lifetime.
5. On full completion:
   - atomically write manifest
   - clear / rewrite lease metadata
   - release lock

Do not block indefinitely waiting for a slot in the first version. If no slot is acquirable quickly,
fall back to one-shot staging and record that as an explicit metric.

### Why Lock For The Full Pipeline Lifetime

The background rustc process runs inside the staged execroot between metadata and full. Releasing the
slot after metadata would allow another worker to mutate the same tree while rustc is still using it.
The current per-process design already got this lifetime right; the shared design should keep it.

### Manifest Rules

Keep the current conservative manifest identity model:

- prefer Bazel-provided digest when present
- fall back to resolved symlink target only when digest is absent
- if an entry is missing on disk, remove and restage it
- on parse errors or ambiguous state, reset the slot

Keep the periodic full-reset rule and the “remove more than half the manifest” reset heuristic.

### Atomicity

For the shared version, manifest writes should become atomic:

1. write `manifest.json.tmp`
2. `fsync` file if needed
3. `rename()` over `manifest.json`

That avoids cross-process readers seeing partially written JSON.

## Additional Instrumentation

These measurements should be present before or during the cross-process prototype.

### Added Now

Current worker metrics now include:

- `declared_inputs`
- `stage_io_ms`
- `avg_declared_inputs`
- `avg_setup_per_input_ms`

This gives a direct read on whether setup cost is scaling with input count or with fixed overhead.

### Add For Shared-Pool Prototype

Add these persistent metrics to `_pw_state/metrics.log`:

1. `slot_acquire namespace=... slot=... wait_ms=... attempts=...`
2. `slot_release slot=... hold_ms=... manifest_save_ms=...`
3. `slot_fallback reason=no_free_slot|lock_timeout|namespace_error`
4. `slot_reset reason=periodic|manifest_error|high_churn reset_ms=...`
5. `staging ... manifest_before=... manifest_after=... remove_ms=... stage_io_ms=...`
6. `lease_recovery slot=...` if stale-owner recovery logic is ever added

The benchmark CSV should also report:

- average `declared_inputs`
- average `setup_ms / declared_input`
- average `stage_io_ms`
- fallback rate
- lock-wait p50 / p90 once the shared pool exists

## Driving Down Symlink Cost

Cross-process reuse is the main structural fix, but there are still ways to reduce symlink-related
cost further.

### 1. Seed Stable Roots Once Per Shared Slot

The current design already seeds sandbox and worker roots once per slot lifetime. In a shared pool,
that becomes materially more valuable because the slot can survive many worker processes.

Candidate roots:

- stable toolchain roots
- stable `external/` subtrees
- cache roots already handled by `maybe_seed_cache_root_for_path`

### 2. Measure Cost Per Declared Input

If `avg_setup_per_input_ms` stays high after reuse begins, the next problem is per-entry syscall
cost, not slot churn. That determines whether further work should focus on:

- fewer staged entries
- fewer directory creations
- fewer symlink syscalls

### 3. Favor Whole-Directory Reuse Where Safe

Current code already preserves symlinks and can symlink whole directories when they are outside the
request sandbox. That is the right direction because a single directory symlink replaces many file
operations. Any extension of this idea should remain conservative and only target immutable roots.

### 4. Borrow Bazel’s Sandbox Placement Ideas

If the shared pool still spends too much time on filesystem metadata churn, consider:

- placing the shared pool under a fast local filesystem / tmpfs-like sandbox base
- continuing to prefer hardlinks for regular files where possible

Relevant Bazel precedent:

- `--sandbox_base`
- hermetic Linux sandbox mode notes that inputs are hardlinked rather than symlinked

Sources:
- https://bazel.build/reference/command-line-reference#flag--sandbox_base
- https://bazel.build/reference/command-line-reference#flag--experimental_use_hermetic_linux_sandbox

### 5. Keep `sandboxfs` As A Conceptual Escape Hatch

Bazel’s own docs point to `sandboxfs` as a way to avoid paying a filesystem syscall per input when
materializing sandboxes. That is too large a step for the next change here, but it is useful
precedent: if shared-slot reuse still leaves a large symlink-forest tax, a more virtualized input
projection model may be the only way to reduce it further.

## Implementation Plan

### Phase 0: Finish Measurement

1. Fix `worker_preparing` extraction from Bazel profiles.
2. Land the added worker metrics parsing.
3. Confirm `avg_setup_per_input_ms` on `sdk_builder_lib` and `//sdk`.

### Phase 1: Shared Slot Namespace

1. Move pool root out of worker-local `_pw_state/stage_pool`.
2. Define namespace key derivation.
3. Switch manifest save to atomic rename.

### Phase 2: Cross-Process Slot Leasing

1. Add per-slot lock file.
2. Add `lease.json` debug metadata.
3. Replace in-process queueing with lock-based scanning.
4. Keep one-shot fallback when no slot is available quickly.

### Phase 3: Shared-Pool Metrics

1. Add acquire / release / fallback / reset log lines.
2. Extend benchmark script to capture fallback rate and lock wait.
3. Track slot hold time across metadata + full.

### Phase 4: Validation

1. `sdk_builder_lib` benchmark against current per-process pool
2. `//sdk` benchmark for wall, critical path, worker setup, reuse histogram
3. correctness testing for stale-manifest and changed `_pipeline/*.rmeta`

### Phase 5: Decide Whether To Continue

Continue only if at least one of these happens:

- reuse histogram shows `reuse_count > 1` broadly on full `//sdk`
- worker-side setup drops materially on `//sdk`
- fallback rate stays low enough that the shared pool is actually being used

If reuse still does not appear, stop here and shift attention to Bazel-side sandbox prep or a more
virtualized input projection model.

## Acceptance Bar

Minimum bar for the shared-pool prototype:

- correctness on full `//sdk`
- measurable `reuse_count > 1` on full `//sdk`
- setup reduction materially larger than the current 7% win from the per-process pool
- no evidence of stale-input leakage

Without those, the added locking and manifest complexity is not justified.

## Worker Key Fix — Supersedes Cross-Process Design (2026-03-13)

### Root Cause Discovery

The entire cross-process shared stage pool proposal was predicated on the assumption that Bazel
spawns many short-lived worker processes that each handle only a few requests. Investigation on
2026-03-13 found the real root cause: **per-action process_wrapper flags in the startup args cause
every action to get a unique WorkerKey, and thus a unique OS process.**

Bazel's multiplex worker architecture is designed for one OS process per unique WorkerKey, with up
to `--worker_max_multiplex_instances` (default 8) concurrent requests sharing that process. The
WorkerKey is derived from `(mnemonic, startup_args, env, execRoot, ...)` — specifically everything
on the command line except the @paramfile contents.

In `construct_arguments` (`rust/private/rustc.bzl`), these flags are added to
`process_wrapper_flags` (startup args, part of WorkerKey):

- `--output-file <crate_output_path>` (line 1120-1122) — **unique per crate**
- `--env-file <path>` (line 1031) — per build-script dependency
- `--arg-file <path>` (line 1033) — per build-flags dependency
- `--rustc-output-format rendered|json` (line 1090) — varies by error_format config
- `--volatile-status-file <path>` (line 1054) — present only when stamp=True
- `--stable-status-file <path>` (line 1055) — present only when stamp=True

Since `--output-file` alone has a different path for every crate, every action gets a unique
WorkerKey → unique OS process → the process handles exactly 2 requests (metadata + full pipeline
pair) → stdin_eof → exit. This was confirmed by:

- 575 distinct worker workdirs for 575 metadata actions
- `argv_len` varying widely across workers (10, 14, 18, 24, 32, 44, 66, 72)
- Every worker seeing exactly `requests_seen=2` in the lifecycle log
- `reuse_count=1` universally (pool reuse never triggers)

### The Fix: Stable Worker Key via Per-Request Flag Relocation

**Instead of cross-process stage pool reuse, fix the worker key so a single process handles all
Rust actions.** The existing per-process stage pool then works as designed.

#### Starlark Side (rustc.bzl)

For worker pipelining actions (`use_worker_pipe = True`), move per-action flags from
`process_wrapper_flags` to `rustc_flags` (the @paramfile). This keeps them out of the startup
args / WorkerKey:

**Move to paramfile (per-action):**
- `--output-file <path>`
- `--env-file <path>`
- `--arg-file <path>`
- `--rustc-output-format <format>`
- `--volatile-status-file <path>`
- `--stable-status-file <path>`

**Keep in startup args (stable across all actions):**
- `--subst pwd=${pwd}`
- `--require-explicit-unstable-features true`

Result: all worker pipelining actions share the same startup args → same WorkerKey → same OS
process → stage pool reuse across the full build.

#### Rust Side (worker.rs)

After constructing `full_args = startup_args + request.arguments`, the per-action pw flags are
after the `--` separator (they came from the paramfile). Both `options.rs` (subprocess path) and
`parse_pw_args` (pipelining path) expect them before `--`.

Add a `relocate_pw_flags()` function that scans for known pw flags after `--` and moves them
before it. This is safe because:

- The flag names (`--output-file`, `--env-file`, etc.) are unambiguous — they cannot collide with
  rustc flags
- The relocation preserves the semantics exactly — same flags, same values, just reordered

#### Worker Process Sharding (Optional Follow-up)

With a stable WorkerKey, all Rust actions share one OS process. For large machines or builds with
high parallelism, an optional sharding mechanism can create N worker processes:

Add `--worker-shard=<hash(crate_name) % N>` to `process_wrapper_flags`. This is stable per crate
(both metadata and full hash to the same shard) but creates N distinct WorkerKeys.

Tradeoff: N=1 gives maximum reuse, N>1 gives more parallelism but less reuse per process.

### Expected Impact

With 575 metadata actions and 8 pool slots per process:

| Config | Processes | Metadata/process | Expected reuse_count |
|--------|-----------|-------------------|---------------------|
| Current (broken) | 575 | 1 | 1 (no reuse) |
| Fixed, N=1 | 1 | 575 | ~72 |
| Fixed, N=4 | 4 | ~144 | ~18 |

At reuse_count=72, the diff mechanism finally triggers meaningfully: most inputs are already staged
from the previous request, so staging cost drops from O(991 adds) to O(delta). The per-action
setup should drop from ~284ms to much less for the reuse case.

### Implementation Status

- [x] Phase A: Move per-action pw flags to paramfile in `rustc.bzl`
  - `--output-file`, `--rustc-output-format`, `--env-file`, `--arg-file` routed to `rustc_flags`
    when `use_worker_pipelining=True` (passed from `rustc_compile_action`)
  - `disable_pipelining` attribute ignored when worker pipelining is active (it only works around
    SVH mismatch in hollow-rlib mode, which worker pipelining doesn't use)
  - Verified via aquery: 474 worker actions share 1 distinct key `('--subst', 'pwd=${pwd}')`
- [x] Phase B: Add `relocate_pw_flags()` to `worker.rs`
  - `is_relocated_pw_flag()` in `options.rs` extended for `--env-file` and `--arg-file`
  - `prepare_param_file` strips relocated flags in non-worker (sandbox fallback) path
- [x] Phase B.1: Close stamped-action worker-key gap
  - `--stable-status-file` and `--volatile-status-file` were still left in startup args for
    worker-pipelining actions, which meant stamped Rust actions would still shard by WorkerKey even
    after the broader relocation work.
  - Fixed on 2026-03-13 by routing both stamp-status flags through the paramfile when
    `use_worker_pipe=True`, extending relocated-flag stripping/relocation to cover them, and
    teaching the pipelining path to apply workspace-status substitutions from those files when
    building the rustc environment.
- [x] Phase C: Validate with `process_wrapper_test` — all 11 tests pass
- [x] Phase C.1: Re-validate after stamped-action fix
  - `bazel test //util/process_wrapper:process_wrapper_test --test_output=errors`
  - `bazel build //test/json_worker_probe:process_wrapper_probe_suite`
- [ ] Phase D: Benchmark on `//sdk` — PARTIAL: build succeeds, worker key unified, but
  `--experimental_worker_multiplex_sandboxing` still spawns ~585 worker processes (one per
  concurrent-request batch). All share `argv_len=6` (same key), but Bazel's multiplexer
  creates a new process for each batch regardless. Stage pool reuse stays at 0-1 because
  each process handles only 2 requests (one pipeline pair).
  - **Conclusion**: The worker key fix is correct and necessary but INSUFFICIENT with
    `--experimental_worker_multiplex_sandboxing`. The per-batch process spawning is Bazel-side
    behavior that cannot be fixed in process_wrapper. The cross-process shared stage pool
    (original plan) may still be needed for multiplex sandboxing builds.
  - Without multiplex sandboxing (unsandboxed workers), this fix WOULD give reuse_count>>1.
- [ ] Phase E (optional): Add worker shard setting for multi-process support

## Investigation Update (2026-03-13)

The work since this plan was written has split into two threads:

1. validating whether cross-process staged execroot reuse is still required for performance
2. investigating a separate multiplex-worker teardown failure that appears to be the more urgent
   correctness problem

The current evidence still supports the original performance conclusion in this document:
per-process stage reuse does not line up with Bazel's actual worker lifetime, and cross-process
reuse is still the likely direction if we continue optimizing staged execroot setup cost.

One concrete cleanup landed while debugging: the worker-key stabilization work was incomplete for
stamped actions. Those actions still carried `--stable-status-file` / `--volatile-status-file` in
startup args, which would have kept stamped builds split across distinct WorkerKeys. That is now
fixed and revalidated locally; any remaining multi-process behavior under
`--experimental_worker_multiplex_sandboxing` is therefore less likely to be a leftover
process_wrapper keying bug.

Another concrete cleanup landed in the staged-execroot reuse path itself: slot seeding now actually
persists across slot reuse instead of being torn down and recreated on every request. The original
per-process pool work recorded `seed_entries`, but the seeding helpers still removed those entries
before every reseed. That defeated the intended "seed stable roots once per slot lifetime" behavior
and kept paying top-level symlink churn on every reuse. The current implementation now:

- treats `seed_entries` as a reuse cache, not a reseed checklist
- skips reseeding when the recorded top-level roots are still present
- falls back to reseeding only when the recorded seed set is missing or the slot has been reset
- records only seeding-created top-level entries for worker-root seeding, rather than every
  top-level execroot entry

This does not solve the larger cross-process lifetime problem, but it removes a real source of
avoidable per-request setup work and makes the slot-lifetime seeding behavior match the design
described earlier in this document.

At the same time, the more immediate bug is no longer "steady-state worker response formatting" or
"stage-pool reuse is missing". The dominant reproducible failure now looks like abrupt multiplex
worker death around teardown, especially during `bazel clean` / `bazel clean --expunge`.

### What Was Tried

Worker instrumentation added in `util/process_wrapper/worker.rs`:

- request and input snapshots
- `_pipeline/*.rmeta` tracking
- `--extern` logging
- emitted artifact state logging
- worker lifecycle logging
- response logging with checksums and prefix/suffix bytes
- root-level lifecycle logging that survives `bazel clean`
- explicit teardown attribution hooks:
  - `event=stdin_eof`
  - `event=stdin_read_error`
  - Unix signal markers for `SIGHUP`, `SIGINT`, `SIGQUIT`, `SIGPIPE`, `SIGTERM`
- worker-wide shutdown coordination:
  - global `shutting_down` state
  - `event=shutdown_begin`
  - stop accepting new work once shutdown starts
  - short-circuit late-arriving requests with a shutdown response
  - soft `SIGTERM` experiment:
    - signal handler marks shutdown
    - closes stdin to break the read loop
    - returns instead of hard `_exit`

Worker response-path tightening:

- raw fd-1 writes under a mutex
- deterministic JSON field order

Probe ladder added under `test/json_worker_probe`:

- bare JSON worker
- generic `process_wrapper` worker
- trivial Rust
- Rust fan-in
- Rust proc-macro
- hybrid Rust graph
- abrupt JSON worker
- abrupt real `process_wrapper` worker

Reproduction / inspection work:

- replayed real reactor builds on `//tools/zerobuf_cli:zerobuf_cli` and nearby subtargets with the
  exact worker-pipelining config
- ran a focused real-world `build -> clean -> build` sequence on
  `//tools/zerobuf_cli:zerobuf_cli` with the worker-pipelining / multiplex-sandboxing flag set
- ran an additional forced-rebuild `build -> clean -> build` loop on
  `//tools/zerobuf_cli:zerobuf_cli` with a unique `--cfg` to ensure real Rust worker activity
- preserved direct zerobuf-chain pipeline directories for post-failure inspection
- verified that some execroot `_pipeline/*.rmeta` artifacts are hardlinked/shared rather than
  snapshotted

### What Did Not Work

- repeated cold-start `zerobuf_cli` builds are not reliably failing right now
- successful direct zerobuf-chain preserved logs remain healthy and do not yet show the bad
  upstream metadata state
- changing response serialization and stdout write mechanics did not affect the parse storm
- there is still no fresh, instrumented `E0463` run that identifies the exact stale or missing
  upstream `_pipeline/*.rmeta`

### What We Know Now

- the reproducible bug is the multiplex-worker teardown failure, not steady-state response
  formatting
- `bazel clean` and `bazel clean --expunge` now reliably trigger:
  `Could not parse json work request correctly`
- root lifecycle logging shows recent Rust workers:
  - start
  - complete requests successfully
  - then disappear without a normal `event=exit` or `event=panic`
- the abrupt worker probes confirm Bazel reacts badly when a multiplex worker dies immediately
  after emitting a valid response
- the abrupt `process_wrapper` probe remains a strong control case:
  Bazel reports a valid JSON response, then reports that the worker died or produced an
  "unparseable WorkResponse"
- the root lifecycle log now captures this deterministic control path as `event=forced_exit`
- the real `bazel clean` storm is now attributed more precisely:
  the root lifecycle log shows many Rust workers receiving `SIGTERM`
- the shutdown-state change did not remove the abrupt control-case failure; it only made the worker
  behavior more attributable
- the soft `SIGTERM` experiment changed worker-side teardown shape:
  many workers now log `SIGTERM -> stdin_eof -> exit`
- the soft `SIGTERM` experiment did not remove Bazel's clean-storm messages; Bazel still reports
  `Could not parse json work request correctly` during `bazel clean`
- even with a forced-rebuild loop that exercised real Rust metadata workers again, the post-clean
  `//tools/zerobuf_cli:zerobuf_cli` rebuild still succeeded; `E0463` remains non-deterministic
- an immediate post-clean rebuild of `//tools/zerobuf_cli:zerobuf_cli` succeeded once, so the clean
  storm still does not deterministically induce downstream `E0463`
- `E0463` still looks like rarer downstream fallout when the broader teardown/state bug lands
  badly

### Current Read

Treat abrupt multiplex worker death as the primary bug.

The likely branching is now:

- `bazel clean` is using a catchable signal (`SIGTERM`), so there is a plausible local mitigation
  path in `process_wrapper`
- if the real clean storm is effectively abrupt death after a valid response, the real fix is more
  likely upstream Bazel, and the abrupt `ProcessWrapperProbe` target is the shortest path to a
  minimal reproducer
- if `E0463` requires a very specific death point in the pipelined Rust path, that should be forced
  deterministically with test-only fault injection rather than waited on passively

### Immediate Next Steps

1. Compare the real clean-storm sequence directly against the abrupt `process_wrapper` control case.
   The clean storm is now confirmed as `SIGTERM`, and a softer local shutdown still does not silence
   Bazel's parse storm. The abrupt probe remains the best minimal
   reproducer for "valid response followed by worker death".

2. Re-run a focused stamped and unstamped worker-pipelining profile on a small Rust target, now that
   all known per-action process_wrapper flags are out of startup args.
   Confirm with lifecycle / metrics logs whether stamped actions still show any WorkerKey
   fragmentation before spending more time on cross-process reuse.

3. Decide whether to keep or revert the soft `SIGTERM` path.
   It improves worker-side attribution and gives graceful `stdin_eof -> exit`, but so far does not
   improve Bazel-visible clean behavior.

4. Run more focused forced-rebuild `build -> clean -> build` loops and stop on the first downstream
   `E0463`.
   Preserve and inspect the upstream `_pipeline/*.rmeta` chain immediately when it happens.

5. Keep `E0463` work on a deterministic path.
   If it remains flaky, add a test-only mode that kills the worker at a chosen pipelined metadata /
   full boundary and inspect preserved `_pipeline/*.rmeta` immediately.

6. Keep the cross-process shared stage pool proposal on hold until the teardown bug is better
   separated from the metadata corruption fallout.
   Cross-process reuse is still the likely performance direction, but it should not be advanced as
   the primary fix for the current correctness failure.
