#!/bin/sh
# Checks the library: it type-checks on its own and from a dependent with
# no warnings, it's formatted, and the dependent in tests/demo prints
# tests/expected.txt. Run from anywhere; `t` must be on PATH.
# BLESS=1 rewrites tests/expected.txt with what it prints now.
set -eu
cd "$(dirname "$0")/.."

for root in lib.t tests/demo/main.t; do
    warnings=$(t check "$root" 2>&1)
    if [ -n "$warnings" ]; then
        printf '%s\n' "$warnings"
        echo "FAIL: t check $root printed warnings"
        exit 1
    fi
done

t fmt --check ./*.t tests/demo/*.t

if [ "${BLESS:-}" = 1 ]; then
    t tests/demo/main.t > tests/expected.txt
    echo "wrote tests/expected.txt"
    exit 0
fi

t tests/demo/main.t > tests/actual.txt
if ! diff -u tests/expected.txt tests/actual.txt; then
    echo "FAIL: output differs from tests/expected.txt"
    exit 1
fi
rm tests/actual.txt
echo "ok"
