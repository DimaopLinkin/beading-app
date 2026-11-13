#!/usr/bin/env bash
# Дописывает строки замечаний этого раунда (из stdin) в журнал и коммитит.
# Пустой ввод или "approve" — коммит без строк, раунд всё равно отмечен.
# Использование: scripts/internal/team/record_review.sh T05 1 < findings.md
set -euo pipefail
cd "$(dirname "$0")/../../.."
id="${1:?ID задачи}"; round="${2:?номер раунда}"
log="docs/review/findings/${id}.md"
[[ -f "$log" ]] || { echo "нет $log (scripts/internal/team/task_start.sh создаёт его)"; exit 1; }
input=$(cat)
rows=$(grep -E "^\| *${id}-R${round}-[0-9]+ *\|" <<<"$input" || true)
stray=$(grep -E '^\| *[A-Z][0-9A-Za-z]*-R[0-9]+-[0-9]+ *\|' <<<"$input" \
  | grep -vE "^\| *${id}-R${round}-[0-9]+ *\|" || true)
[[ -z "$stray" ]] || { echo "строки не этой задачи/раунда, не записаны:"; echo "$stray"; exit 1; }
[[ -z "$rows" ]] || printf '%s\n' "$rows" >> "$log"
git add "$log"
git commit -q --allow-empty -m "Record review round ${round}"
echo "recorded $(grep -c . <<<"$rows" || true) findings"
