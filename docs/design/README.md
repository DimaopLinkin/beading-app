# Обмен с Claude Design через репозиторий

Правило проекта: треды макеты не рисуют. Они пишут промпты для Claude Design, ревьюят его HTML и переносят принятые токены и компоненты в UI kit приложения (Cupertino-first, Liquid Glass, см. [ADR-0001](../decisions/0001-native-look.md)).

```text
docs/design/
  CLAUDE_DESIGN.md   — единственный вход для Claude Design: как взять промпт и куда положить результат
  queue/             — очередь промптов NN-имя.md со статусом в начале файла; _context.md — общий контекст
  inbox/             — HTML от Claude Design: <id>-v<N>.html (+ необязательно .md с пояснениями)
  accepted/          — принятые макеты (копирует тред после ревью), оттуда берутся UI kit и экраны
  review-log.md      — замечания ревью и повторяющиеся находки
```

## Ход одного промпта

1. Дмитрий пишет Claude Design: **«Возьми следующий промпт из docs/design/CLAUDE_DESIGN.md»**.
2. Claude Design берёт файл очереди, делает HTML и кладёт в `inbox/` (сам коммитом в ветку `design/<id>` + PR в `dev`, либо Дмитрий кладёт файл руками, если у Claude Design доступ только на чтение).
3. Тред проекта находит новое: `scripts/internal/team/design_review.sh`. Ревьюит по чек-листу из [design-prompts.md](../design-prompts.md#3-проверка-макетов-на-соответствие-liquid-glass), пишет замечания в `review-log.md`.
4. Замечания есть: `status: rework`, Дмитрий говорит Claude Design ту же фразу, тот делает `v2`. Замечаний нет: файл копируется в `accepted/<имя>.html`, `status: accepted`, токены и компоненты уходят в задачу T01b и экранные задачи.

Изменения в `docs/design/` попадают в `dev` только через PR. Ветка `design/*` вливается через PR, тред мержит его после ревью.

## Новый промпт

Добавить файл `queue/NN-имя.md` с началом `id`, `title`, `status: todo`, `depends` (если нужен принятый макет). `docs/design-prompts.md` остаётся справочником и источником общего контекста; рабочая копия промптов — очередь.
