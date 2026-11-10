# Выпуск и раздача сборок

Приложение **не публикуется**: ни App Store, ни TestFlight, записи в App Store Connect нет. Дмитрий собирает сборки сам и передаёт Насте напрямую. Релизы собираются только из тега в `main` (см. [changelog.md](changelog.md), [workflow.md](workflow.md)).

| Платформа | Тип сборки | Как попадает к ней |
|---|---|---|
| iPhone | **Ad Hoc** `.ipa`, подписана сертификатом Apple Distribution, UDID телефона зарегистрирован в портале | Дмитрий ставит сам (Finder/Apple Configurator/`xcrun devicectl`) |
| MacBook | `.app` с подписью **Developer ID Application**, нотаризована и «прошита» (stapled), упакована в `.dmg` | Дмитрий отправляет `.dmg`, она перетаскивает в «Программы» |

Идентификаторы: bundle id `com.dimaoplinkin.beading` (iOS и macOS одинаковый), iCloud-контейнер `iCloud.com.dimaoplinkin.beading`, имя под значком «Бисер», минимум iOS 18.0 и macOS 26.0.

## Настройка один раз (делает Дмитрий)

Команда в Apple Developer Program — рабочая. Ничего из этого не создаёт запись в App Store Connect и не публикует приложение.

### 1. Портал разработчика

[developer.apple.com/account](https://developer.apple.com/account) → *Certificates, Identifiers & Profiles*. Team ID (10 символов) виден в *Membership details*; он нужен скриптам как `TEAM_ID`.

1. **Identifiers → + → App IDs → App**. Description «Бисер», Bundle ID *Explicit* `com.dimaoplinkin.beading`. Capabilities: **iCloud** (отметить *Include CloudKit support*). Ничего больше не включать. Платформы: iOS и macOS (один App ID на обе).
2. **Identifiers → + → iCloud Containers**. Identifier `iCloud.com.dimaoplinkin.beading`. Затем открыть App ID → *iCloud → Configure* и привязать этот контейнер.
3. **Devices → + → iOS**. Имя «iPhone Насти», UDID её телефона. Как узнать UDID: подключить iPhone к Mac кабелем → Finder → выбрать iPhone → под именем щёлкнуть по строке с моделью, пока не появится UDID → правый клик → *Копировать*. (Либо Xcode → Window → Devices and Simulators → Identifier.)
4. **Certificates**: нужны **Apple Distribution** (для Ad Hoc) и **Developer ID Application** (для Mac). Дмитрий создаёт их сам в связке ключей (CSR → портал → скачать → двойной щелчок), либо Xcode → Settings → Accounts → *Manage Certificates* → «+». Developer ID Application может создать только Account Holder или Admin команды.
5. Профили вручную создавать не нужно: скрипты вызывают `xcodebuild … -allowProvisioningUpdates`, и Xcode сам создаст Ad Hoc профиль (с её UDID) и Developer ID профиль. Для этого в Xcode (*Settings → Accounts*) должна быть добавлена учётная запись команды.

### 2. Нотаризация (Mac)

Один раз сохранить пароль приложения в связку ключей:

```bash
# пароль приложения: appleid.apple.com → Вход и безопасность → Пароли приложений
xcrun notarytool store-credentials "biser-notary" --apple-id "<apple-id>" --team-id "<TEAM_ID>"
```

Имя профиля `biser-notary` — значение `NOTARY_PROFILE` по умолчанию.

### 3. Что ещё не включено

iCloud-права (`com.apple.developer.icloud-*`) в entitlements **пока не добавлены**: без плагина CloudKit (T27) они ничего не делают, а во время разработки на Mac с подписью «-» приложение с таким правом не запустилось бы. T27 добавит их и `aps-environment`; к тому времени App ID и контейнер из шага 1 уже готовы.

## Сборка

Нужны Mac, Xcode, Flutter 3.41.0. Релиз собирается из тега `v<версия>` в `main` (скрипты проверяют: тег есть, совпадает с `version:` в `pubspec.yaml`, дерево чистое). Для пробной сборки с `dev` на приёмку (T10) добавить `ALLOW_UNTAGGED=1`: в имени файла будет `-dev`.

```bash
export TEAM_ID=ABCDE12345                      # Team ID из шага 1

# iPhone: Ad Hoc .ipa → build/release/biser-<версия>+<сборка>-adhoc.ipa
scripts/release_ios.sh
scripts/release_ios.sh --install <UDID>        # и сразу поставить по кабелю (xcrun devicectl)

# Mac: подпись Developer ID, нотаризация, staple → build/release/biser-<версия>+<сборка>.dmg
scripts/release_macos.sh
```

`DRY_RUN=1` только печатает команды. Номер сборки берётся из `+N` в `pubspec.yaml`, переопределяется `BUILD_NUMBER=12`.

Что делает `release_ios.sh`: `flutter build ios --config-only` → `xcodebuild archive` → `xcodebuild -exportArchive` с `ios/ExportOptions-AdHoc.plist` (`method: ad-hoc`).
Что делает `release_macos.sh`: `flutter build macos --config-only` → archive → export `macos/ExportOptions-DeveloperID.plist` (`method: developer-id`, Hardened Runtime включён в проекте) → нотаризация `.app` (`notarytool submit --wait`) → `stapler staple` → `.dmg` (приложение и ярлык «Программы») → подпись, нотаризация и staple `.dmg` → проверка `spctl`.

## Как передать ей сборки

**iPhone.** Подключить телефон кабелем и либо `scripts/release_ios.sh --install <UDID>`, либо перетащить `.ipa` на iPhone в боковой панели Finder (или Apple Configurator → Add → Apps). Подтверждать на телефоне ничего не нужно: профиль Ad Hoc принимается сам. Если появится «Не удалось проверить приложение» — UDID не попал в профиль (повторить шаг 1.3 и пересобрать).
**Mac.** Отправить `.dmg` (AirDrop, облако, флешка). Она открывает его и перетаскивает «Бисер» в «Программы». Предупреждения Gatekeeper быть не должно: приложение нотаризовано. Если пришёл файл через мессенджер и macOS пишет «не удаётся проверить», проверьте на своём Mac `spctl --assess --type open --context context:primary-signature -vv файл.dmg` — после `stapler` ответ должен быть `accepted`.
К сборкам приложить текст `docs/release-notes/<версия>.md`.

## Срок действия

Профиль Ad Hoc и сертификаты действуют 1 год. **Дата окончания профиля (заполнить при первой настройке): ____.** За месяц до неё пересобрать `.ipa` и поставить заново (приложение после окончания срока на iPhone перестаёт запускаться). Developer ID сертификат живёт дольше (5 лет), но проверьте дату в связке ключей. Данные приложения при переустановке поверх остаются.

## Чек-лист релиза

1. Релизный PR `release/<версия>` → `main` влит Дмитрием, тег `v<версия>` поставлен.
2. Если менялись синхронизируемые данные — схема CloudKit задеплоена в Production.
3. `scripts/release_ios.sh` → `.ipa`, `scripts/release_macos.sh` → `.dmg`.
4. Проверка: iPhone-сборка ставится и открывается; Mac `.dmg` открывается без предупреждений Gatekeeper; синхронизация iPhone ↔ Mac работает (обе сборки — Production).
5. Дмитрий передаёт ей сборки и текст `docs/release-notes/<версия>.md`.

## Сроки

Профили Ad Hoc и сертификаты действуют 1 год: за месяц до окончания пересобрать и поставить заново. Дата окончания записывается в `docs/release.md` при первой настройке (задача T10).

## Приёмка T10 на устройствах (чек-лист для Дмитрия)

Тред собрал всё, но не мог запустить на устройстве. Пройдите по порядку и отметьте результат в PR. Для шагов 1–4 нужен Mac с Xcode.

**A. Установка**
- [ ] `ALLOW_UNTAGGED=1 TEAM_ID=… scripts/release_ios.sh --install <UDID>`: архив собирается, `.ipa` ставится на iPhone 13 Pro Max, приложение открывается, имя под значком «Бисер», значок-заглушка (кольцо из бусин).
- [ ] `ALLOW_UNTAGGED=1 TEAM_ID=… scripts/release_macos.sh`: нотаризация проходит (`status: Accepted`), `.dmg` открывается, приложение копируется в «Программы» и запускается **без предупреждений Gatekeeper** (Gatekeeper проверяет только скачанные файлы: отправьте `.dmg` себе через AirDrop или мессенджер и откройте полученную копию).
- [ ] Если что-то из этого упало: скопировать вывод скрипта в PR; в первую очередь я ожидаю проблемы в `Info.plist`, `ExportOptions` и именах сертификатов (скрипты и конфигурация собраны без Xcode, вживую не запускались), а также в Swift-канале (шаг C: он не компилировался).

**B. Разрешения** (iPhone и Mac)
- [ ] Тексты запросов камеры и фото по-русски (появятся в T05/T06, пока запросить нечем; ключи `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` уже в Info.plist). Для Mac в `Release.entitlements` есть sandbox, файлы, камера, фото.

**C. Платформенный канал «Уменьшить прозрачность»**
Профильная сборка с кабелем: `flutter run --profile -d <iPhone>` (и `-d macos`). Настройки → внизу «Проверка стекла» (раздел виден только в отладочных и профильных сборках).
- [ ] В строке «Уменьшить прозрачность» сначала «выкл», «Стекло: прозрачное».
- [ ] iPhone: Настройки → Универсальный доступ → Дисплей и размер текста → *Понижение прозрачности* вкл. Вернуться в приложение, не перезапуская: «вкл», «Стекло: сплошное», панели стали сплошными без размытия. Выключить: вернулось размытие.
- [ ] Mac: Системные настройки → Универсальный доступ → Дисплей → *Уменьшить прозрачность* — то же самое.
- [ ] То же для «Повышенная контрастность» (в стеклянной панели «вкл», стекло сплошное).
- [ ] Перезапуск приложения при включённом «Уменьшить прозрачность»: сразу сплошное (значение читается при старте).

**D. Вид стекла** (скриншоты приложить к PR)
- [ ] Светлая и тёмная темы: бар сверху, панель с цифрами, кнопка внизу над ярко-цветной схемой. Текст читается, края не «грязнят», блик не режет глаз.
- [ ] Выглядит ли стекло приемлемо рядом с нативным Liquid Glass iOS 26 / macOS 26 (панель навигации, Центр управления)? Если заметно хуже, ADR-0002 предлагает вариант 1 (нативный SwiftUI) только для `GlassBar` и `GlassSheet`, отдельной задачей.

**E. Кадры на схеме 100×400** (только профильная сборка, телефон не в режиме энергосбережения)
- [ ] Экран «Проверка стекла» сам двигает схему и показывает кадры. Подождать ~20 секунд, нажать «Сбросить цифры» и ещё 20 секунд. Записать в PR: среднее, «95% кадров до», «дольше 8,3 мс», «дольше 16,7 мс».
- [ ] iPhone 13 Pro Max (120 Гц): цель — 95% кадров до 8,3 мс; допустимо до 16,7 мс без пропусков. Mac: то же.
- [ ] Если хуже: попробовать `GlassDensity.dense` (меньше слоёв) и в DevTools → Performance посмотреть, не растёт ли растеризация от `BackdropFilter`; результаты записать в ADR-0002.

