#!/bin/bash
# A script for installing the necessary dependencies on Buildkite workers to run
# `rust_wasm_bindgen_test` targets.

set -euo pipefail

sudo apt -y update
sudo apt -y install \
    libxcb1 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libxkbcommon-x11-0 \
    libcairo2 \
    libgtk-3-0 \
    libx11-xcb1
