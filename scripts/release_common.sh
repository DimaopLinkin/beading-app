#!/usr/bin/env bash
# Общие функции release_ios.sh и release_macos.sh. Подключается через `source`.
# Пошаговая инструкция и настройка портала — docs/release.md.

die() { echo "ОШИБКА: $*" >&2; exit 1; }

# run <команда...> — печатает и выполняет; при DRY_RUN=1 только печатает.
run() {
  echo "+ $*"
  if [[ "${DRY_RUN:-0}" == 1 ]]; then return 0; fi
  "$@"
}

require_macos() {
  [[ "$(uname -s)" == Darwin ]] || die "сборка подписанных приложений возможна только на Mac (сейчас $(uname -s))"
}

require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || die "не найдена команда '$tool'"
  done
}

require_team_id() {
  [[ -n "${TEAM_ID:-}" ]] || die "задай TEAM_ID — десятисимвольный Team ID (портал разработчика → Membership details)"
  [[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "TEAM_ID '$TEAM_ID' не похож на Team ID (10 символов A–Z, 0–9)"
}

# Читает version из pubspec.yaml: BUILD_NAME (0.1.0) и BUILD_NUMBER (из +N или переменной окружения).
read_version() {
  local raw
  raw=$(awk '/^version:/ {print $2; exit}' pubspec.yaml)
  [[ -n "$raw" ]] || die "в pubspec.yaml нет version"
  BUILD_NAME="${raw%%+*}"
  if [[ -z "${BUILD_NUMBER:-}" ]]; then
    [[ "$raw" == *+* ]] && BUILD_NUMBER="${raw##*+}" || BUILD_NUMBER=1
  fi
  [[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "BUILD_NUMBER должен быть числом, а не '$BUILD_NUMBER'"
}

# Релизные сборки идут из чистого дерева на теге v<версия>. ALLOW_UNTAGGED=1 — пробная сборка (помечается в имени файла).
check_release_source() {
  if [[ "${ALLOW_UNTAGGED:-0}" == 1 ]]; then
    SUFFIX="-dev"
    echo "ВНИМАНИЕ: пробная сборка без тега (ALLOW_UNTAGGED=1), в имени файла будет -dev"
    return 0
  fi
  SUFFIX=""
  [[ -z "$(git status --porcelain)" ]] || die "в рабочем дереве есть несохранённые изменения"
  local tag
  tag=$(git describe --exact-match --tags HEAD 2>/dev/null) || die "HEAD без тега; релиз собирается из тега v${BUILD_NAME} (или ALLOW_UNTAGGED=1 для пробной сборки)"
  [[ "$tag" == "v${BUILD_NAME}" ]] || die "тег '$tag' не совпадает с версией в pubspec.yaml (ожидался v${BUILD_NAME})"
}

# render_export_options <шаблон> <куда> — подставляет Team ID.
render_export_options() {
  sed "s/__TEAM_ID__/${TEAM_ID}/g" "$1" > "$2"
}
