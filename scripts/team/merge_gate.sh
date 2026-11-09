#!/usr/bin/env bash
# Можно ли мёржить: в журнале нет открытых замечаний, есть фрагмент changelog.
# CI проверяется отдельно (статус PR). Код выхода 0 — можно.
# Использование: scripts/team/merge_gate.sh T05
set -euo pipefail
cd "$(dirname "$0")/../.."
id="${1:?ID задачи}"
fail=0
open=$(grep -E '\| *(open|reopened) *\|$' "docs/review/findings/${id}.md" || true)
[[ -n "$open" ]] && { echo "открытые замечания:"; echo "$open"; fail=1; }
[[ -e "changelog.d/${id}.md" ]] || { echo "нет changelog.d/${id}.md"; fail=1; }
grep -q 'Record review round' <(git log --format=%s origin/dev..HEAD) \
  || { echo "ревью ещё не проводилось"; fail=1; }
(( fail )) || echo "ok: можно мёржить после зелёного CI"
exit $fail
