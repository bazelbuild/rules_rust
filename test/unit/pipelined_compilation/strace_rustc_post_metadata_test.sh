#!/usr/bin/env bash
# Regression test: rustc makes zero input file reads after emitting .rmeta.
#
# This is the critical invariant for worker-managed pipelining: after the
# metadata response is sent, background rustc must not read any sandbox inputs.
# Gate 0 investigation (project_gate0_strace_results.md) proved this holds on
# rustc 1.94.0. This test provides ongoing regression coverage.
#
# Tagged manual + no-sandbox + local; requires strace (Linux only).
set -euo pipefail

RUSTC="${RUSTC:-rustc}"
STRACE="${STRACE:-strace}"

# ---------------------------------------------------------------------------
# Locate tools
# ---------------------------------------------------------------------------
if ! command -v "$STRACE" &>/dev/null; then
    echo "SKIP: strace not found (set STRACE= to override)"
    exit 0
fi
if ! command -v "$RUSTC" &>/dev/null; then
    echo "SKIP: rustc not found (set RUSTC= to override)"
    exit 0
fi

RUSTC_VERSION=$("$RUSTC" --version)
echo "Using rustc: $RUSTC_VERSION"
echo "Using strace: $("$STRACE" --version 2>&1 | head -1)"

# ---------------------------------------------------------------------------
# Temp workspace
# ---------------------------------------------------------------------------
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# dep crate
cat > "$WORKDIR/dep.rs" <<'EOF'
pub fn dep_fn() -> i32 { 42 }
EOF

# included.txt for include_str!
cat > "$WORKDIR/included.txt" <<'EOF'
hello from include_str
EOF

# main lib crate: depends on dep and uses include_str!
cat > "$WORKDIR/lib.rs" <<'EOF'
extern crate dep;

const INCLUDED: &str = include_str!("included.txt");

pub fn answer() -> i32 {
    let _ = INCLUDED;
    dep::dep_fn()
}
EOF

OUTDIR="$WORKDIR/out"
mkdir -p "$OUTDIR"

# ---------------------------------------------------------------------------
# Step 1: compile dep.rs to get dep.rmeta (no strace needed)
# ---------------------------------------------------------------------------
"$RUSTC" \
    --edition 2021 \
    --crate-type lib \
    --crate-name dep \
    --emit=metadata,link \
    --out-dir "$OUTDIR" \
    "$WORKDIR/dep.rs"

DEP_RMETA="$OUTDIR/libdep.rmeta"
if [[ ! -f "$DEP_RMETA" ]]; then
    echo "FAIL: dep.rmeta not produced"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: compile lib.rs under strace
#
# Rustc writes .rmeta to a temp dir (e.g. out/rmeta<hash>/full.rmeta) then
# renames it to libmylib.rmeta.  We trace openat+read+close to capture all
# file I/O; the artifact JSON lines go to stderr separately.
# ---------------------------------------------------------------------------
STRACE_LOG="$WORKDIR/strace.log"

"$STRACE" \
    -f \
    -e trace=openat,read,close \
    -o "$STRACE_LOG" \
    "$RUSTC" \
    --edition 2021 \
    --crate-type lib \
    --crate-name mylib \
    --emit=dep-info,metadata,link \
    --error-format=json \
    --json=artifacts \
    --extern "dep=$DEP_RMETA" \
    -L "$OUTDIR" \
    --out-dir "$OUTDIR" \
    "$WORKDIR/lib.rs" 2>/dev/null

RMETA_OUT="$OUTDIR/libmylib.rmeta"
if [[ ! -f "$RMETA_OUT" ]]; then
    echo "FAIL: libmylib.rmeta not produced"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 3: find the .rmeta write boundary
#
# Rustc writes metadata to a temporary path like out/rmeta<HASH>/full.rmeta
# using O_RDWR|O_CREAT before renaming it to libmylib.rmeta.  This openat()
# is the earliest observable "metadata write started" event.
#
# We also accept the pattern of writing directly to a path ending in .rmeta
# with O_CREAT (in case rustc internals change).
# ---------------------------------------------------------------------------
# Pattern 1: temp rmeta dir (rmeta<hash>/full.rmeta or similar) with O_CREAT
BOUNDARY_LINE=$(grep -n "openat.*rmeta.*full\.rmeta.*O_.*CREAT\|openat.*full\.rmeta.*O_.*CREAT" "$STRACE_LOG" | head -1 | cut -d: -f1)

# Pattern 2: fallback — any openat with O_WRONLY or O_CREAT for a path in OUTDIR
if [[ -z "$BOUNDARY_LINE" ]]; then
    ESCAPED_OUTDIR=$(printf '%s\n' "$OUTDIR" | sed 's/[[\.*^$()+?{|]/\\&/g')
    BOUNDARY_LINE=$(grep -n "openat.*${ESCAPED_OUTDIR}.*O_.*CREAT\|openat.*${ESCAPED_OUTDIR}.*O_WRONLY" "$STRACE_LOG" | head -1 | cut -d: -f1)
fi

if [[ -z "$BOUNDARY_LINE" ]]; then
    echo "FAIL: could not find .rmeta write openat() in strace log"
    echo "--- strace log (openat lines) ---"
    grep "openat" "$STRACE_LOG" | head -30 || true
    exit 1
fi

echo "Boundary: strace line $BOUNDARY_LINE (first output-file write)"

# Lines after the boundary (post-metadata I/O)
POST_LOG="$WORKDIR/post_boundary.log"
tail -n +"$((BOUNDARY_LINE + 1))" "$STRACE_LOG" > "$POST_LOG"

# Lines before and including the boundary (pre-metadata I/O)
PRE_LOG="$WORKDIR/pre_boundary.log"
head -n "$BOUNDARY_LINE" "$STRACE_LOG" > "$PRE_LOG"

# ---------------------------------------------------------------------------
# Step 4: assert zero input-file openat() reads after the boundary
#
# Input files to watch: lib.rs, dep.rs, included.txt, *.rmeta deps, *.rlib deps
#
# Exclusions (legitimate post-boundary opens):
#   O_WRONLY / O_CREAT / O_RDWR  — output writes
#   ENOENT                        — probing for nonexistent files
#   O_DIRECTORY                   — directory traversal
#   /proc /sys /dev               — kernel pseudo-files
#   /home /rustup toolchain paths — rustc runtime libs (legitimate)
# ---------------------------------------------------------------------------
FAIL=0
INPUT_PATTERNS=(
    "lib\.rs"
    "dep\.rs"
    "included\.txt"
    "libdep\.rmeta"
    "libdep\.rlib"
)

for pat in "${INPUT_PATTERNS[@]}"; do
    BAD=$(grep -E "openat.*${pat}" "$POST_LOG" \
        | grep -vE "O_WRONLY|O_CREAT|O_RDWR|ENOENT|O_DIRECTORY" \
        | grep -vE "/proc/|/sys/|/dev/" \
        || true)
    if [[ -n "$BAD" ]]; then
        echo "FAIL: post-metadata read of input file matching '${pat}':"
        echo "$BAD"
        FAIL=1
    fi
done

# Also flag any .so reads that look like proc-macro loads after the boundary
# (only flag .so files from OUTDIR or workdir — not system/toolchain .so)
ESCAPED_OUTDIR=$(printf '%s\n' "$OUTDIR" | sed 's/[[\.*^$()+?{|]/\\&/g')
ESCAPED_WORKDIR=$(printf '%s\n' "$WORKDIR" | sed 's/[[\.*^$()+?{|]/\\&/g')
BAD_SO=$(grep -E "openat.*(${ESCAPED_OUTDIR}|${ESCAPED_WORKDIR}).*\.so" "$POST_LOG" \
    | grep -vE "O_WRONLY|O_CREAT|O_RDWR|ENOENT|O_DIRECTORY" \
    || true)
if [[ -n "$BAD_SO" ]]; then
    echo "FAIL: post-metadata openat() of .so in workdir/outdir (proc macro?) after boundary:"
    echo "$BAD_SO"
    FAIL=1
fi

# ---------------------------------------------------------------------------
# Step 5: assert all input FDs are closed before the boundary
#
# For each input file opened read-only before the boundary, find its FD
# (the return value of openat) and verify close($fd) appears before the
# boundary line.
# ---------------------------------------------------------------------------
while IFS= read -r line; do
    # Extract the FD: last token after "= " on the line
    fd=$(printf '%s' "$line" | grep -oE '= [0-9]+$' | grep -oE '[0-9]+' || true)
    [[ -z "$fd" ]] && continue

    if ! grep -qE "close\($fd\)[[:space:]]*= 0" "$PRE_LOG"; then
        echo "FAIL: FD $fd (opened for input) not closed before .rmeta write boundary"
        echo "  Opened by: $line"
        FAIL=1
    fi
done < <(grep -E "openat.*(lib\.rs|dep\.rs|included\.txt|libdep\.rmeta|libdep\.rlib)" "$PRE_LOG" \
    | grep -vE "O_WRONLY|O_CREAT|O_RDWR|ENOENT|O_DIRECTORY" \
    | grep -E '= [0-9]+$' \
    || true)

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
echo ""
echo "--- Summary ---"
echo "rustc version: $RUSTC_VERSION"
echo "strace boundary line: $BOUNDARY_LINE / $(wc -l < "$STRACE_LOG") total"
echo "post-boundary strace lines: $(wc -l < "$POST_LOG")"

if [[ $FAIL -ne 0 ]]; then
    echo "RESULT: FAIL"
    exit 1
fi

echo "RESULT: PASS — zero input file reads after .rmeta emission, all input FDs closed before boundary"
exit 0
