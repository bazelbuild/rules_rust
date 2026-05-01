"""A module containing a mapping of nightly iso dates to Rust versions.

This is a generated file -- see //util/fetch_shas
"""

# Each entry marks the first tracked nightly date where the Rust
# version changed. To resolve a given iso_date, find the latest
# entry whose date is <= the target date.
NIGHTLY_VERSION_TRANSITIONS = {
    "2023-09-19": "1.74.0",
    "2023-10-05": "1.75.0",
    "2023-11-16": "1.76.0",
    "2023-12-28": "1.77.0",
    "2024-02-08": "1.78.0",
    "2024-03-21": "1.79.0",
    "2024-05-02": "1.80.0",
    "2024-06-13": "1.81.0",
    "2024-07-25": "1.82.0",
    "2024-09-05": "1.83.0",
    "2024-10-17": "1.84.0",
    "2024-11-28": "1.85.0",
    "2025-01-09": "1.86.0",
    "2025-02-20": "1.87.0",
    "2025-04-03": "1.88.0",
    "2025-05-13": "1.89.0",
    "2025-08-07": "1.91.0",
    "2025-09-18": "1.92.0",
    "2025-10-30": "1.93.0",
    "2025-12-11": "1.94.0",
    "2026-01-22": "1.95.0",
    "2026-03-05": "1.96.0",
    "2026-04-16": "1.97.0",
}
