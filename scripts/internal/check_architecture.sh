#!/usr/bin/env bash
# Проверяет направление зависимостей между слоями по импортам и экспортам.
# Использование: scripts/internal/check_architecture.sh [корень проекта] — по умолчанию корень репозитория.
set -euo pipefail
cd "${1:-$(dirname "$0")/../..}"
pkg=$(awk '/^name:/ {print $2; exit}' pubspec.yaml)
fail=0

forbid() {  # forbid <каталог> <регулярка импорта> <сообщение>
  local hits
  [[ -d "$1" ]] || return 0
  hits=$(grep -rnE "^(import|export) ['\"]($2)" "$1" --include='*.dart' || true)
  if [[ -n "$hits" ]]; then echo "ARCH: $3"; echo "$hits"; fail=1; fi
}

forbid lib/domain "package:flutter/|package:drift|package:$pkg/(data|presentation|app)/|dart:io|dart:ui" \
  "domain должен быть чистым Dart"
forbid lib/core "package:flutter/|package:drift|package:$pkg/(domain|data|presentation|app)/" \
  "core ни от чего не зависит"
forbid lib/data "package:$pkg/(presentation|app)/" "data не знает о UI"
forbid lib/presentation "package:drift|package:$pkg/(data|app)/" "presentation не импортирует data"

# Material — только через мост: приложение собрано на Cupertino (ADR о нативном виде).
if [[ -d lib/presentation ]]; then
  hits=$(grep -rnE "^(import|export) ['\"]package:flutter/material\.dart" lib --include='*.dart' \
    | grep -v '^lib/presentation/theme/material_bridge\.dart:' || true)
  if [[ -n "$hits" ]]; then echo "ARCH: Material импортируем только в presentation/theme/material_bridge.dart"; echo "$hits"; fail=1; fi
fi

# CupertinoIcons рисуются шрифтом из пакета cupertino_icons: без зависимости в pubspec сборка проходит,
# а на устройстве все иконки превращаются в «?» (баг 0.1.0).
if grep -rqE "CupertinoIcons\." lib --include='*.dart' && ! grep -qE '^  cupertino_icons:' pubspec.yaml; then
  echo "ARCH: lib использует CupertinoIcons, но cupertino_icons не объявлен в dependencies (pubspec.yaml)"; fail=1
fi

exit $fail
