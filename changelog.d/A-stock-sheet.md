---
task: A-stock-sheet
type: changed
---

## Для пользовательницы

- Лист, который открывается при выборе нитки или бисера в каталоге, и лист правки запаса в расходе ниток теперь в том же стиле, что «Новый проект»: системный лист, который тянется вниз, со списками в духе iOS.
- В «Моём запасе» число мотков меняется сразу при нажатии на «+» и «−». Если запись не удалась, под счётчиком появляется сообщение, а число возвращается к сохранённому.

## Для разработки

- `ColorDetailSheet` (`lib/presentation/catalog/color_detail_sheet.dart`) заменил `_ColorSheet` на `showCupertinoSheet`; `_StockSheet` в `FlossScreen` тоже.
- `CatalogCubit.setStock` больше не глотает ошибку: `CatalogState.stockWriteFailure`.
- Тест с настоящей базой drift (`catalog_stock_real_db_test.dart`) защищает цепочку «+» → репозиторий → поток → счётчик.
