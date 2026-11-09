#!/usr/bin/env bash
# Ищет похожие замечания той же категории в журналах других задач
# (для пометки "recurrence of"). Слова ищутся как подстроки без учёта регистра,
# достаточно совпадения любого; без слов — все замечания категории.
# Использование: scripts/team/find_recurrence.sh T05 arch импорт data
set -euo pipefail
cd "$(dirname "$0")/../.."
case "${LC_ALL:-${LANG:-}}" in *UTF-8* | *utf8*) ;; *) export LC_ALL=C.UTF-8 ;; esac
id="${1:?ID задачи}"; category="${2:?категория}"; shift 2
shopt -s nullglob
logs=()
for f in docs/review/findings/[A-Z][0-9]*.md; do
  [[ "$f" == "docs/review/findings/${id}.md" ]] || logs+=("$f")
done
(( ${#logs[@]} )) || { echo "повторов нет"; exit 0; }
# Колонки: | ID | Раунд | Кто | Серьёзность | Категория | Где | Суть | Повтор | Статус |
same_category=$(awk -F'|' -v cat="$category" '
  $2 ~ /-R[0-9]+-[0-9]+/ { c = $6; gsub(/^ +| +$/, "", c); if (c == cat) print FILENAME ":" $0 }' "${logs[@]}")
hits="$same_category"
if (( $# )) && [[ -n "$hits" ]]; then
  args=(); for w in "$@"; do args+=(-e "$w"); done
  hits=$(grep -iF "${args[@]}" <<<"$same_category" || true)
fi
echo "${hits:-повторов нет}"
