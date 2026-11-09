#!/usr/bin/env bash
# Печатает раздел задачи из docs/tasks.md и действующие правила ревью.
# Использование: scripts/team/task_brief.sh T05
set -euo pipefail
cd "$(dirname "$0")/../.."
id="${1:?ID задачи}"

awk -v id="$id" '
  $0 ~ "^### " id " — " { on = 1; print; next }
  on && /^##/ { exit }
  on { print }' docs/tasks.md

grep -E '^\| `[a-z-]+` \|' docs/tasks.md | grep -wE "${id}" | cut -d'|' -f2-4 | sed 's/^/type:/' || true

echo
echo "## Действующие правила (docs/review/rules.md)"
grep -E '^\| *RULE-' docs/review/rules.md || echo "нет"
