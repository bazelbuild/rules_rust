#!/bin/bash

set -euo pipefail

echo "=== Testing Deterministic Build for Ring Crate (.rlib files) ==="

# Define the target to test
TARGET="@crates//:ring"
STORE_DIR="./deterministic_test_store"
BUILD1_DIR="${STORE_DIR}/build1"
BUILD2_DIR="${STORE_DIR}/build2"

# Define the build command with flags (modify this to add/change flags)
# Example: BUILD_CMD="bazel build --noremote_accept_cached --verbose_failures --sandbox_debug"
BUILD_CMD="bazel build --noremote_accept_cached --@rules_rust//rust/settings:lto=thin"

# Clean up any previous test runs
if [ -d "$STORE_DIR" ]; then
    echo "Cleaning up previous test store..."
    rm -rf "$STORE_DIR"
fi

# Create directories for storing build outputs
mkdir -p "$BUILD1_DIR" "$BUILD2_DIR"

echo "--- First Build ---"
# Build the target
$BUILD_CMD "$TARGET"

# Find and copy the .rlib artifacts
echo "Copying first build .rlib artifacts..."
BAZEL_BIN=$(bazel info bazel-bin)
find "$BAZEL_BIN" -name "*.rlib" -type f -exec cp {} "$BUILD1_DIR/" \;

echo "First build .rlib artifacts stored in: $BUILD1_DIR"
ls -la "$BUILD1_DIR"

echo "--- Cleaning Build ---"
# Clean the build to ensure we're starting fresh
bazel clean

echo "--- Second Build ---"
# Build again
$BUILD_CMD "$TARGET"

# Copy second build .rlib artifacts
echo "Copying second build .rlib artifacts..."
BAZEL_BIN=$(bazel info bazel-bin)
find "$BAZEL_BIN" -name "*.rlib" -type f -exec cp {} "$BUILD2_DIR/" \;

echo "Second build .rlib artifacts stored in: $BUILD2_DIR"
ls -la "$BUILD2_DIR"

echo "--- Comparing Build Outputs ---"

# Compare .rlib files individually
RESULT=0
DIFFERENT_FILES=()

echo "Comparing .rlib files individually..."
for rlib1 in "$BUILD1_DIR"/*.rlib; do
    if [ ! -f "$rlib1" ]; then
        echo "No .rlib files found in first build"
        RESULT=1
        break
    fi
    
    filename=$(basename "$rlib1")
    rlib2="$BUILD2_DIR/$filename"
    
    if [ ! -f "$rlib2" ]; then
        echo "❌ File missing in second build: $filename"
        RESULT=1
        continue
    fi
    
    if ! diff "$rlib1" "$rlib2" > /dev/null; then
        echo "❌ DIFFERENCE FOUND: $filename"
        echo "  Hash 1: $(sha256sum "$rlib1" | cut -d' ' -f1)"
        echo "  Hash 2: $(sha256sum "$rlib2" | cut -d' ' -f1)"
        DIFFERENT_FILES+=("$filename")
        RESULT=1
    else
        echo "✅ Identical: $filename"
    fi
done

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS: Builds are deterministic! All .rlib files are identical."
else
    echo ""
    echo "❌ FAILURE: Builds are NOT deterministic."
    echo "Different .rlib files: ${#DIFFERENT_FILES[@]} out of $(ls -1 "$BUILD1_DIR"/*.rlib 2>/dev/null | wc -l)"
    
    if [ ${#DIFFERENT_FILES[@]} -gt 0 ]; then
        echo ""
        echo "Debug commands for different files:"
        for filename in "${DIFFERENT_FILES[@]}"; do
            echo "  For $filename:"
            echo "    diffoscope '$BUILD1_DIR/$filename' '$BUILD2_DIR/$filename'"
            echo "    Or upload to https://try.diffoscope.org/"
        done
    fi
fi

echo ""
echo "=== Test Complete ==="
echo ".rlib artifacts stored in: $STORE_DIR"

exit $RESULT 
