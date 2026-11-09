# Архитектура

## Платформы и инструменты

| Что | Версия / решение |
|---|---|
| Flutter | 3.41.0 (`environment.flutter: ">=3.41.0"`) |
| Dart | 3.11.0 (`environment.sdk: ^3.11.0`) |
| Xcode | 27.1 |
| Целевые платформы | iOS (iPhone 13 Pro Max), deployment target **iOS 18.0**; macOS (нативная Flutter-сборка), deployment target **macOS 26.0** (у неё 26.x, не 27). Android/Web/Windows не собираем. |
| Анализатор | `analysis_options.yaml` Дмитрия, копия — [setup/analysis_options.yaml](setup/analysis_options.yaml). Правила не ослабляем без согласования. |

## Чистая слоёная архитектура

Три слоя и корень композиции. Зависимости направлены только внутрь, к домену.

```text
presentation ──► domain ◄── data
      ▲                       ▲
      └──── app (DI, роутинг, запуск) ───┘
```

| Слой | Что лежит | Что можно импортировать |
|---|---|---|
| `domain` | Сущности, value objects, интерфейсы репозиториев, use cases, чистые алгоритмы (генерация схем, квантование цветов, подсчёт бисера, политика пасхалок, слияние при синхронизации) | Только `dart:*`, `meta`, `collection`, `equatable`. **Никакого Flutter, drift, path_provider.** |
| `data` | drift-база, DAO, мапперы row ↔ entity, реализации репозиториев, кодеки файлов (импорт/экспорт), платформенные источники (iCloud, файловая система, декодирование изображений) | `domain`, сторонние пакеты данных |
| `presentation` | Экраны, виджеты, Cubit/Bloc, тема, локализация | `domain`, `core`, Flutter. **Не импортирует `data`.** |
| `app` | DI (get_it), роутер (go_router), `main.dart`, инициализация (wakelock, ориентация, окно macOS) | Всё |
| `core` | Общие утилиты без бизнес-смысла: `Result`/`Failure`, `Clock`, `IdGenerator`, расширения | `dart:*` |

### Структура каталогов

Слой — верхний уровень, фича — внутри слоя. Так правило зависимостей проверяется простой проверкой импортов (см. `scripts/check_architecture.sh` в [workflow.md](workflow.md)).

```text
lib/
  app/            # main, di.dart, router.dart, bootstrap.dart
  core/           # result.dart, failure.dart, clock.dart, id_generator.dart
  domain/
    pattern/      # Pattern, Grid, GridType, Technique, PatternColor, use cases
    palette/      # BeadColor, BeadCatalog, ColorMatcher
    generator/    # ImageToPattern, ColorQuantizer, Dithering, TextToPattern
    project/      # Project, Progress, RowState, use cases
    easter_egg/   # Compliment, EasterEggPolicy
    sync/         # SyncRecord, MergePolicy, SyncRemote (интерфейс)
    settings/
  data/
    db/           # drift: app_database.dart, tables/, daos/, migrations/
    pattern/      # PatternRepositoryImpl, GridCodec
    palette/      # каталог из assets/catalog/*.json
    sync/         # CloudKit/iCloud реализация SyncRemote, файловый экспорт
    ...
  presentation/
    theme/        # AppTheme light/dark, токены из UI kit
    l10n/         # ARB, ru — основной язык
    widgets/      # общий UI kit: BeadCell, PaletteChip, RowCounter...
    library/ editor/ generator/ work/ projects/ settings/ easter_egg/
test/             # зеркалит lib/
```

### Ключевые решения

- **Состояние:** `flutter_bloc` (в основном `Cubit`), тесты через `bloc_test`. Состояния — иммутабельные sealed-классы, `switch` по ним исчерпывающий (`no_default_cases`).
- **DI:** `get_it`, регистрация только в `lib/app/di.dart`. Виджеты получают Cubit через `BlocProvider`, Cubit получает use cases через конструктор.
- **Навигация:** `go_router`.
- **Ошибки:** use cases возвращают `Result<T, Failure>` (sealed). Исключения ловятся на границе `data` (`on DriftException`, `on FileSystemException` — `avoid_catches_without_on_clauses`).
- **Время и случайность** всегда через инжектируемые `Clock` и `Random` — иначе не протестировать прогресс, таймеры и пасхалки.
- **Идентификаторы:** UUID v7 строкой (`IdGenerator`), генерируются на клиенте. Это нужно для синхронизации без конфликтов ключей.
- **Локализация:** `flutter_localizations` + ARB, русский основной; строки в коде запрещены (пункт чек-листа ревью).
- **Отрисовка схемы:** `CustomPainter` + `InteractiveViewer`, перерисовка только видимой области; схемы до ~50 000 бусин должны листаться на 60 fps.

## Доменная модель

Основа — выводы [research.md](research.md), раздел 8. Корень — `Project` (то, что видно в библиотеке). Содержимое проекта — одна из трёх видов схем, у каждой свой прогресс.

```text
Project ─┬─ content: sealed PatternContent
         │     ├─ ImagePattern  (фото/страница PDF из книги)   → progress: RulerProgress
         │     ├─ GridPattern   (своя сеточная схема)         → progress: GridProgress
         │     └─ StepPattern   (пошаговая инструкция, бонус) → progress: StepsProgress
         ├─ status: idea | inProgress | done
         ├─ technique, notes, cover, lastWorkedAt
         └─ work sessions (время)
```

- `ImagePattern` — путь к файлу изображения в песочнице приложения, номер страницы PDF, исходный размер. `RulerProgress` — позиция и высота «линейки» в долях изображения, шаг сдвига, номер ряда, масштаб и сдвиг просмотра.
- `GridPattern` — `GridGeometry`, ширина, высота, `BeadSize`, палитра-**снимок** `List<PatternColor>` (правка каталога не меняет старые схемы — урок Loomerly), `Grid`.
- `GridGeometry` — стратегия, отвечающая за координаты центров бусин, попадание касанием в ячейку, соседей (для заливки) и порядок чтения:

| Геометрия | Как устроена | Техники |
|---|---|---|
| `rectangular` | Ровные ряды и столбцы | Станок, квадратный стежок |
| `peyote(drop: n)` | Столбцы со сдвигом на ½ бусины по вертикали, бусины группами по n | Мозаика/пейот, 2-drop |
| `brick` | Ряды со сдвигом на ½ бусины по горизонтали, ряды могут быть разной длины | Кирпичный стежок, серьги |
| `tubularPeyote` (бонус) | Пейот, замкнутый в цилиндр, со step-up | Трубчатые браслеты |

- `Grid` — плоский `Uint16List` индексов палитры, `0` = пусто. Иммутабелен, правка возвращает копию. Сериализуется версионированным `GridCodec`.
- `PatternColor` — RGB, опционально артикул каталога (бренд, серия, код, название), символ для режима символов.
- `GridProgress` — множество завершённых рядов, текущий ряд, текущая бусина (если отмечают по бусине).
- `ReadingOrder` — чистая функция «схема → ряды плетения»: для каждого ряда направление (←/→) и word chart вида `3 × A, 2 × B`. Для пейота первый ряд плетения = два ряда сетки.
- `MaterialEstimate` — количество бусин по цветам и граммы по таблице веса бусины для `BeadSize`.
