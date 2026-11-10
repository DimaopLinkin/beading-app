#!/usr/bin/env bash
# Собирает фрагменты changelog.d/*.md в версию CHANGELOG.md и release notes.
# Использование: scripts/internal/release_notes.sh <версия> [дата YYYY-MM-DD]
#   --check   только проверить формат фрагментов (используется в scripts/internal/check.sh)
set -euo pipefail
cd "$(dirname "$0")/../.."

types=(added changed fixed removed internal)
declare -A titles=([added]='Добавлено' [changed]='Изменено' [fixed]='Исправлено' [removed]='Удалено' [internal]='Внутреннее')

fragments() { find changelog.d -maxdepth 1 -name 'T*.md' | sort -V; }
field() { awk -v k="$2" '/^---$/{n++; next} n==1 && $1==k":" {print $2; exit}' "$1"; }
section() {  # section <файл> <заголовок> — строки списка под заголовком
  awk -v h="## $2" '$0==h {on=1; next} /^## / {on=0} on && /^- / {print}' "$1"
}

check() {
  local fail=0 f t
  for f in $(fragments); do
    t=$(field "$f" type)
    if [[ ! " ${types[*]} " == *" $t "* ]]; then echo "CHANGELOG: $f: неизвестный type '$t'"; fail=1; fi
    if [[ "$(field "$f" task)" != "$(basename "$f" .md)" ]]; then echo "CHANGELOG: $f: task не совпадает с именем файла"; fail=1; fi
    if [[ -z "$(section "$f" 'Для разработки')$(section "$f" 'Для пользовательницы')" ]]; then
      echo "CHANGELOG: $f: нет ни одной записи"; fail=1
    fi
    if [[ "$t" != internal && -z "$(section "$f" 'Для пользовательницы')" ]]; then
      echo "CHANGELOG: $f: type '$t' требует записи «Для пользовательницы» (иначе используйте internal)"; fail=1
    fi
  done
  return $fail
}

if [[ "${1:-}" == "--check" ]]; then check; exit; fi

version="${1:?версия, например 0.1.0}"
date="${2:-$(date +%F)}"
check
[[ -n "$(fragments)" ]] || { echo "Нет фрагментов в changelog.d/"; exit 1; }

entry=$(mktemp); notes="docs/release-notes/$version.md"
mkdir -p docs/release-notes
{
  echo "## [$version] — $date"
  for t in "${types[@]}"; do
    lines=""
    for f in $(fragments); do
      [[ "$(field "$f" type)" == "$t" ]] || continue
      task=$(field "$f" task)
      while IFS= read -r l; do lines+="$l ($task)"$'\n'; done < <([[ "$t" == internal ]] || section "$f" 'Для пользовательницы'; section "$f" 'Для разработки')
    done
    [[ -n "$lines" ]] && printf '\n### %s\n\n%s' "${titles[$t]}" "$lines"
  done
  echo
} > "$entry"

{
  echo "# Что нового в версии $version"
  echo
  for f in $(fragments); do section "$f" 'Для пользовательницы'; done
} > "$notes"

awk -v entry="$entry" '
  /^## \[Unreleased\]/ { print; print ""; print "Смотри `changelog.d/`."; print ""; while ((getline l < entry) > 0) print l; skip=1; next }
  skip && /^## \[/ { skip=0 }
  !skip { print }
' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md

for f in $(fragments); do git rm -q "$f" 2>/dev/null || rm "$f"; done
echo "Готово: CHANGELOG.md и $notes"
