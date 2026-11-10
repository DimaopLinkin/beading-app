#!/usr/bin/env bash
# Все проверки: формат, анализатор, правила слоёв, фрагменты changelog, тесты и пороги покрытия.
# То же гоняет CI. Аргументы уходят в `flutter test` (например, путь к одному тесту).
set -euo pipefail
cd "$(dirname "$0")/../.."

scripts/setup.sh

# Сгенерированный *.g.dart не форматируем: он в .gitignore и пересоздаётся при каждой сборке.
find lib test -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 dart format --output=none --set-exit-if-changed
flutter analyze --fatal-infos --fatal-warnings
scripts/internal/check_architecture.sh
scripts/internal/release_notes.sh --check

flutter test --coverage --exclude-tags gallery --test-randomize-ordering-seed random "$@"

# Пороги покрытия, сгенерированный код не считаем.
check_coverage() {
  local prefix="$1" min="$2"
  awk -v prefix="$prefix" -v min="$min" '
    /^SF:/ { file = substr($0, 4); skip = (index(file, prefix) != 1 || file ~ /\.g\.dart$|\/l10n\/|main\.dart$/) }
    /^LF:/ && !skip { total += substr($0, 4) }
    /^LH:/ && !skip { hit += substr($0, 4) }
    END {
      pct = total ? hit * 100 / total : 100
      printf "coverage %s: %.1f%% (min %d%%)\n", prefix, pct, min
      exit (pct + 0.0001 < min)
    }' coverage/lcov.info
}
check_coverage "lib/domain/" 95
check_coverage "lib/" 85
