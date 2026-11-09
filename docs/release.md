# Выпуск и раздача сборок

Приложение **не публикуется**: ни App Store, ни TestFlight, записи в App Store Connect нет. Дмитрий собирает сборки сам и передаёт Насте напрямую. Релизы собираются только из тега в `main` (см. [changelog.md](changelog.md), [workflow.md](workflow.md)).

| Платформа | Тип сборки | Как попадает к ней |
|---|---|---|
| iPhone | **Ad Hoc** `.ipa`, подписана сертификатом Apple Distribution, UDID телефона зарегистрирован в портале | Дмитрий ставит сам (Finder/Apple Configurator/`xcrun devicectl`) |
| MacBook | `.app` с подписью **Developer ID Application**, нотаризована и «прошита» (stapled), упакована в `.dmg` | Дмитрий отправляет `.dmg`, она перетаскивает в «Программы» |

Один раз (делает Дмитрий в портале, пошаговая инструкция — в T10): App ID, iCloud-контейнер, регистрация UDID её iPhone, профили Ad Hoc (iOS) и Developer ID (macOS) с iCloud. Подробности про CloudKit и среды — в [data-and-sync.md](data-and-sync.md#cloudkit-без-app-store-connect).

## Чек-лист релиза

1. Релизный PR `release/<версия>` → `main` влит Дмитрием, тег `v<версия>` поставлен.
2. Если менялись синхронизируемые данные — схема CloudKit задеплоена в Production.
3. `scripts/release_ios.sh` → `.ipa`, `scripts/release_macos.sh` → `.dmg`.
4. Проверка: iPhone-сборка ставится и открывается; Mac `.dmg` открывается без предупреждений Gatekeeper; синхронизация iPhone ↔ Mac работает (обе сборки — Production).
5. Дмитрий передаёт ей сборки и текст `docs/release-notes/<версия>.md`.

## Сроки

Профили Ad Hoc и сертификаты действуют 1 год: за месяц до окончания пересобрать и поставить заново. Дата окончания записывается в `docs/release.md` при первой настройке (задача T10).
