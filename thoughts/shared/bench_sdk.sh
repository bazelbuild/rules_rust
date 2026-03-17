#!/usr/bin/env bash
# Benchmark pipelining configurations against reactor-repo-2 //sdk
#
# Usage:
#   ./bench_sdk.sh [ITERATIONS]
#
# Configs measured (cold builds — all Rust actions forced to cache-miss via --cfg):
#   no-pipeline           pipelined_compilation=false (baseline)
#   hollow-rlib           pipelined_compilation=true, no worker pipelining
#   worker-pipe-nosand    worker pipelining, no multiplex sandboxing
#   worker-pipe           worker pipelining, multiplex sandboxing
#   worker-pipe+incr      worker pipelining, multiplex sandboxing + incremental
#
# Configs measured (warm rebuilds — prime build then append a comment to lib/hash):
#   *-rb variants of each cold config
#
# No separate warmup needed: the disk cache at ../bazel-disk-cache is assumed
# to be warm from prior development builds. C/build-script/proc-macro actions
# are exec-configuration and unaffected by --extra_rustc_flag (target-config
# only), so they stay cached across all benchmark runs.
#
# Output: CSV to stdout, progress to stderr.

set -euo pipefail

REPO="/var/mnt/dev/reactor-repo-2"
TARGET="//sdk"
ITERS="${1:-5}"
RUN_ID=$(date +%s)

BAZEL="bazel"

# First-party crate to touch for rebuild tests.
# lib/hash has ~27 first-party rdeps in the //sdk dependency graph.
TOUCH_FILE="$REPO/lib/hash/src/lib.rs"

INCR_CACHE="/tmp/rules_rust_incremental"

# ── Config flag arrays ────────────────────────────────────────────────────────

NO_PIPE_FLAGS=(
    "--@rules_rust//rust/settings:pipelined_compilation=false"
    "--@rules_rust//rust/settings:experimental_worker_pipelining=false"
)

HOLLOW_RLIB_FLAGS=(
    "--@rules_rust//rust/settings:pipelined_compilation=true"
    "--@rules_rust//rust/settings:experimental_worker_pipelining=false"
)

WORKER_PIPE_NOSAND_FLAGS=(
    "--@rules_rust//rust/settings:pipelined_compilation=true"
    "--@rules_rust//rust/settings:experimental_worker_pipelining=true"
)

WORKER_PIPE_FLAGS=(
    "--@rules_rust//rust/settings:pipelined_compilation=true"
    "--@rules_rust//rust/settings:experimental_worker_pipelining=true"
    "--experimental_worker_multiplex_sandboxing"
    "--strategy=Rustc=worker,sandboxed"
    "--strategy=RustcMetadata=worker,sandboxed"
)

WORKER_PIPE_INCR_FLAGS=(
    "--@rules_rust//rust/settings:pipelined_compilation=true"
    "--@rules_rust//rust/settings:experimental_worker_pipelining=true"
    "--@rules_rust//rust/settings:experimental_incremental=true"
    "--experimental_worker_multiplex_sandboxing"
    "--strategy=Rustc=worker,sandboxed"
    "--strategy=RustcMetadata=worker,sandboxed"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

log() { echo "[bench] $*" >&2; }

cfg_flags() {
    case "$1" in
        no-pipeline)         printf '%s\n' "${NO_PIPE_FLAGS[@]}" ;;
        hollow-rlib)         printf '%s\n' "${HOLLOW_RLIB_FLAGS[@]}" ;;
        worker-pipe-nosand)  printf '%s\n' "${WORKER_PIPE_NOSAND_FLAGS[@]}" ;;
        worker-pipe)         printf '%s\n' "${WORKER_PIPE_FLAGS[@]}" ;;
        worker-pipe+incr)    printf '%s\n' "${WORKER_PIPE_INCR_FLAGS[@]}" ;;
        *) echo "unknown config: $1" >&2; exit 1 ;;
    esac
}

# cfg_to_id CFG → safe Rust identifier (no hyphens or plus signs)
cfg_to_id() {
    local s="${1//-/_}"   # hyphens → underscores
    s="${s//+/p}"         # plus → p
    echo "$s"
}

# timed_build LABEL CFG_RUSTFLAG [extra_flags...]
# Runs `bazel build $TARGET` and emits one CSV data row (no newline prefix):
#   wall_ms,wall_s,crit_s,total_actions,worker_count,sandbox_count
# Returns 1 on build failure.
timed_build() {
    local label="$1" cfg_flag="$2"
    shift 2
    local extra_flags=("$@")
    local outfile
    outfile=$(mktemp /tmp/bazel_bench_XXXXXX.txt)

    local start_ns end_ns
    start_ns=$(date +%s%N)

    cd "$REPO"
    if $BAZEL build "$TARGET" \
        --@rules_rust//rust/settings:extra_rustc_flag="--cfg=${cfg_flag}" \
        "${extra_flags[@]}" \
        2>&1 | tee "$outfile" >/dev/null; then
        :
    else
        log "ERROR: build failed (label=$label cfg=$cfg_flag)"
        cat "$outfile" | grep -E 'ERROR:|FAILED' | head -5 >&2 || true
        rm -f "$outfile"
        return 1
    fi

    end_ns=$(date +%s%N)
    local wall_ms=$(( (end_ns - start_ns) / 1000000 ))

    local crit_s total_actions workers sandboxes
    crit_s=$(grep -oP 'Critical Path: \K[\d.]+' "$outfile" | tail -1 || echo "0")
    total_actions=$(grep -oP '\K\d+(?= total actions)' "$outfile" | tail -1 || echo "0")
    workers=$(grep -oP '\K\d+(?= worker)' "$outfile" | head -1 || echo "0")
    sandboxes=$(grep -oP '\K\d+(?= linux-sandbox)' "$outfile" | head -1 || echo "0")
    rm -f "$outfile"

    local wall_s
    wall_s=$(awk "BEGIN{printf \"%.1f\", $wall_ms/1000}")
    echo "$wall_ms,$wall_s,$crit_s,$total_actions,$workers,$sandboxes"
}

# ── CSV header ────────────────────────────────────────────────────────────────

echo "iter,config,wall_ms,wall_s,crit_s,total_actions,worker_count,sandbox_count"

# ── Main loop ─────────────────────────────────────────────────────────────────

for iter in $(seq 1 "$ITERS"); do
    log "=== Iteration $iter / $ITERS ==="

    # ── Cold builds ──────────────────────────────────────────────────────────
    # Each cold build:
    #   - Shuts down the Bazel server (clears in-memory action cache, stops workers)
    #   - Clears the incremental rustc cache so no prior state exists
    #   - Uses a unique --cfg key (iter + run_id) to force all target-config Rust
    #     actions to be disk-cache misses; exec-config actions (C, build scripts,
    #     proc-macros) are unaffected and stay cached

    rm -rf "$INCR_CACHE"

    for cfg in no-pipeline hollow-rlib worker-pipe-nosand worker-pipe worker-pipe+incr; do
        log "  [cold] $cfg"
        $BAZEL shutdown >/dev/null 2>&1 || true

        mapfile -t flags < <(cfg_flags "$cfg")
        id=$(cfg_to_id "$cfg")
        cfg_flag="bench_cold_${id}_i${iter}_r${RUN_ID}"

        if row=$(timed_build "cold/$cfg" "$cfg_flag" "${flags[@]}"); then
            echo "$iter,$cfg,$row"
        else
            echo "$iter,$cfg,FAILED,,,,"
        fi
    done

    # ── Warm rebuilds ────────────────────────────────────────────────────────
    # For each config:
    #   1. Shutdown (do NOT clear incremental cache — the stable prime key's
    #      incremental state written in iter 1 must persist for iter 2+, because
    #      in iter 2+ the prime hits the Bazel disk cache and rustc doesn't run)
    #   2. Prime build with a stable --cfg (iter 1: full Rust build; iter 2+:
    #      all disk-cache hits, incremental state from iter 1 persists on disk)
    #   3. Append a comment to lib/hash/src/lib.rs to change its content digest
    #   4. Rebuild immediately (no server shutdown — Bazel in-memory cache intact,
    #      only lib/hash and its ~27 rdeps are re-run; incremental state valid
    #      because the stable key hasn't changed between prime runs)
    #   5. Revert file via git

    for cfg in no-pipeline hollow-rlib worker-pipe-nosand worker-pipe worker-pipe+incr; do
        rb_cfg="${cfg}-rb"
        log "  [rebuild] $rb_cfg"

        $BAZEL shutdown >/dev/null 2>&1 || true
        # Do NOT rm -rf $INCR_CACHE here: incremental state for the stable prime
        # key must survive across iterations. The cold builds above use unique
        # --cfg keys and write to different incremental session subdirs, so they
        # don't interfere with the stable prime key's incremental state.

        mapfile -t flags < <(cfg_flags "$cfg")
        id=$(cfg_to_id "$cfg")
        # stable key: same across iterations so the prime hits disk cache on iter 2+
        prime_flag="bench_prime_${id}"

        log "    priming..."
        cd "$REPO"
        if ! $BAZEL build "$TARGET" \
            --@rules_rust//rust/settings:extra_rustc_flag="--cfg=${prime_flag}" \
            "${flags[@]}" \
            2>&1 | tail -2 >&2; then
            log "    prime FAILED, skipping rebuild"
            echo "$iter,$rb_cfg,FAILED,,,,"
            continue
        fi

        # Modify lib/hash to change its content digest
        echo "// bench-rebuild-${RUN_ID}-i${iter}" >> "$TOUCH_FILE"
        log "    modified $TOUCH_FILE"

        # Rebuild (no shutdown — in-memory cache preserved)
        if row=$(timed_build "rebuild/$cfg" "$prime_flag" "${flags[@]}"); then
            echo "$iter,$rb_cfg,$row"
        else
            echo "$iter,$rb_cfg,FAILED,,,,"
        fi

        # Revert
        cd "$REPO" && git checkout -- "$TOUCH_FILE"
        log "    reverted $TOUCH_FILE"
    done

    log "  iteration $iter done."
done

log "Benchmark complete."
