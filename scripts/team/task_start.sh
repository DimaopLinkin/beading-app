#!/usr/bin/env bash
# Начинает задачу: ветка от свежего dev, фрагмент changelog, журнал ревью.
# Использование: scripts/team/task_start.sh T05 library
set -euo pipefail
cd "$(dirname "$0")/../.."
id="${1:?ID задачи, например T05}"; slug="${2:?slug ветки, например library}"

git fetch -q origin dev
git checkout -b "task/${id}-${slug}" origin/dev

title=$(grep -m1 -E "^### ${id} — " docs/tasks.md | sed -E "s/^### ${id} — //" || true)

frag="changelog.d/${id}.md"
[[ -e "$frag" ]] || sed "s/^task: .*/task: ${id}/" changelog.d/_template.md > "$frag"

log="docs/review/findings/${id}.md"
if [[ ! -e "$log" ]]; then
  cat > "$log" <<MD
# ${id} — ${title:-<название>}

| ID | Раунд | Кто | Серьёзность | Категория | Где | Суть | Повтор | Статус |
|---|---|---|---|---|---|---|---|---|
MD
fi

echo "branch: task/${id}-${slug}"
echo "created: $frag $log"
