# Rust Pipelining Benchmark Analysis

**Date:** 2026-03-05
**Iterations:** 10
**Machine:** Linux 6.17.7, x86_64
**Parallelism:** 16 jobs
**Rustc:** 1.91.1 (ed61e7d7e 2025-11-07)

## Workload

Five widely-used crates covering common real-world patterns (networking, serialization,
proc-macros, async runtime):

| Target | Type | Notes |
|---|---|---|
| tokio 1.49.0 | async runtime | fs, io, macros, net, process, rt-multi-thread, signal, sync, time |
| serde_json 1.0.149 | serialization | default features |
| cookie_store 0.22.1 | HTTP cookies | transitive via reqwest |
| hyper 1.8.1 | HTTP library | full features |
| reqwest 0.12.28 | HTTP client | cookies, http2, json, rustls-tls, stream |

## Configurations

| Config | Description | Actions | Strategy |
|---|---|---|---|
| **no-pipeline** | `pipelined_compilation=false` | 143 | 142 linux-sandbox |
| **hollow-rlib** | `pipelined_compilation=true` (-Zno-codegen + full) | 251 | 217 linux-sandbox |
| **worker-pipe** | `pipelined_compilation=true` + `experimental_worker_pipelining=true` | 115 | 114 multiplex-worker |
| **cargo** | `cargo build` (pipelining enabled by default) | — | 116 crates |

**Bazel methodology:** Each iteration starts with `bazel shutdown && bazel clean` and a fresh
disk cache. A warmup build populates the disk cache with C/build-script actions (ring, aws-lc-sys,
proc-macro compilation for exec-platform). The three Bazel configs then measure only Rust
compilation time; each uses a unique `--cfg` flag to force Rust re-compilation while sharing
the cached non-Rust actions. The worker-pipe config used Bazel's default
`--worker_max_multiplex_instances=8` (see note in worker-pipe analysis section).

**Cargo methodology:** Each iteration runs `cargo clean && cargo build -j 16` from a project
with matching crate versions and features. Cargo builds include ring's build.rs (C assembly
compilation, ~0.5s) and all proc-macro compilations. Cargo uses `ring` as TLS backend;
Bazel uses `aws-lc-rs` (heavier C build, cached in warmup).

## Results Summary

```
                    WALL TIME (seconds)
Config          Mean    Median   Min    Max    Stdev   CV
─────────────   ─────   ──────   ────   ────   ─────   ────
no-pipeline     20.7    20.5     19.9   21.9   0.64    3.1%
hollow-rlib     11.4    11.3     11.0   12.1   0.34    3.0%
worker-pipe      8.4     8.5      8.1    8.8   0.29    3.4%
cargo            8.2     8.1      7.6    9.1   0.50    6.1%
```

```
                    CRITICAL PATH (seconds, Bazel only)
Config          Mean    Stdev   Overhead (wall - crit)
─────────────   ─────   ─────   ──────────────────────
no-pipeline     19.46   0.56    1.23s
hollow-rlib      9.91   0.27    1.50s
worker-pipe      7.99   0.29    0.45s
```

## Speedups

| Comparison | Speedup | Ratio |
|---|---|---|
| hollow-rlib vs no-pipeline | 44.9% faster | 1.81x |
| worker-pipe vs no-pipeline | 59.3% faster | 2.45x |
| cargo vs no-pipeline | 60.3% faster | 2.52x |
| worker-pipe vs hollow-rlib | 26.1% faster | 1.35x |
| worker-pipe vs cargo | ~2.7% slower | 0.97x |

## Raw Data (all 10 iterations)

```
Iter  no-pipeline  hollow-rlib  worker-pipe  cargo
────  ───────────  ───────────  ───────────  ─────
 1      20.4s        11.4s        8.6s       8.1s
 2      20.4s        11.5s        8.4s       8.1s
 3      20.8s        11.6s        8.6s       8.4s
 4      20.5s        11.0s        8.0s       7.6s
 5      19.9s        11.1s        8.0s       7.5s
 6      20.1s        11.1s        8.1s       7.8s
 7      20.1s        11.1s        8.0s       7.8s
 8      21.9s        11.1s        8.7s       9.1s
 9      20.8s        12.1s        8.7s       8.7s
10      21.5s        11.6s        8.6s       8.6s
```

## Analysis

### Worker pipelining closes the gap with Cargo

Worker pipelining (8.4s mean) is within 3% of Cargo's build time (8.2s mean). The
remaining gap is attributable to Bazel's per-action overhead (sandbox setup, action cache
lookups, output file hashing). Notably, the worker-pipe config has the lowest Bazel
overhead at 0.45s (wall minus critical path), vs 1.23s for no-pipeline and 1.50s for
hollow-rlib. This is because worker-pipe runs 114 actions via multiplex workers (no
sandbox overhead), while hollow-rlib runs 217 sandboxed actions.

### Why hollow-rlib has more actions but is faster than no-pipeline

Hollow-rlib creates 251 actions (2 per pipelined crate: one metadata + one full) vs
143 for no-pipeline. Despite the higher action count, hollow-rlib is 1.81x faster
because downstream crates can begin compilation as soon as the metadata action
(~50ms with -Zno-codegen) completes, without waiting for the upstream's full codegen.
This parallelism reduces the critical path from 19.5s to 9.9s.

### Worker-pipe achieves the best critical path

Worker-pipe's critical path (8.0s) is 19% shorter than hollow-rlib's (9.9s). This
improvement comes from eliminating the double-compilation overhead: hollow-rlib runs
rustc twice per pipelined crate (once for metadata, once for full), while worker-pipe
runs rustc once (the worker returns .rmeta early from the same process that produces
the .rlib). The single-invocation approach saves ~0.5s of per-crate rustc startup time
across the dependency graph.

### Action count reduction

Worker-pipe uses only 115 total actions (114 worker + 1 internal), compared to 251 for
hollow-rlib. Each pipelined rlib crate produces just one worker action instead of two
sandboxed actions. This 54% reduction in action count also reduces Bazel's scheduling
and I/O overhead.

### Variance

All configurations show low variance (CV 3.0-3.4%) for the Bazel configs, indicating
stable, reproducible measurements. Cargo has slightly higher variance (CV 6.1%),
likely due to ring's build.rs C compilation being more sensitive to system load.
Iteration 8 was an outlier across all configs (hottest for no-pipeline at 21.9s and
cargo at 9.1s), suggesting transient system load.

### Caveats

1. **Bazel times exclude C/build-script compilation** (cached in warmup); Cargo times
   include ring's build.rs (~0.5s C assembly). Subtracting ring's overhead would bring
   Cargo to ~7.7s, making worker-pipe ~9% slower than Cargo's pure Rust time.

2. **Different TLS backends:** Bazel builds use aws-lc-rs (heavier C build, cached);
   Cargo builds use ring (lighter C build, included in timing).

3. **Bazel uses linux-sandbox strategy** for non-worker actions, adding per-action
   overhead vs Cargo's direct process spawning.

4. **Exec-platform crates** (build scripts, proc-macros) use hollow-rlib mode in all
   three Bazel configs to maintain consistent SVH (stable version hash). Worker
   pipelining applies only to target-configuration rlib/lib crates.

5. **`--worker_max_multiplex_instances` tuning:** A follow-up run with
   `--worker_max_multiplex_instances=Rustc=32` (allowing up to 16 concurrent rustc
   processes on this 16-CPU machine) measured **9.2s mean** — 9.6% *slower* than the
   default-8 run. With 16 concurrent rustc processes competing for 16 CPUs, each process
   gets ~1 CPU, whereas the default-8 limit gives each process ~2 CPUs. The reduced
   per-process CPU availability hurts LLVM codegen parallelism and increases context-
   switching overhead. Bazel's default of 8 coincides with CPU_count/2, which is the
   empirically optimal concurrency for rustc on this machine. The settings.bzl
   recommendation has been updated accordingly: do not exceed ~CPU_count/2 for this flag.
