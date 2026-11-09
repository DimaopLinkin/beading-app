#!/usr/bin/env bash
# Формат, анализатор (инфо = ошибка) и правила слоёв.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
dart run build_runner build --delete-conflicting-outputs
# Сгенерированный *.g.dart не форматируем: он в .gitignore и пересоздаётся при каждой сборке.
find lib test -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 dart format --output=none --set-exit-if-changed
flutter analyze --fatal-infos --fatal-warnings
scripts/check_architecture.sh
scripts/release_notes.sh --check
