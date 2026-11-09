# Процесс разработки

## Роли

| Кто | Что делает |
|---|---|
| **Оркестратор** (координатор проекта) | Берёт задачу из [tasks.md](tasks.md), когда её зависимости влиты в `dev`; создаёт тред; передаёт ему текст задачи + этот документ; запускает ревьюера; **мёржит PR в `dev`** после закрытого ревью и зелёного CI; предлагает релизы PR в `main`. |
| **Тред-исполнитель** | Одна задача = один тред = одна ветка = один PR. Пишет тесты и код, гоняет скрипты, пушит, открывает PR, исправляет замечания ревью. Сам себя не ревьюит. |
| **Ревьюер** | Отдельный агент без контекста исполнителя. Проверяет PR по [review/checklist.md](review/checklist.md) и [review/rules.md](review/rules.md), пишет замечания в журнал. |
| **Дмитрий** | Принимает продуктовые решения, аппрувит и вливает релизные PR в `main`, ставит релизы на устройства. |

## Ветки и PR

| Ветка | Назначение |
|---|---|
| `main` | Только релизы. Каждый коммит в `main` — выпущенная версия с тегом `vX.Y.Z`. Вливает только Дмитрий. |
| `dev` | Интеграционная ветка. Все задачи вливаются сюда. |
| `task/<ID>-<slug>` | Одна задача, от свежего `dev`, PR в `dev` |
| `release/<версия>` | Подготовка релиза от `dev`, PR в `main` (см. [changelog.md](changelog.md)) |

**Жёсткие правила (от Дмитрия):**

- В `main` Claude **не пушит и не мёржит**. Релиз Claude предлагает PR `release/<версия>` → `main`, Дмитрий делает аппрув и вливает сам.
- В `dev` Claude **не пушит напрямую**. Изменения попадают в `dev` только мёржем PR; мёржить PR в `dev` Claude может сам, когда ревью закрыто и CI зелёный.
- Это касается и служебных правок (документы, правила ревью, CHANGELOG): только через ветку и PR.

- Ветка задачи от свежего `dev`: `task/<ID>-<slug>`, например `task/T03-drift-schema`. PR — **в `dev`**.
- Перед открытием PR и перед каждым раундом ревью: `git fetch origin dev && git rebase origin/dev`.
- Коммиты маленькие, сообщения на английском в повелительном наклонении (`Add grid codec`).
- PR-описание: ID задачи, что сделано, как проверить, вывод `scripts/check.sh` (последние строки).
- Мёрж в `dev` — squash, делает оркестратор сам, без отдельного согласования, когда ревью закрыто (нет открытых замечаний) и CI зелёный. Сразу после мёржа оркестратор запускает задачи, у которых теперь все зависимости в `dev`.
- Задача стартует только когда **все её зависимости уже в `dev`**. Параллельные задачи не трогают одни и те же файлы; общие точки (`di.dart`, `router.dart`, `app_database.dart`, `pubspec.yaml`, ARB) правятся минимальными добавлениями, конфликты решает тот, кто ребейзится вторым.

## TDD

Цикл для каждого поведения: **красный → зелёный → рефакторинг**.

1. Написать тест на одно поведение, убедиться, что он падает по правильной причине.
2. Минимальный код до зелёного.
3. Рефакторинг при зелёных тестах, `scripts/analyze.sh` чистый.

Что и как тестируем:

| Слой | Тесты | Инструменты |
|---|---|---|
| domain | Юнит-тесты всех use cases и алгоритмов, граничные случаи, property-тесты для кодеков и слияния (encode→decode = identity) | `test`, фейки вместо моков где можно |
| data | Репозитории на `NativeDatabase.memory()`, мапперы туда-обратно, тесты миграций drift, кодеки файлов на фикстурах | `drift_dev` schema tests |
| presentation | Cubit — `bloc_test`; экраны — widget-тесты (состояния loading/empty/error/data, тёмная и светлая тема); отрисовка сетки — golden-тесты | `bloc_test`, `mocktail` для use cases |
| app | Smoke-тест запуска, что DI собирается | |

Пороги покрытия (без `*.g.dart`, `l10n`, `main.dart`): `lib/domain` ≥ 95%, всё приложение ≥ 85%. Проверяет `scripts/test.sh`.

Время, случайность, id, файловая система — только через инжектируемые абстракции. `DateTime.now()` и `Random()` в `lib/` вне `core/` — замечание ревью.

## Скрипты

Все проверки — только скриптами, руками ничего не гоняем. Задача T00 создаёт их в `scripts/` в этом виде (`chmod +x`). `scripts/release_notes.sh` уже есть в репозитории (см. [changelog.md](changelog.md)).

`scripts/test.sh`:

```bash
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
```

`scripts/analyze.sh`:

```bash
#!/usr/bin/env bash
# Формат, анализатор (инфо = ошибка) и правила слоёв.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos --fatal-warnings
scripts/check_architecture.sh
scripts/release_notes.sh --check
```

`scripts/check_architecture.sh`:

```bash
#!/usr/bin/env bash
# Проверяет направление зависимостей между слоями по импортам.
set -euo pipefail
cd "$(dirname "$0")/.."
pkg=$(awk '/^name:/ {print $2; exit}' pubspec.yaml)
fail=0

forbid() {  # forbid <каталог> <регулярка импорта> <сообщение>
  local hits
  hits=$(grep -rnE "^import '($2)" "$1" --include='*.dart' || true)
  if [[ -n "$hits" ]]; then echo "ARCH: $3"; echo "$hits"; fail=1; fi
}

forbid lib/domain "package:flutter/|package:drift|package:$pkg/(data|presentation|app)/|dart:io|dart:ui" \
  "domain должен быть чистым Dart"
forbid lib/core "package:flutter/|package:drift|package:$pkg/(domain|data|presentation|app)/" \
  "core ни от чего не зависит"
forbid lib/data "package:$pkg/(presentation|app)/" "data не знает о UI"
forbid lib/presentation "package:drift|package:$pkg/(data|app)/" "presentation не импортирует data"

exit $fail
```

`scripts/check.sh` — то, что гоняет исполнитель перед пушем и CI:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/analyze.sh
scripts/test.sh "$@"
```

CI (`.github/workflows/check.yml`, задача T00): на каждый PR в `dev` и `main` — `ubuntu-latest`, Flutter 3.41.0, `scripts/check.sh`; отдельная джоба `macos-latest` собирает `flutter build macos --debug` и `flutter build ios --no-codesign --debug`.

## Определение готовности задачи (DoD)

- [ ] Все критерии приёмки задачи покрыты тестами, тесты написаны до кода.
- [ ] `scripts/check.sh` зелёный локально и в CI.
- [ ] Нет `// ignore:` без комментария-обоснования (`document_ignores`).
- [ ] Новые строки UI — в ARB (ru).
- [ ] Новые экраны проверены в светлой и тёмной теме (widget-тест или golden).
- [ ] Изменение схемы БД — с миграцией и тестом миграции.
- [ ] Есть фрагмент `changelog.d/<ID>.md` по правилам [changelog.md](changelog.md).
- [ ] PR открыт, ревью закрыто (все замечания исправлены или отклонены с согласия ревьюера).

## Цикл ревью и журнал повторов

```text
исполнитель: PR готов ──► ревьюер: раунд N ──► замечания? ──нет──► approve ──► мёрж
                                 ▲                  │да
                                 └── исполнитель исправляет, отвечает по каждому ID
```

1. **Раунд ревью.** Ревьюер читает diff, задачу и проверяет по чек-листу и по действующим правилам из [review/rules.md](review/rules.md). Каждое замечание получает ID `T05-R1-03` (задача, раунд, номер), серьёзность (`blocker`/`major`/`minor`/`nit`), категорию из списка в [review/checklist.md](review/checklist.md), файл и строку.
2. **Запись.** Ревьюер дописывает замечания в `docs/review/findings/<ID задачи>.md` в ветке задачи (у каждой задачи свой файл — параллельные ветки не конфликтуют) и оставляет комментарий в PR.
3. **Исправление.** Исполнитель отвечает по каждому ID: `fixed <commit>` или `rejected: <причина>`. Отклонение принимает только ревьюер.
4. **Следующий раунд** начинается с проверки, что все прошлые замечания действительно исправлены и не вернулись. Ревью идёт, пока открытых замечаний не останется (включая `nit`). После 5 раундов без схождения оркестратор зовёт Дмитрия.
5. **Повторы (рецидивы).** Перед раундом ревьюер ищет похожие замечания в `docs/review/findings/*.md` в `dev`. Если категория/суть уже встречалась в другой задаче — замечание помечается `recurrence of T02-R1-04`, серьёзность поднимается на ступень.
6. **Правила.** Когда замечание повторилось во второй задаче, оркестратор после мёржа переносит его в [review/rules.md](review/rules.md) с номером `RULE-NN`. Правила:
   - вкладываются в текст каждой новой задачи («не повторять: RULE-01…»);
   - по возможности автоматизируются (линт-правило, проверка в `check_architecture.sh`, тест) — тогда правило помечается `automated`.
