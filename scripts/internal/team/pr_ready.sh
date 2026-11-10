#!/usr/bin/env bash
# Готовит ветку к PR или к новому раунду ревью: rebase на dev, check.sh,
# сохраняет хвост вывода и печатает черновик описания PR.
# Использование: scripts/internal/team/pr_ready.sh T05
set -euo pipefail
cd "$(dirname "$0")/../../.."
id="${1:?ID задачи}"

git fetch -q origin dev
git rebase origin/dev

out=$(mktemp)
status=0
if [[ -x scripts/internal/check.sh ]]; then
  scripts/internal/check.sh >"$out" 2>&1 || status=$?
else
  echo "scripts/internal/check.sh ещё нет (до T00)" >"$out"
fi

title=$(grep -m1 -E "^### ${id} — " docs/tasks.md | sed -E "s/^### //" || true)
title="${title:-$id}"
cat <<MD
## ${title}

### Что сделано
$(sed -n '/^## Для разработки/,$p' "changelog.d/${id}.md" 2>/dev/null | tail -n +2)

### Как проверить
\`scripts/internal/check.sh\`

\`\`\`text
$(tail -n 15 "$out")
\`\`\`
MD
rm -f "$out"
exit $status
