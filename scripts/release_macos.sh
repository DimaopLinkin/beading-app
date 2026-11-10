#!/usr/bin/env bash
# Собирает .dmg с приложением: подпись Developer ID, нотаризация, staple. Для её MacBook.
#
# Использование:
#   TEAM_ID=ABCDE12345 NOTARY_PROFILE=biser-notary scripts/release_macos.sh
#   ALLOW_UNTAGGED=1 …   # пробная сборка (имя файла с -dev)
#   DRY_RUN=1 …          # только показать команды
# Переменные:
#   TEAM_ID                обязательно
#   NOTARY_PROFILE         имя профиля `xcrun notarytool store-credentials` (по умолчанию biser-notary)
#   DEVELOPER_ID_IDENTITY  как называется сертификат (по умолчанию «Developer ID Application»)
# Результат: build/release/biser-<версия>+<сборка>[-dev].dmg
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/release_common.sh
source scripts/release_common.sh

while (($#)); do
  case "$1" in
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "неизвестный аргумент '$1'" ;;
  esac
done

[[ "${DRY_RUN:-0}" == 1 ]] || require_macos
require_tools flutter xcodebuild xcrun codesign ditto hdiutil
require_team_id
read_version
check_release_source
notary="${NOTARY_PROFILE:-biser-notary}"
identity="${DEVELOPER_ID_IDENTITY:-Developer ID Application}"

out=build/release/macos
archive="$out/beading.xcarchive"
app="$out/export/beading.app"
dmg_name="biser-${BUILD_NAME}+${BUILD_NUMBER}${SUFFIX}.dmg"
[[ "${DRY_RUN:-0}" == 1 ]] || { rm -rf "$out"; mkdir -p "$out"; }

run flutter build macos --release --config-only --build-name "$BUILD_NAME" --build-number "$BUILD_NUMBER"
run xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath "$archive" -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" archive

render_export_options macos/ExportOptions-DeveloperID.plist "$out/ExportOptions.plist"
run xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" \
  -exportOptionsPlist "$out/ExportOptions.plist" -allowProvisioningUpdates

run codesign --verify --deep --strict --verbose=2 "$app"

# 1. Нотаризация самого .app: чтобы «скрепка» (staple) лежала внутри приложения и работала без сети.
run ditto -c -k --keepParent "$app" "$out/app.zip"
run xcrun notarytool submit "$out/app.zip" --keychain-profile "$notary" --wait
run xcrun stapler staple "$app"
run spctl --assess --type execute --verbose=2 "$app"

# 2. .dmg: приложение и ярлык «Программы».
stage="$out/dmg"
mkdir -p "$stage"
run ditto "$app" "$stage/beading.app"
run ln -s /Applications "$stage/Applications"
run hdiutil create -volname "Бисер" -srcfolder "$stage" -ov -format UDZO "build/release/$dmg_name"
run codesign --sign "$identity" --timestamp "build/release/$dmg_name"
run xcrun notarytool submit "build/release/$dmg_name" --keychain-profile "$notary" --wait
run xcrun stapler staple "build/release/$dmg_name"
run spctl --assess --type open --context context:primary-signature --verbose=2 "build/release/$dmg_name"

echo "Готово: build/release/$dmg_name"
