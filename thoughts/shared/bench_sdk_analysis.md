# SDK Benchmark Analysis: Worker Pipelining with Multiplex Sandboxing

**Date:** 2026-03-09
**Target:** `reactor-repo-2 //sdk` (73 first-party Rust libraries, ~165 total)
**Machine:** 16 jobs, Linux 6.17.7, x86_64
**Bazel:** 9.0.0
**Script:** `thoughts/shared/bench_sdk.sh`, 5 iterations
**Previous benchmark:** 2026-03-06 (Bazel 8.4.2, no multiplex sandboxing)

## Methodology

Three cold-build configs and three warm-rebuild configs were measured:

| Config | Flags |
|---|---|
| `no-pipeline` | `pipelined_compilation=false` (baseline) |
| `worker-pipe` | `experimental_worker_pipelining=true`, `--experimental_worker_multiplex_sandboxing`, `--strategy=Rustc=worker,sandboxed` |
| `worker-pipe+incr` | same as worker-pipe + `experimental_incremental=true` |
| `*-rb` | corresponding rebuild: prime build → append comment to `lib/hash/src/lib.rs` → rebuild |

**Key change from previous benchmark:** This run uses `--experimental_worker_multiplex_sandboxing`
(per-request sandbox isolation within the multiplex worker) and `worker,sandboxed` fallback
strategy. The previous benchmark used unsandboxed multiplex workers with `worker,local` fallback.

**Forcing Rust cache misses:** each cold build uses a unique `--extra_rustc_flag=--cfg=bench_<config>_i<N>_r<RUN_ID>`. This is a target-config flag only; exec-config actions (C/CC, build scripts, proc-macros) stay disk-cached across all runs.

**Note on iteration 1:** Iteration 1 cold builds show higher variance (157.7s no-pipeline, 126.9s worker-pipe) because some disk-cache entries were not yet populated. By iteration 2 all non-Rust actions are cached. Stable means below use iterations 2–5.

**Note on incremental rebuild validity:** Only iteration 1's `worker-pipe+incr-rb` (4.3s) reflects true warm-incremental performance. In iterations 2+, the rebuild prime hits the Bazel disk cache (rustc doesn't run), so no incremental state gets written. The iters 2–5 `worker-pipe+incr-rb` results (~21.4s) are effectively cold-incremental rebuilds.

---

## Raw Data

```
iter,config,wall_ms,wall_s,crit_s,total_actions,worker_count,sandbox_count
1,no-pipeline,157741,157.7,106.63,1086,0,1043
1,worker-pipe,126874,126.9,72.77,1661,1150,15
1,worker-pipe+incr,97381,97.4,78.77,1167,1165,0
1,no-pipeline-rb,26438,26.4,25.87,106,0,105
1,worker-pipe-rb,27624,27.6,26.95,174,106,67
1,worker-pipe+incr-rb,4310,4.3,3.84,64,7,0
2,no-pipeline,86856,86.9,71.85,1087,0,590
2,worker-pipe,79841,79.8,52.59,1676,1150,15
2,worker-pipe+incr,109799,109.8,82.11,1167,1165,0
2,no-pipeline-rb,28022,28.0,27.49,106,0,105
2,worker-pipe-rb,29418,29.4,28.83,174,106,67
2,worker-pipe+incr-rb,21176,21.2,20.59,174,117,0
3,no-pipeline,86055,86.1,72.46,1087,0,590
3,worker-pipe,87662,87.7,53.41,1676,1150,15
3,worker-pipe+incr,109580,109.6,82.51,1167,1165,0
3,no-pipeline-rb,28596,28.6,28.05,106,0,105
3,worker-pipe-rb,29962,30.0,29.38,174,106,67
3,worker-pipe+incr-rb,21503,21.5,21.01,174,117,0
4,no-pipeline,87759,87.8,71.19,1087,0,590
4,worker-pipe,85072,85.1,55.23,1676,1150,15
4,worker-pipe+incr,110241,110.2,82.63,1167,1165,0
4,no-pipeline-rb,28258,28.3,27.69,106,0,105
4,worker-pipe-rb,28717,28.7,28.20,174,106,67
4,worker-pipe+incr-rb,21360,21.4,20.85,174,117,0
5,no-pipeline,86292,86.3,70.73,1087,0,590
5,worker-pipe,86607,86.6,53.24,1676,1150,15
5,worker-pipe+incr,106365,106.4,80.83,1167,1165,0
5,no-pipeline-rb,28515,28.5,27.96,106,0,105
5,worker-pipe-rb,28888,28.9,28.05,174,106,67
5,worker-pipe+incr-rb,21467,21.5,20.93,174,117,0
```

---

## Cold Build Summary (iters 2–5, stable)

| Config | Mean wall (s) | Mean crit path (s) | Overhead (wall - crit) | vs no-pipeline | Actions | Workers | Sandbox |
|---|---|---|---|---|---|---|---|
| `no-pipeline` | 86.8 | 71.6 | 15.2s | — | ~1087 | 0 | 590 |
| `worker-pipe` | 84.8 | 53.6 | 31.2s | **1.02× faster** | ~1676 | 1150 | 15 |
| `worker-pipe+incr` | 109.0 | 82.0 | 27.0s | 0.80× (26% slower) | ~1167 | 1165 | 0 |

## Warm Rebuild Summary

| Config | Iter 1 (s) | Mean iters 2–5 (s) | Actions | Workers |
|---|---|---|---|---|
| `no-pipeline-rb` | 26.4 | 28.4 | 106 | 0 |
| `worker-pipe-rb` | 27.6 | 29.2 | 174 | 106 |
| `worker-pipe+incr-rb` | **4.3** | 21.4 | 64/174 | 7/117 |

---

## Analysis

### Multiplex sandboxing eliminates the wall-time benefit of worker pipelining

The headline finding: **worker-pipe is only 2.3% faster than no-pipeline** (84.8s vs 86.8s). The
critical path is 25% shorter (53.6s vs 71.6s), confirming that pipelining works — downstream crates
start earlier. But the Bazel overhead doubles: 31.2s for worker-pipe vs 15.2s for no-pipeline.

The overhead comes from `--experimental_worker_multiplex_sandboxing`, which creates a per-request
sandbox directory, stages inputs via hardlinks/symlinks into a worker-owned execroot
(`_pw_state/pipeline/<key>/`), and copies outputs back after completion. With 1150 worker requests,
this I/O adds up.

### Comparison with previous unsandboxed benchmark (2026-03-06, Bazel 8.4.2)

| Config | Old wall (s) | New wall (s) | Old overhead | New overhead |
|---|---|---|---|---|
| `no-pipeline` | 102.7 | 86.8 | 20.5s | 15.2s |
| `worker-pipe` | 63.5 | 84.8 | 20.9s | 31.2s |
| `worker-pipe+incr` | 100.8 | 109.0 | 19.0s | 27.0s |

The no-pipeline baseline improved 15.5% (Bazel 9 vs 8.4.2). Worker-pipe regressed 33.5% due to
sandboxing overhead. The old unsandboxed worker-pipe was **1.62× faster** than its baseline;
the new sandboxed version is only **1.02× faster**.

### Incremental rebuild remains the star

`worker-pipe+incr-rb` iteration 1 at **4.3s** (vs 13.8s in the old benchmark) is a 3.2× improvement.
This is the CGU fix (`-Ccodegen-units=16`) from the previous analysis working as expected: incremental
codegen with 16 CGUs instead of 256 eliminates the overhead that was masking the incremental benefit.

### Rebuild pipelining shows no benefit with sandboxing

`worker-pipe-rb` (29.2s) is slightly slower than `no-pipeline-rb` (28.4s). For small rebuilds
(~27 crates), the sandboxing overhead per-action dominates any pipelining benefit. Without
sandboxing, the old benchmark showed worker-pipe-rb at 27.9s vs no-pipeline-rb at 30.4s (8% faster).

---

## Recommendations

### Do NOT enable `--experimental_worker_multiplex_sandboxing` for performance

The per-request sandboxing overhead (input staging, output copying) negates the pipelining speedup.
Worker pipelining's critical-path reduction only translates to wall-time improvement when the
per-action overhead is low — which unsandboxed multiplex workers achieve but sandboxed ones do not.

### Updated strategy recommendation

| Use case | Recommended config |
|---|---|
| CI / performance-sensitive builds | `worker-pipe` **without** `--experimental_worker_multiplex_sandboxing` |
| Hermetic / security-sensitive builds | `worker-pipe` **with** `--experimental_worker_multiplex_sandboxing` (accept ~30% overhead) |
| Local development (frequent rebuilds) | `worker-pipe` + `experimental_incremental=true` (without multiplex sandboxing) |

On Bazel 9+, no `--strategy` flags are needed — Bazel auto-selects the multiplex worker from
`supports-multiplex-workers` in exec_reqs. Use `--strategy=Rustc=worker,sandboxed` on Bazel 8
as fallback (the `sandboxed` fallback is only used when the worker strategy is unavailable, which
is not the sandboxing-overhead case measured here).

### Future optimization opportunities

The sandboxing overhead is dominated by input staging (hardlinking/symlinking ~1000+ files per
request into `_pw_state/pipeline/<key>/execroot/`). Potential improvements:
1. **Shared read-only layer:** Instead of staging inputs per-request, use a single symlink tree
   updated incrementally, with per-request output directories only.
2. **Lazy input resolution:** Only stage inputs that rustc actually reads (use strace/seccomp to
   detect), rather than all declared inputs.
3. **Skip staging for non-pipelined requests:** Only pipeline requests (metadata+full pairs) need
   persistent execroots. Non-pipelined requests could use `current_dir(sandbox_dir)` directly.

---

## Benchmark Improvements Applied

Compared to the 2026-03-06 benchmark:
1. **Bazel 9.0.0** (was Bazel 8.4.2)
2. **Multiplex sandboxing enabled** (`--experimental_worker_multiplex_sandboxing`)
3. **Sandboxed fallback** (`worker,sandboxed` instead of `worker,local`)
4. **RustcMetadata strategy** added (`--strategy=RustcMetadata=worker,sandboxed`)
5. **CGU fix** (`-Ccodegen-units=16` with incremental) from prior analysis

## Remaining improvements needed

The `worker-pipe+incr-rb` result is only valid for iteration 1 (same issue as previous benchmark).
Fix the benchmark script to avoid clearing incremental cache between rebuild primes.

---

## 2026-03-10 Focused Follow-up: `//zm_cli:zm_cli_lib`

To separate SDK-level cache effects from actual worker sandbox cost, a colder Rust-heavy target
in the `//sdk` graph was measured with remote cache hits disabled:

| Config | Wall (s) | Crit path (s) | Actions | Workers | Sandbox |
|---|---|---|---|---|---|
| `worker-pipe` | 69.6 | 43.34 | 746 | 736 | 9 |
| `no-pipeline` | 115.0 | 75.91 | 927 | 0 | 912 |

For the `worker-pipe` run, pipeline logs from 280 metadata actions show:

- `stage_ms`: 55.4s total, 197.9ms average per action, p90 392ms, p99 1083ms
- `setup_ms`: 56.1s total, effectively identical to `stage_ms`
- metadata output materialization: 29ms total, all via hardlinks, zero copies
- staged inputs: 295,571 declared inputs, all preserved as symlinks, zero file copies

This narrows the remaining problem:

- On a real cold Rust-heavy target, sandboxed worker pipelining still clearly helps.
- The dominant residual overhead is staged-input setup, even when it is entirely symlink-based.
- Output copying is not the bottleneck for the safe path.

So the next safe optimization direction is staged-execroot reuse or narrower input staging, not
further output materialization work.

---

## 2026-03-10 Profile Follow-up: `//sdk/sdk_builder:sdk_builder_lib`

To check whether the `//sdk` slowdown was mostly top-level packaging or a broader graph issue, I
profiled `//sdk/sdk_builder:sdk_builder_lib` with Bazel profiles in both modes.

Profiled comparison:

| Config | Wall (s) | Crit path (s) | Processes |
|---|---|---|---|
| `no-pipeline` | 19.4 | 12.25 | 231 `linux-sandbox` |
| `worker-pipe` | 23.0 | 14.03 | 228 `worker`, 4 `linux-sandbox` |

Key findings:

- The slowdown is **not** primarily a top-level packaging/linking issue. In both profiles, the
  critical path ends in Rust compilation work, not a final binary/packaging action.
- The worker profile shows a large new bucket in worker setup:
  - `worker_preparing`: 91.8s total across 199 events, 461ms average
  - `worker_working`: 71.6s total across 126 events, 568ms average
- `ACTION_EXECUTION` grows from 116.1s to 191.2s summed across threads, while analysis/load phases
  only increase modestly.
- The process_wrapper pipeline logs for the same run show setup time is almost entirely input
  staging:
  - 226 metadata actions
  - `stage_ms`: 29.9s total, 132ms average, p90 238ms
  - `setup_ms`: 30.4s total, 134ms average
  - sandbox symlink seeding: 4ms total
  - worker entry seeding: 35ms total
  - output materialization remains negligible

Interpretation:

- `sdk_builder_lib` is a genuine mixed-graph regression case for sandboxed `worker-pipe`, not a
  misleading artifact of the final `//sdk` action.
- The dominant loss is still pre-execution setup in the pipelined worker path, especially staged
  input construction.
- On this target, pipelining does not recover that cost through a shorter critical path; the
  critical path is slightly worse under sandboxed `worker-pipe`.
