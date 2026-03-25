#!/usr/bin/env bash
# Benchmark multiplex-sandboxed worker pipelining across a worker-topology matrix.
#
# Default behavior follows thoughts/shared/plans/2026-03-25-consolidated-worker-pipelining-plan.md:
# - target: //sdk/sdk_builder:sdk_builder_lib
# - 1 warmup + 2 measured iterations
# - sweep worker_max_instances=1,2,4
# - sweep worker_max_multiplex_instances=8,12,16
#
# Outputs:
# - CSV on stdout
# - per-run Bazel logs/profiles under --output-dir
#
# Notes:
# - Successful pipelined builds delete per-pipeline pipeline.log files, so the benchmark prefers
#   worker-owned _pw_state/metrics.log aggregates when available. Slot reuse metrics are derived
#   from persistent stage-slot manifests.

set -euo pipefail

BAZEL="${BAZEL:-bazel}"
REPO="${REPO:-/var/mnt/dev/reactor-repo-2}"
TARGETS="${TARGETS:-//sdk/sdk_builder:sdk_builder_lib}"
ITERS="${ITERS:-2}"
WARMUPS="${WARMUPS:-1}"
MAX_INSTANCES="${MAX_INSTANCES:-1 2 4}"
MULTIPLEX_VALUES="${MULTIPLEX_VALUES:-8 12 16}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/multiplex_sandbox_overhead_$(date +%Y%m%d_%H%M%S)}"
RUN_ID="$(date +%s)"

usage() {
    cat <<'EOF'
Usage:
  bench_multiplex_sandbox_overhead.sh [options]

Options:
  --repo PATH                 Repo to benchmark (default: /var/mnt/dev/reactor-repo-2)
  --targets "T1 T2"           Space-separated Bazel targets
  --iters N                   Measured iterations per config (default: 2)
  --warmups N                 Warmup iterations per config (default: 1)
  --max-instances "1 2 4"     Sweep values for --worker_max_instances=Rustc=
  --multiplex "8 12 16"       Sweep values for --worker_max_multiplex_instances=Rustc=
  --output-dir DIR            Where logs/profiles/results are written
  --help                      Show this help

Environment variables with the same names are also honored.
EOF
}

log() {
    echo "[bench] $*" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO="$2"
            shift 2
            ;;
        --targets)
            TARGETS="$2"
            shift 2
            ;;
        --iters)
            ITERS="$2"
            shift 2
            ;;
        --warmups)
            WARMUPS="$2"
            shift 2
            ;;
        --max-instances)
            MAX_INSTANCES="$2"
            shift 2
            ;;
        --multiplex)
            MULTIPLEX_VALUES="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

WORKER_PIPE_FLAGS=(
    "--@rules_rust//rust/settings:pipelined_compilation=true"
    "--@rules_rust//rust/settings:experimental_worker_pipelining=true"
    "--experimental_worker_multiplex_sandboxing"
    "--strategy=Rustc=worker,sandboxed"
    "--strategy=RustcMetadata=worker,sandboxed"
)

run_label() {
    local target="$1" max_instances="$2" multiplex="$3" phase="$4" iter="$5"
    local target_id
    target_id=$(echo "$target" | tr '/:+' '_' | tr -s '_' | sed 's/^_//; s/_$//')
    echo "${target_id}_mi${max_instances}_mx${multiplex}_${phase}${iter}"
}

prepare_repo_state() {
    local target="$1"
    cd "$REPO"
    "$BAZEL" shutdown >/dev/null 2>&1 || true
    "$BAZEL" clean --expunge >/dev/null 2>&1 || true
    # Recreate the Bazel server and discover fresh paths for this run.
    EXECROOT=$("$BAZEL" info execution_root 2>/dev/null)
    OUTPUT_BASE=$("$BAZEL" info output_base 2>/dev/null)
    BAZEL_WORKERS_DIR="$OUTPUT_BASE/bazel-workers"
    rm -rf "$BAZEL_WORKERS_DIR" "$EXECROOT/_pw_state"
    mkdir -p "$BAZEL_WORKERS_DIR"
    CURRENT_TARGET="$target"
}

## PID sampling — runs pgrep in a background loop during builds to count
## distinct OS processes vs distinct Bazel worker directories.
PID_SAMPLE_FILE=""
PID_SAMPLER_PID=""

start_pid_sampler() {
    PID_SAMPLE_FILE="$OUTPUT_DIR/${1}_pids.txt"
    : > "$PID_SAMPLE_FILE"
    (
        while true; do
            pgrep -f 'process_wrapper.*persistent_worker' >> "$PID_SAMPLE_FILE" 2>/dev/null || true
            sleep 0.5
        done
    ) &
    PID_SAMPLER_PID=$!
}

stop_pid_sampler() {
    if [[ -n "$PID_SAMPLER_PID" ]]; then
        kill "$PID_SAMPLER_PID" 2>/dev/null || true
        wait "$PID_SAMPLER_PID" 2>/dev/null || true
        PID_SAMPLER_PID=""
    fi
    if [[ -n "$PID_SAMPLE_FILE" && -f "$PID_SAMPLE_FILE" ]]; then
        local distinct
        distinct=$(sort -u "$PID_SAMPLE_FILE" | grep -c . || echo 0)
        LAST_DISTINCT_PIDS="$distinct"
        log "distinct_pids=$distinct (from pgrep sampling)"
    else
        LAST_DISTINCT_PIDS=""
    fi
}

build_with_profile() {
    local target="$1" max_instances="$2" multiplex="$3" phase="$4" iter="$5"
    local label log_file profile_file rust_cfg
    label=$(run_label "$target" "$max_instances" "$multiplex" "$phase" "$iter")
    log_file="$OUTPUT_DIR/${label}.log"
    profile_file="$OUTPUT_DIR/${label}.profile.gz"
    rust_cfg="bench_multiplex_${RUN_ID}_${label}"

    LAST_LABEL="$label"
    LAST_LOG_FILE="$log_file"
    LAST_PROFILE_FILE="$profile_file"
    LAST_DISTINCT_PIDS=""

    log "run=$label target=$target"
    start_pid_sampler "$label"
    local start_ns end_ns
    start_ns=$(date +%s%N)
    (
        cd "$REPO"
        "$BAZEL" build "$target" \
            "${WORKER_PIPE_FLAGS[@]}" \
            "--@rules_rust//rust/settings:extra_rustc_flag=--cfg=${rust_cfg}" \
            "--worker_max_instances=Rustc=${max_instances}" \
            "--worker_max_multiplex_instances=Rustc=${multiplex}" \
            "--profile=${profile_file}"
    ) 2>&1 | tee "$log_file" >/dev/null
    end_ns=$(date +%s%N)
    stop_pid_sampler
    LAST_WALL_MS=$(( (end_ns - start_ns) / 1000000 ))
}

extract_basic_metrics() {
    local log_file="$1"
    python3 - "$log_file" "$LAST_WALL_MS" <<'PY'
import pathlib
import re
import sys

log_path = pathlib.Path(sys.argv[1])
wall_ms = sys.argv[2]
text = log_path.read_text(errors="replace") if log_path.exists() else ""

def pick(pattern, default=""):
    matches = re.findall(pattern, text, flags=re.MULTILINE)
    return matches[-1] if matches else default

crit_s = pick(r"Critical Path:\s*([0-9.]+)")
total_actions = pick(r"([0-9]+)\s+total actions")
worker_count = pick(r"([0-9]+)\s+worker\b")
sandbox_count = pick(r"([0-9]+)\s+linux-sandbox\b")
print("|".join([wall_ms, crit_s, total_actions, worker_count, sandbox_count]))
PY
}

extract_profile_metrics() {
    local profile_file="$1"
    local raw summary
    raw=$(cd /tmp && "$BAZEL" analyze-profile --dump=raw "$profile_file" 2>/dev/null || true)
    summary=$(cd /tmp && "$BAZEL" analyze-profile "$profile_file" 2>/dev/null || true)
    python3 - <<'PY' "$raw" "$summary"
import re
import sys

raw = sys.argv[1]
summary = sys.argv[2]

def parse_summary(text, key):
    for line in text.splitlines():
        lower = line.lower()
        if key not in lower:
            continue
        total = ""
        count = ""
        avg = ""
        m_total = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*s", line)
        if m_total:
            total = m_total.group(1)
        m_count = re.search(r"([0-9]+)\s+(?:events|actions|spawns)", line, flags=re.I)
        if m_count:
            count = m_count.group(1)
        m_avg = re.search(r"([0-9]+(?:\.[0-9]+)?)\s*ms", line, flags=re.I)
        if m_avg:
            avg = m_avg.group(1)
        if total or count or avg:
            return total, count, avg
    return "", "", ""

def parse_raw(text, key):
    total_ms = 0.0
    count = 0
    for line in text.splitlines():
        lower = line.lower()
        if key not in lower:
            continue
        count += 1
        m_ms = re.search(r"\b([0-9]+(?:\.[0-9]+)?)ms\b", lower)
        if m_ms:
            total_ms += float(m_ms.group(1))
            continue
        m_us = re.search(r"\b([0-9]+(?:\.[0-9]+)?)us\b", lower)
        if m_us:
            total_ms += float(m_us.group(1)) / 1000.0
            continue
        m_ns = re.search(r"\b([0-9]+(?:\.[0-9]+)?)ns\b", lower)
        if m_ns:
            total_ms += float(m_ns.group(1)) / 1_000_000.0
            continue
        m_s = re.search(r"\b([0-9]+(?:\.[0-9]+)?)s\b", lower)
        if m_s:
            total_ms += float(m_s.group(1)) * 1000.0
    if count and total_ms:
        return f"{total_ms / 1000.0:.3f}", str(count), f"{total_ms / count:.1f}"
    return "", "", ""

prep = parse_summary(summary, "worker_preparing")
work = parse_summary(summary, "worker_working")
if not any(prep):
    prep = parse_raw(raw, "worker_preparing")
if not any(work):
    work = parse_raw(raw, "worker_working")
if not any(prep):
    prep = parse_summary(summary, "worker setup")
if not any(work):
    work = parse_summary(summary, "worker working")

print("|".join([
    prep[0], prep[1], prep[2],
    work[0], work[1], work[2],
]))
PY
}

extract_worker_fs_metrics() {
    local workers_dir="$1"
    python3 - "$workers_dir" <<'PY'
import json
import pathlib
import statistics
import sys
from collections import Counter

workers_dir = pathlib.Path(sys.argv[1])
distinct_workers = set()
reuse_values = []
pipeline_logs = []
metrics_logs = []

if workers_dir.exists():
    for path in workers_dir.rglob("*"):
        if path.is_dir() and path.name.endswith("-workdir") and "Rustc" in path.name:
            distinct_workers.add(str(path))
    for manifest in workers_dir.rglob("manifest.json"):
        if "_pw_state/stage_pool/" not in manifest.as_posix():
            continue
        try:
            data = json.loads(manifest.read_text())
        except Exception:
            continue
        reuse_values.append(int(data.get("reuse_count", 0)))
    for log in workers_dir.rglob("pipeline.log"):
        if "/_pw_state/pipeline/" in log.as_posix():
            pipeline_logs.append(log)
    for log in workers_dir.rglob("metrics.log"):
        if "/_pw_state/metrics.log" in log.as_posix():
            metrics_logs.append(log)

reuse_gt1 = sum(1 for value in reuse_values if value > 1)
max_reuse = max(reuse_values) if reuse_values else 0
hist = Counter(reuse_values)
reuse_hist = ";".join(f"{k}:{hist[k]}" for k in sorted(hist)) if hist else ""

setup_values = []
stage_values = []
stage_io_values = []
declared_input_values = []
metadata_actions = 0
source_logs = metrics_logs if metrics_logs else pipeline_logs
for log in source_logs:
    try:
        lines = log.read_text(errors="replace").splitlines()
    except Exception:
        continue
    for line in lines:
        if not line.startswith("staging "):
            continue
        metadata_actions += 1
        setup = ""
        stage = ""
        stage_io = ""
        declared_inputs = ""
        for token in line.split():
            if token.startswith("total_setup_ms="):
                setup = token.split("=", 1)[1]
            elif token.startswith("diff_ms="):
                stage = token.split("=", 1)[1]
            elif token.startswith("inputs_ms="):
                stage = token.split("=", 1)[1]
            elif token.startswith("stage_io_ms="):
                stage_io = token.split("=", 1)[1]
            elif token.startswith("declared_inputs="):
                declared_inputs = token.split("=", 1)[1]
        if setup:
            try:
                setup_values.append(float(setup))
            except ValueError:
                pass
        if stage:
            try:
                stage_values.append(float(stage))
            except ValueError:
                pass
        if stage_io:
            try:
                stage_io_values.append(float(stage_io))
            except ValueError:
                pass
        if declared_inputs:
            try:
                declared_input_values.append(float(declared_inputs))
            except ValueError:
                pass

def fmt_avg(values):
    if not values:
        return ""
    return f"{statistics.fmean(values):.1f}"

def fmt_p90(values):
    if not values:
        return ""
    ordered = sorted(values)
    idx = max(0, min(len(ordered) - 1, int((len(ordered) - 1) * 0.9)))
    return f"{ordered[idx]:.1f}"

print("|".join([
    str(len(distinct_workers)),
    str(metadata_actions if metadata_actions else ""),
    fmt_avg(setup_values),
    fmt_p90(setup_values),
    fmt_avg(stage_values),
    fmt_avg(stage_io_values),
    fmt_avg(declared_input_values),
    (f"{statistics.fmean(setup_values) / statistics.fmean(declared_input_values):.3f}"
     if setup_values and declared_input_values and statistics.fmean(declared_input_values) > 0
     else ""),
    str(reuse_gt1 if reuse_values else ""),
    str(max_reuse if reuse_values else ""),
    reuse_hist,
    "metrics" if metrics_logs else ("pipeline" if pipeline_logs else "no"),
]))
PY
}

emit_csv_row() {
    local target="$1" max_instances="$2" multiplex="$3" iter="$4" phase="$5"
    local basic profile fs
    basic=$(extract_basic_metrics "$LAST_LOG_FILE")
    IFS='|' read -r wall_ms crit_s total_actions worker_count sandbox_count <<<"$basic"

    profile=$(extract_profile_metrics "$LAST_PROFILE_FILE")
    IFS='|' read -r worker_preparing_s worker_preparing_events worker_preparing_avg_ms \
        worker_working_s worker_working_events worker_working_avg_ms <<<"$profile"

    fs=$(extract_worker_fs_metrics "$BAZEL_WORKERS_DIR")
    IFS='|' read -r distinct_workers metadata_actions avg_setup_ms p90_setup_ms avg_stage_ms \
        avg_stage_io_ms avg_declared_inputs avg_setup_per_input_ms slot_reuse_gt1 \
        max_reuse_count reuse_hist pipeline_logs_present <<<"$fs"

    local notes=""
    if [[ "$pipeline_logs_present" == "no" ]]; then
        notes="worker_metrics_unavailable"
    elif [[ "$pipeline_logs_present" == "pipeline" ]]; then
        notes="worker_metrics_fell_back_to_pipeline_logs"
    fi
    if [[ -n "$reuse_hist" ]]; then
        if [[ -n "$notes" ]]; then
            notes="${notes};"
        fi
        notes="${notes}reuse_hist=${reuse_hist}"
    fi
    if [[ -n "$worker_preparing_events" ]]; then
        if [[ -n "$notes" ]]; then
            notes="${notes};"
        fi
        notes="${notes}worker_preparing_events=${worker_preparing_events}"
    fi
    if [[ -n "$worker_working_events" ]]; then
        if [[ -n "$notes" ]]; then
            notes="${notes};"
        fi
        notes="${notes}worker_working_events=${worker_working_events}"
    fi

    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$target" \
        "$max_instances" \
        "$multiplex" \
        "$iter" \
        "$phase" \
        "$wall_ms" \
        "$crit_s" \
        "$worker_preparing_s" \
        "$worker_working_s" \
        "$distinct_workers" \
        "$LAST_DISTINCT_PIDS" \
        "$metadata_actions" \
        "$avg_setup_ms" \
        "$p90_setup_ms" \
        "$avg_stage_ms" \
        "$avg_stage_io_ms" \
        "$avg_declared_inputs" \
        "$avg_setup_per_input_ms" \
        "$slot_reuse_gt1" \
        "$max_reuse_count" \
        "$total_actions" \
        "$worker_count" \
        "$sandbox_count" \
        "$notes"
}

RESULTS_CSV="$OUTPUT_DIR/results.csv"
CSV_HEADER="target,max_instances,multiplex,iter,phase,wall_ms,crit_s,worker_preparing_s,worker_working_s,distinct_workers,distinct_pids,metadata_actions,avg_setup_ms,p90_setup_ms,avg_stage_ms,avg_stage_io_ms,avg_declared_inputs,avg_setup_per_input_ms,slot_reuse_gt1,max_reuse_count,total_actions,worker_count,sandbox_count,notes"
echo "$CSV_HEADER" | tee "$RESULTS_CSV"

for target in $TARGETS; do
    for max_instances in $MAX_INSTANCES; do
        for multiplex in $MULTIPLEX_VALUES; do
            log "=== target=$target max_instances=$max_instances multiplex=$multiplex ==="

            for warmup_iter in $(seq 1 "$WARMUPS"); do
                prepare_repo_state "$target"
                build_with_profile "$target" "$max_instances" "$multiplex" "warmup" "$warmup_iter"
                log "warmup completed: $LAST_LABEL"
            done

            for iter in $(seq 1 "$ITERS"); do
                prepare_repo_state "$target"
                build_with_profile "$target" "$max_instances" "$multiplex" "measured" "$iter"
                emit_csv_row "$target" "$max_instances" "$multiplex" "$iter" "measured" \
                    | tee -a "$RESULTS_CSV"
            done
        done
    done
done

# Aggregate all PID sample files into a single distinct_pids.txt summary
DISTINCT_PIDS_FILE="$OUTPUT_DIR/distinct_pids.txt"
{
    echo "# Distinct PIDs observed across all benchmark runs"
    echo "# Generated: $(date -Iseconds)"
    for pid_file in "$OUTPUT_DIR"/*_pids.txt; do
        [[ -f "$pid_file" ]] || continue
        label=$(basename "$pid_file" _pids.txt)
        distinct=$(sort -u "$pid_file" | grep -c . || echo 0)
        echo "$label: $distinct distinct PIDs"
    done
} > "$DISTINCT_PIDS_FILE"
log "distinct PID summary written to $DISTINCT_PIDS_FILE"

log "results written to $RESULTS_CSV"
