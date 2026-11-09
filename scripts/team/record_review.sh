#!/usr/bin/env bash
# Дописывает таблицу замечаний (строки из stdin) в журнал и коммитит.
# Использование: scripts/team/record_review.sh T05 1 < findings.md
set -euo pipefail
cd "$(dirname "$0")/../.."
id="${1:?ID задачи}"; round="${2:?номер раунда}"
log="docs/review/findings/${id}.md"
rows=$(grep -E '^\| *[A-Z][0-9A-Za-z]*-R[0-9]+-[0-9]+ *\|' || true)
[[ -n "$rows" ]] && printf '%s\n' "$rows" >> "$log"
git add "$log"
git commit -q --allow-empty -m "Record review round ${round}"
echo "recorded $(printf '%s' "$rows" | grep -c . || true) findings"
