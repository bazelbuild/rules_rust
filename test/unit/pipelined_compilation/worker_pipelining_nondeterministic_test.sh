#!/usr/bin/env bash
# End-to-end test: worker pipelining produces consistent builds with
# non-deterministic proc macros.
#
# The svh_mismatch target graph uses a proc macro that iterates a HashMap
# (non-deterministic across process invocations). With two-invocation
# pipelining approaches, each crate can be compiled twice in separate rustc
# processes, risking SVH mismatch (E0460). With worker pipelining, each crate
# is compiled by a single rustc invocation, so SVH is always consistent.
#
# This test verifies that both worker-pipelined and non-pipelined builds
# of the nondeterministic proc macro target graph always succeed across
# multiple iterations.
#
# Tagged manual + local because it invokes Bazel (Bazel-in-Bazel).
set -euo pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  >&2 echo "This script should be run under Bazel (bazel test)"
  exit 1
fi

cd "${BUILD_WORKSPACE_DIRECTORY}"

TARGET="//test/unit/pipelined_compilation:svh_mismatch_test"
ITERATIONS="${WORKER_PIPELINING_TEST_ITERATIONS:-5}"

echo "=== Worker Pipelining Non-Deterministic Proc Macro Test ==="
echo "Target: ${TARGET}"
echo "Iterations: ${ITERATIONS}"
echo ""

# ---------------------------------------------------------------------------
# Phase 1: Worker-pipelined builds (must always succeed)
#
# Worker pipelining uses a single rustc invocation per crate. The metadata
# action spawns rustc, returns as soon as .rmeta is ready, and the full
# action waits for the same rustc to finish. Since the proc macro only runs
# once, SVH is always consistent.
#
# Uses --strategy=Rustc=worker,local: library crates use worker (pipelined),
# binary/test targets fall back to local (they don't support workers).
# ---------------------------------------------------------------------------
echo "--- Phase 1: Worker-pipelined builds ---"
WORKER_PASS=0
WORKER_FAIL=0

for i in $(seq 1 "$ITERATIONS"); do
  echo -n "  worker-pipelined build ${i}/${ITERATIONS}... "
  if bazel build "${TARGET}" \
      --@rules_rust//rust/settings:pipelined_compilation=true \
      --@rules_rust//rust/settings:experimental_worker_pipelining=true \
      --strategy=Rustc=worker,local \
      --disk_cache="" \
      --noremote_accept_cached \
      --noremote_upload_local_results \
      2>/dev/null; then
    echo "OK"
    WORKER_PASS=$((WORKER_PASS + 1))
  else
    echo "FAIL"
    WORKER_FAIL=$((WORKER_FAIL + 1))
  fi
done

echo "  Results: ${WORKER_PASS}/${ITERATIONS} pass"
echo ""

# ---------------------------------------------------------------------------
# Phase 2: Non-pipelined builds (must always succeed — baseline)
#
# Without pipelining, each crate is compiled exactly once, so SVH is
# trivially consistent. This phase establishes the baseline.
# ---------------------------------------------------------------------------
echo "--- Phase 2: Non-pipelined (standalone) builds ---"
STANDALONE_PASS=0
STANDALONE_FAIL=0

for i in $(seq 1 "$ITERATIONS"); do
  echo -n "  standalone build ${i}/${ITERATIONS}... "
  if bazel build "${TARGET}" \
      --@rules_rust//rust/settings:pipelined_compilation=false \
      --@rules_rust//rust/settings:experimental_worker_pipelining=false \
      --strategy=Rustc=local \
      --disk_cache="" \
      --noremote_accept_cached \
      --noremote_upload_local_results \
      2>/dev/null; then
    echo "OK"
    STANDALONE_PASS=$((STANDALONE_PASS + 1))
  else
    echo "FAIL (unexpected!)"
    STANDALONE_FAIL=$((STANDALONE_FAIL + 1))
  fi
done

echo "  Results: ${STANDALONE_PASS}/${ITERATIONS} pass"
echo ""

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo "  Worker-pipelined:  ${WORKER_PASS}/${ITERATIONS} pass"
echo "  Standalone:        ${STANDALONE_PASS}/${ITERATIONS} pass"
echo ""

if [[ ${WORKER_FAIL} -gt 0 ]]; then
  echo "FAIL: Worker-pipelined build failed ${WORKER_FAIL} time(s)."
  echo "Worker pipelining should never produce SVH mismatch because each crate"
  echo "is compiled by a single rustc invocation."
  exit 1
fi

if [[ ${STANDALONE_FAIL} -gt 0 ]]; then
  echo "FAIL: Standalone build failed ${STANDALONE_FAIL} time(s) (unexpected)."
  exit 1
fi

echo "PASS: Worker pipelining builds are consistent with non-deterministic proc macros."
exit 0
