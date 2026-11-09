#!/usr/bin/env bash
# Формат, анализатор (инфо = ошибка) и правила слоёв.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings
scripts/check_architecture.sh
scripts/release_notes.sh --check
