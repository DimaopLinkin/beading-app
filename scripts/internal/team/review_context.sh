#!/usr/bin/env bash
# Собирает вход для ревьюера одним выводом: задача, правила, журнал, diff.
# Раунд 1 — весь diff от dev; раунд N>1 — только diff с прошлого
# коммита "Record review round N-1".
# Использование: scripts/internal/team/review_context.sh T05 2
set -euo pipefail
cd "$(dirname "$0")/../../.."
id="${1:?ID задачи}"; round="${2:-1}"

git fetch -q origin dev
scripts/internal/team/task_brief.sh "$id"

log="docs/review/findings/${id}.md"
echo
echo "## Журнал ${log}"
if [[ ! -f "$log" ]]; then
  echo "(журнала нет)"
elif (( round > 1 )); then
  # закрытые (fixed, принятые rejected) не показываем
  grep -vE '\| *(fixed [0-9a-f]{6,}|rejected: .*\(принято\)) *\| *$' "$log" || true
else
  echo "(раунд 1)"
fi

base=origin/dev
if (( round > 1 )); then
  prev=$(git log --format=%H -1 --grep="^Record review round $((round - 1))\$" || true)
  [[ -n "$prev" ]] && base="$prev"
fi

echo
echo "## Изменённые файлы (от ${base:0:12})"
git diff --stat "$base"...HEAD -- . ':!*.g.dart' ':!docs/review/findings/'
echo
echo "## Diff"
git diff "$base"...HEAD -- . ':!*.g.dart' ':!docs/review/findings/' ':!test/**/goldens/**'
