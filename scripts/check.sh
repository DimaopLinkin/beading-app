#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/analyze.sh
scripts/test.sh "$@"
