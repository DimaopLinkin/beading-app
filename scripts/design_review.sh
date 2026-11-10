#!/usr/bin/env bash
# Показывает, что ждёт ревью в обмене с Claude Design.
# Использование: scripts/design_review.sh [--remote]
#   --remote  сначала подтянуть ветку origin/design/* и учесть файлы из неё
set -euo pipefail
cd "$(dirname "$0")/.."

q=docs/design/queue
field() { awk '/^---$/{n++; next} n==1 && $1==k":" {sub(/^[^ ]+ /,""); print; exit}' k="$2" "$1"; }

echo "== Очередь =="
for f in "$q"/[0-9]*.md; do
  printf '%-28s %s\n' "$(field "$f" id)" "$(field "$f" status)"
done

inbox() {  # inbox <ссылка на дерево> — HTML в inbox
  # Файлы inbox/<id>-v<N>.html и каталоги docs/design/<id>/ (так Claude Design кладёт артборды сам)
  if [[ "$1" == "." ]]; then
    find docs/design/inbox -maxdepth 1 -name '*.html' -printf '%f\n' 2>/dev/null
    find docs/design/inbox -mindepth 1 -maxdepth 1 -type d -printf '%f.dir\n' 2>/dev/null
    find docs/design -mindepth 1 -maxdepth 1 -type d -not -name queue -not -name inbox -not -name accepted -printf '%f.dir\n'
  else
    git ls-tree --name-only "$1" docs/design/inbox/ 2>/dev/null | sed 's|.*/||' | grep '\.html$' || true
    git ls-tree --name-only "$1" docs/design/ 2>/dev/null | sed 's|.*/||' | grep -vE '\.|^(queue|inbox|accepted)$' | sed 's/$/.dir/' || true
  fi
}

reviewed() { grep -oE '^## [0-9a-z-]+ v[0-9]+' docs/design/review-log.md | sed 's/^## //; s/ v/-v/'; }

sources=(.)
if [[ "${1:-}" == "--remote" ]]; then
  git fetch -q origin '+refs/heads/design/*:refs/remotes/origin/design/*' 2>/dev/null || true
  mapfile -t branches < <(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/design/*')
  [[ ${#branches[@]} -gt 0 ]] && sources+=("${branches[@]}") || echo "(веток origin/design/* пока нет)"
fi

echo
echo "== Ждёт ревью (нет записи в review-log.md) =="
pending=$(
  for s in "${sources[@]}"; do
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      base=${name%.html}; base=${base%.dir}
      reviewed | grep -qx "$base" || echo "$base  ($s)"
    done < <(inbox "$s")
  done | sort -u
)
echo "${pending:-(ничего нового)}"
