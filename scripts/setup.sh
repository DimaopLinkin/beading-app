#!/usr/bin/env bash
# Первый запуск после клонирования (и после смены схемы БД или .arb): зависимости и кодогенерация.
# Потом достаточно `flutter run`. Что делает:
#   flutter pub get      — пакеты; заодно генерирует локализации (lib/presentation/l10n, flutter: generate)
#   build_runner         — drift: lib/data/db/**/*.g.dart (в git не коммитятся)
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
dart run build_runner build --delete-conflicting-outputs
