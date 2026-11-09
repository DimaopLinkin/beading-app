#!/usr/bin/env bash
# Генерирует код, гоняет все тесты с покрытием и проверяет пороги.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test --coverage --test-randomize-ordering-seed random "$@"

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
