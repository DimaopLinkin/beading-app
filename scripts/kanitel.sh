#!/usr/bin/env bash
# Сборка и запуск «Канители» одной командой: стрелками выбираете действие и платформу.
#   scripts/kanitel.sh                 — интерактивно
#   scripts/kanitel.sh build macos     — без меню (build|run, ios|macos; для run ios спросит устройство)
# Всегда --release (macOS только arm64). Результат сборки копируется в artifacts/ (в git не попадает):
#   artifacts/beading-v<версия из pubspec>.app  (macOS, ad-hoc подпись) + …-macos.zip для передачи на другой Mac
#   artifacts/beading-v<версия из pubspec>.ipa  (iPhone)
# Параметры Supabase берутся из config/supabase.json (в git нет, образец: config/supabase.example.json).
# Работает на bash 3.2 (системный macOS), без внешних зависимостей кроме flutter.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=config/supabase.json
ARTIFACTS=artifacts

# menu "Заголовок" "пункт 1" "пункт 2" ...  →  номер выбранного пункта (с 0) в $MENU_CHOICE
menu() {
  local title=$1; shift
  local items=("$@") count=$# sel=0 key rest i
  printf '\n%s\n' "$title" >&2
  while true; do
    for ((i = 0; i < count; i++)); do
      if [ "$i" -eq "$sel" ]; then printf '  \033[7m▸ %s\033[0m\n' "${items[$i]}" >&2
      else printf '    %s\n' "${items[$i]}" >&2; fi
    done
    IFS= read -rsn1 key </dev/tty
    if [ "$key" = $'\033' ]; then
      read -rsn2 -t 1 rest </dev/tty || rest=''
      case "$rest" in
        '[A') sel=$(((sel + count - 1) % count)) ;;
        '[B') sel=$(((sel + 1) % count)) ;;
      esac
    elif [ -z "$key" ]; then
      MENU_CHOICE=$sel
      return
    elif [ "$key" = q ]; then
      echo 'Отмена.' >&2; exit 130
    fi
    printf '\033[%dA' "$count" >&2
  done
}

die() { echo "Ошибка: $*" >&2; exit 1; }
command -v flutter >/dev/null || die 'flutter не найден в PATH'

VERSION=$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1 | tr -d '[:space:]')
[ -n "$VERSION" ] || die 'не нашёл version в pubspec.yaml'
SUFFIX="beading-v$VERSION"

ACTION=${1:-}; PLATFORM=${2:-}
if [ -z "$ACTION" ]; then
  menu 'Что делаем? (↑↓ выбрать, Enter подтвердить, q выйти)' 'Запустить (run)' 'Собрать (build)'
  case $MENU_CHOICE in 0) ACTION=run ;; *) ACTION=build ;; esac
fi
if [ -z "$PLATFORM" ]; then
  menu 'Платформа' 'iPhone' 'Mac (macOS)'
  case $MENU_CHOICE in 0) PLATFORM=ios ;; *) PLATFORM=macos ;; esac
fi
case $ACTION in run | build) ;; *) die "действие: build или run, а не '$ACTION'" ;; esac
case $PLATFORM in ios | macos) ;; *) die "платформа: ios или macos, а не '$PLATFORM'" ;; esac

# Параметры сборки: Supabase из gitignored-файла, без него сборка работает без синхронизации.
DEFINES=()
if [ -f "$CONFIG" ]; then
  DEFINES=(--dart-define-from-file="$CONFIG")
else
  echo "⚠ Нет $CONFIG: соберу без синхронизации. Образец: config/supabase.example.json" >&2
fi

# Кодогенерация drift (в git не лежит): нужна после чистого клона.
if ! ls lib/data/db/*.g.dart >/dev/null 2>&1 && ! find lib/data/db -name '*.g.dart' 2>/dev/null | grep -q .; then
  echo '→ Первый запуск: scripts/setup.sh'
  scripts/setup.sh
fi

if [ "$ACTION" = run ]; then
  if [ "$PLATFORM" = macos ]; then
    exec flutter run --release -d macos ${DEFINES[@]+"${DEFINES[@]}"}
  fi
  IDS=(); NAMES=()
  while IFS= read -r line; do
    case $line in *'• ios •'* | *'• ios'*) ;; *) continue ;; esac
    case $line in *simulator*) continue ;; esac
    NAMES+=("$(echo "$line" | awk -F' • ' '{print $1 " (" $4 ")"}')")
    IDS+=("$(echo "$line" | awk -F' • ' '{print $2}')")
  done < <(flutter devices 2>/dev/null | grep '•' || true)
  [ ${#IDS[@]} -gt 0 ] || die 'iPhone не найден: подключите кабелем, разблокируйте, нажмите «Доверять» (flutter devices)'
  if [ ${#IDS[@]} -eq 1 ]; then DEVICE=${IDS[0]}
  else menu 'Устройство' "${NAMES[@]}"; DEVICE=${IDS[$MENU_CHOICE]}; fi
  exec flutter run --release -d "$DEVICE" ${DEFINES[@]+"${DEFINES[@]}"}
fi

mkdir -p "$ARTIFACTS"
if [ "$PLATFORM" = macos ]; then
  flutter build macos --release ${DEFINES[@]+"${DEFINES[@]}"}
  APP=$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)
  [ -n "$APP" ] || die 'не нашёл собранный .app'
  OUT="$ARTIFACTS/$SUFFIX.app"
  rm -rf "$OUT"; ditto "$APP" "$OUT"
  # Переподписываем ad-hoc: сборка с рабочей командой Apple Development запускается только на Mac,
  # внесённых в эту команду, на другом Mac (у Насти) значок перечёркнут. Ad-hoc подпись работает на любом
  # Apple Silicon Mac после снятия карантина. Сессия Supabase лежит в обычной связке, ей команда не нужна.
  rm -f "$OUT/Contents/embedded.provisionprofile"
  codesign --force --deep --options runtime --timestamp=none \
    --entitlements macos/Runner/Release.entitlements --sign - "$OUT"
  codesign --verify --deep --strict "$OUT" || die 'ad-hoc подпись не прошла проверку'
  ZIP="$ARTIFACTS/$SUFFIX-macos.zip"
  rm -f "$ZIP"; ditto -c -k --keepParent "$OUT" "$ZIP"
  echo "→ Для другого Mac передайте $ZIP. Там: распаковать, затем один раз"
  echo "  xattr -dr com.apple.quarantine <путь к .app>  (или правой кнопкой → Открыть)"
else
  flutter build ios --release ${DEFINES[@]+"${DEFINES[@]}"}
  APP=build/ios/iphoneos/Runner.app
  [ -d "$APP" ] || die 'не нашёл build/ios/iphoneos/Runner.app'
  OUT="$ARTIFACTS/$SUFFIX.ipa"
  TMP=$(mktemp -d); mkdir "$TMP/Payload"; ditto "$APP" "$TMP/Payload/Runner.app"
  rm -f "$OUT"; (cd "$TMP" && zip -qry "$OLDPWD/$OUT" Payload); rm -rf "$TMP"
fi
echo "✓ Готово: $OUT"
