#!/usr/bin/env bash
#
# Extract FAIL entries from a test summary in a normalized form.
#
# Both the baseline file and the CI comparison must use this script so the
# two never drift apart. Output is sorted and deduplicated so it can be fed
# directly to comm(1).
#
# The trailing detail in parentheses -- "(exit code 1)", "(TIMEOUT after 120s)"
# -- is intentionally dropped: it varies between runs and would cause spurious
# mismatches. Only "<grate> / <test file>" identifies the failure.
#
# Usage: scripts/extract-failures.sh <test-summary.txt>

set -euo pipefail

summary="${1:?usage: extract-failures.sh <test-summary.txt>}"

if [[ ! -f "${summary}" ]]; then
    echo "extract-failures.sh: no such file: ${summary}" >&2
    exit 1
fi

# Matches lines like: FAIL: imfs-grate / imfs_test.c (exit code 1)
grep -oE '^FAIL: [A-Za-z0-9_.-]+ / [A-Za-z0-9_.-]+' "${summary}" | sort -u