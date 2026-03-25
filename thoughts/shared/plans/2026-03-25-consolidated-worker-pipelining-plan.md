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

3. What test coverage is still missing?
   At minimum:
   - cancellation with a live background rustc,
   - worker shutdown with active pipeline entries,
   - explicit `bazel clean` / teardown behavior for multiplex workers,
   - metadata-cache-hit / full-request-fallback paths,
   - dynamic execution with a real remote executor and explicit worker cancellation behavior.

4. Which public docs should be downgraded from recommendation to experiment?
   The settings docs and code comments should reflect the actual maturity of the sandboxed path.

## Recommended Next Steps

1. Keep this file as the single current plan.
2. Do not recreate a parallel dated plan stack for the same topic unless the problem scope changes
   materially.
3. Move future benchmark updates into benchmark docs or raw-data summaries rather than back into
   the plan stack.
4. Make one explicit product decision about sandboxed worker pipelining:
   - either narrow the supported scope and document the current limitations,
   - or start a fresh strict-sandbox design from the remaining open questions above.
5. Update code comments and user-facing settings docs so they do not overstate the sandboxed
   contract story.

## Benchmark And Artifact References

The following files remain useful and should not be collapsed into this plan:

- `thoughts/shared/bench_sdk_analysis.md`
- `thoughts/shared/benchmark_analysis.md`
- `thoughts/shared/bench_sdk_raw.csv`
- `thoughts/shared/bench_cargo_raw.csv`
- `thoughts/shared/benchmark_raw_data.csv`

Those files contain raw or summarized measurements. This file is only for architecture and status.
