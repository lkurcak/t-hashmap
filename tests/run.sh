#!/bin/sh
# Checks the library: it type-checks on its own with no warnings, it's
# formatted, and the tests in tests/lib.t (a dependent, by path) pass.
# Run from anywhere; `t` must be on PATH.
set -eu
cd "$(dirname "$0")/.."

t check --deny-warnings lib.t
t fmt --check ./*.t tests/*.t
t test --deny-warnings tests/lib.t
