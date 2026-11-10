#!/usr/bin/env bash
# Собирает Ad Hoc .ipa для её iPhone (UDID должен быть в профиле, см. docs/release.md).
#
# Использование:
#   TEAM_ID=ABCDE12345 scripts/release_ios.sh                  # сборка из тега v<версия> в main
#   ALLOW_UNTAGGED=1 TEAM_ID=… scripts/release_ios.sh          # пробная сборка (имя файла с -dev)
#   TEAM_ID=… scripts/release_ios.sh --install <UDID-или-имя>  # после сборки поставить на iPhone по кабелю
#   DRY_RUN=1 …                                                # только показать команды
# Результат: build/release/biser-<версия>+<сборка>-adhoc[-dev].ipa
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/release_common.sh
source scripts/release_common.sh

device=""
while (($#)); do
  case "$1" in
    --install) device="${2:?после --install нужен UDID или имя устройства}"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) die "неизвестный аргумент '$1'" ;;
  esac
done

[[ "${DRY_RUN:-0}" == 1 ]] || require_macos
require_tools flutter xcodebuild xcrun
require_team_id
read_version
check_release_source

out=build/release/ios
archive="$out/beading.xcarchive"
ipa_name="biser-${BUILD_NAME}+${BUILD_NUMBER}-adhoc${SUFFIX}.ipa"
rm -rf "$out"; mkdir -p "$out"

run flutter build ios --release --config-only --no-codesign --build-name "$BUILD_NAME" --build-number "$BUILD_NUMBER"
run xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination generic/platform=iOS -archivePath "$archive" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" archive

render_export_options ios/ExportOptions-AdHoc.plist "$out/ExportOptions.plist"
run xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" \
  -exportOptionsPlist "$out/ExportOptions.plist" -allowProvisioningUpdates

if [[ "${DRY_RUN:-0}" != 1 ]]; then
  built=$(ls "$out"/export/*.ipa 2>/dev/null | head -n1 || true)
  [[ -n "$built" ]] || die "после экспорта нет .ipa в $out/export"
  mv "$built" "build/release/$ipa_name"
fi
echo "Готово: build/release/$ipa_name"

if [[ -n "$device" ]]; then
  run xcrun devicectl device install app --device "$device" "build/release/$ipa_name"
fi
