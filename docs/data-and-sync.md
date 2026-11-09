# Данные и синхронизация

## Локальная база: drift

drift (SQLite) — единственный источник правды на устройстве. Все таблицы, участвующие в синхронизации, имеют одинаковые служебные поля:

| Поле | Тип | Зачем |
|---|---|---|
| `id` | TEXT, UUID v7, PK | Генерируется на клиенте, уникален между устройствами |
| `created_at` | INTEGER (UTC ms) | |
| `updated_at` | INTEGER (UTC ms) | Сравнение «кто новее» при слиянии |
| `deleted_at` | INTEGER NULL | Мягкое удаление (tombstone), чтобы удаление доехало до второго устройства |
| `device_id` | TEXT | Какое устройство последним меняло запись |

### Таблицы (первая версия схемы)

| Таблица | Поля сверх служебных | Комментарий |
|---|---|---|
| `projects` | name, status (`idea`/`inProgress`/`done`), technique, content_kind (`image`/`grid`/`steps`), notes, cover_path NULL, last_worked_at | Корень библиотеки |
| `image_patterns` | project_id FK, file_path, pdf_page NULL, width_px, height_px, ruler_top, ruler_height, ruler_step, current_row, view_scale, view_dx, view_dy | Схема из книги и её прогресс. Файл копируется в Application Support, путь относительный. |
| `grid_patterns` | project_id FK, geometry, drop, width, height, bead_size, current_row, current_bead, cells BLOB, cells_codec_version | Сетка одним BLOB (индексы палитры), а не строкой на бусину: 30×400 = 12 000 строк на схему — слишком дорого. Кодек версионирован и покрыт тестами. |
| `pattern_colors` | grid_pattern_id FK, position, rgb, name, catalog_brand NULL, catalog_code NULL, symbol | Палитра-снимок схемы: значения скопированы, а не ссылка на каталог |
| `bead_colors` | brand, series, code, name, rgb, finish, size | Каталог (Miyuki Delica, Toho, Preciosa). Наполняется из `assets/catalog/*.json` при первом запуске/миграции, не синхронизируется. |
| `grid_progress_rows` | grid_pattern_id FK, row_index, completed_at | Отмеченные ряды. Отдельная таблица, потому что при слиянии это множество (объединяем), а не одно значение. Текущая бусина — в `grid_patterns.current_row/current_bead`. |
| `work_sessions` | project_id FK, started_at, ended_at NULL | Учёт времени плетения |
| `inventory` | bead_color_id, grams | Бонус: запасы бисера |
| `settings` | key PK, value | Тема, wakelock, имя для пасхалок |
| `easter_egg_log` | egg_id, shown_at | Чтобы пасхалки не повторялись и были редкими. Локальная, не синхронизируется. |

### Правила работы с drift

- Схема описывается в `lib/data/db/tables/`, код генерируется `build_runner` (`*.g.dart` в git не коммитим, генерация — часть `scripts/test.sh` и `scripts/analyze.sh`).
- Каждое изменение схемы: `schemaVersion++`, шаг в `migrations/`, дамп схемы `dart run drift_dev make-migrations` и **сгенерированный тест миграции** со всех прошлых версий. Без теста миграции PR не проходит ревью.
- В тестах — `NativeDatabase.memory()`; реализации репозиториев тестируются на настоящей in-memory базе, а не на моках.
- Доменные сущности не знают о drift: мапперы `XRow ↔ X` в `data`, тестируются в обе стороны.
- Все записи — через репозитории; репозиторий сам ставит `updated_at`/`device_id` (через `Clock` и `DeviceId`).

## Синхронизация iPhone ↔ MacBook

### Варианты

| Вариант | Плюсы | Минусы | Вывод |
|---|---|---|---|
| **Экспорт/импорт файла** (`.biser` = zip с JSON, через AirDrop/«Поделиться») | Просто, без аккаунтов, заодно даёт обмен схемами | Ручной, прогресс не переносится сам | **MVP**, делаем в любом случае |
| **iCloud / CloudKit, приватная база** (`CKSyncEngine`, iOS 17+/macOS 14+) | Бесплатно, работает под её Apple ID, без своего сервера, фоновые уведомления | Нужен платный Apple Developer Program, Swift-плагин для iOS и macOS | **Рекомендую** как основной автосинк |
| iCloud Drive: файл-журнал изменений в ubiquity-контейнере | Проще CloudKit, Swift почти не нужен | Задержки iCloud Drive, конфликты файлов, свой формат журнала | Запасной вариант, если CloudKit не пойдёт |
| Свой бэкенд (Supabase/Firebase) | Кроссплатформенно | Аккаунт, сервер, приватность, поддержка | Не нужно для двух устройств одного человека |
| Локальная сеть (Bonjour) | Без облака | Оба устройства должны быть рядом и открыты | Нет |

### Рекомендуемая схема

1. **Этап 1 (MVP):** экспорт/импорт `.biser` + резервная копия всей базы в файл.
2. **Этап 2:** автосинк через CloudKit:
   - Swift-плагин `beading_cloudkit` (общий код для iOS и macOS) — только транспорт: отправить/получить записи, токены изменений.
   - Вся логика слияния — в Dart, в `domain/sync`, чистыми функциями со 100% покрытием:
     - запись целиком — *last-writer-wins* по `updated_at`, при равенстве — по `device_id`;
     - `grid_progress_rows` — объединение множеств (отметку ряда нельзя «потерять»), снятие отметки — tombstone;
     - удаление — tombstone, физическая очистка через 30 дней.
   - Интерфейс `SyncRemote` в домене позволяет подменить транспорт на iCloud Drive без переписывания логики.

### Предпосылки этапа 2 (выполнены)

- Apple Developer Program оплачен — есть CloudKit, TestFlight и подписанная сборка для Mac.
- macOS 26.x и iOS 18+ — `CKSyncEngine` (iOS 17+/macOS 14+) доступен без обходных путей.
