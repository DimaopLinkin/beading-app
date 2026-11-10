# Галерея качества генератора

Одна команда, без аргументов, строит листы «фото / варианты конвейера» для каждого фото, вида схемы (станок, пейот,
вышивка крестиком) и варианта, плюс `metrics.md`:

```bash
flutter test --tags gallery test/gallery/
```

Результат — в `build/gallery/` (в git не попадает); папку можно сменить переменной `GALLERY_OUT`.
Слева на листе фото, правее варианты в порядке `galleryVariants`; подписи в таблице `metrics.md` в том же порядке.

- **Личные фото** (любые личные) кладём в папку вне репозитория и указываем `GALLERY_PHOTOS=/путь`: они
  попадут на листы с приставкой `private-`, но не в `baseline.json` и не в git.
- **Новая стадия генератора** добавляет свой `GalleryVariant` в `gallery_support.dart`: листы и метрики «до / после» и
  проверка по базе появятся сами. PR прикладывает листы, а `docs/review/findings/<ID>.md` ссылается на них.
- **База метрик** `test/fixtures/photos/baseline.json`; обновление после сознательного изменения качества:
  `GALLERY_UPDATE_BASELINE=1 flutter test --tags gallery test/gallery/` (см. README фикстур).
- «Реальный» вид (бусины, крестики) подключится после T56: пока листы плоские.
- В обычный прогон `scripts/internal/check.sh` тег `gallery` не входит (`--exclude-tags gallery`); регрессия по
  метрикам идёт отдельным тестом `test/domain/image_to_grid/quality_gallery_test.dart`.
