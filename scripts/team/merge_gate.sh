#!/usr/bin/env bash
# Можно ли мёржить: последний раунд ревью был после последнего изменения
# кода, в журнале нет незакрытых замечаний, есть фрагмент changelog.
# CI проверяется отдельно (статус PR). Код выхода 0 — можно.
# Использование: scripts/team/merge_gate.sh T05
set -euo pipefail
cd "$(dirname "$0")/../.."
id="${1:?ID задачи}"
log="docs/review/findings/${id}.md"
fail=0

if [[ -f "$log" ]]; then
  # Закрыты только fixed <commit> и rejected: … (принято).
  open=$(grep -E "^\| *${id}-R[0-9]+-[0-9]+ *\|" "$log" \
    | grep -vE '\| *(fixed [0-9a-f]{6,}|rejected: .*\(принято\)) *\| *$' || true)
  [[ -z "$open" ]] || { echo "незакрытые замечания:"; echo "$open"; fail=1; }
else
  echo "нет журнала $log"; fail=1
fi

[[ -e "changelog.d/${id}.md" ]] || { echo "нет changelog.d/${id}.md"; fail=1; }

git fetch -q origin dev
last=$(git log --format=%H -1 --grep='^Record review round [0-9]*$' origin/dev..HEAD || true)
if [[ -z "$last" ]]; then
  echo "ревью ещё не проводилось"; fail=1
else
  after=$(git log --format='%h %s' "$last"..HEAD -- . ':!docs/review/findings/')
  [[ -z "$after" ]] || { echo "изменения после последнего раунда ревью:"; echo "$after"; fail=1; }
fi

(( fail )) || echo "ok: можно мёржить после зелёного CI"
exit $fail
