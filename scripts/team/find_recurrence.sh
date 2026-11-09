#!/usr/bin/env bash
# Ищет похожие замечания в журналах других задач (для пометки "recurrence of").
# Использование: scripts/team/find_recurrence.sh T05 arch "импорт из data"
set -euo pipefail
cd "$(dirname "$0")/../.."
id="${1:?ID задачи}"; category="${2:?категория}"; shift 2
pattern="${*:-.}"
shopt -s nullglob
logs=()
for f in docs/review/findings/[A-Z][0-9]*.md; do
  [[ "$f" == "docs/review/findings/${id}.md" ]] || logs+=("$f")
done
hits=""
(( ${#logs[@]} )) && hits=$(grep -HiE "\| *${category} *\|.*(${pattern})" "${logs[@]}" || true)
echo "${hits:-повторов нет}"
