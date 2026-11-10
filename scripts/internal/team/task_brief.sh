#!/usr/bin/env bash
# Печатает раздел задачи из docs/tasks.md и действующие правила ревью.
# Использование: scripts/internal/team/task_brief.sh T05
set -euo pipefail
cd "$(dirname "$0")/../../.."
id="${1:?ID задачи}"

section=$(awk -v id="$id" '
  $0 ~ "^### " id " — " { on = 1; print; next }
  on && /^##/ { exit }
  on { print }' docs/tasks.md)
if [[ -n "$section" ]]; then
  echo "$section"
else
  # Задача без раздела (M4, исследования A..) — строка из таблицы.
  row=$(grep -E "^\| *${id} *\|" docs/tasks.md || true)
  echo "${row:-нет задачи ${id} в docs/tasks.md}"
fi

grep -E '^\| `[a-z-]+` \|' docs/tasks.md | grep -wE "${id}" | cut -d'|' -f2-4 | sed 's/^/type:/' || true

echo
echo "## Действующие правила (docs/review/rules.md)"
grep -E '^\| *RULE-' docs/review/rules.md || echo "нет"
