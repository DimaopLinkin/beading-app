#!/usr/bin/env python3
"""Собирает assets/catalog/lucas_floss.json (мулине Luca-S) из таблицы соответствия Luca-S → DMC магазина corolina.ru.

Запуск: python3 tool/build_lucas_floss_catalog.py <Luca-S - DMC.xlsx> <assets/catalog/dmc_floss.json> <дата снятия данных>
Нужен openpyxl. Цвет Luca-S — цвет DMC-аналога из каталога DMC (своих RGB у Luca-S нет). Жёлтая заливка ячейки DMC в
таблице значит «приблизительное сходство»: у такой нитки название начинается с «≈». Строки без аналога («-») и с аналогом
вне каталога DMC пропускаются. Если аналогов несколько («351, 350», «353/20»), берётся первый. Оговорки — в README каталога.
"""
import json
import sys

import openpyxl

xlsx, dmc_path, date = sys.argv[1:4]
dmc = {c['code'].lower(): c for c in json.load(open(dmc_path, encoding='utf-8'))['colors']}
colors, skipped = [], []
for row in openpyxl.load_workbook(xlsx).active.iter_rows(min_row=2):
    luca, analog = row[0].value, row[1].value
    if luca is None or analog is None:
        continue
    code = str(luca).strip()
    key = str(analog).split(',')[0].split('/')[0].strip().lower()
    found = dmc.get(key)
    if found is None:
        skipped.append(code)
        continue
    approx = bool(row[1].fill and row[1].fill.fill_type and row[1].fill.fgColor.rgb == 'FFFFFF00')
    colors.append(
        {
            'code': code,
            'name': ('≈ ' if approx else '= ') + 'DMC ' + found['code'] + ' ' + found['name'],
            'rgb': found['rgb'],
        }
    )
codes = [c['code'] for c in colors]
if len(set(codes)) != len(codes):
    raise SystemExit('повтор номера')
out = {
    'version': 1,
    'material': 'floss',
    'brand': 'Luca-S',
    'series': 'Мулине',
    'source': 'corolina.ru, таблица соответствия цветов Luca-S - DMC (%d номеров); цвет взят у DMC-аналога из каталога DMC, '
    'не измерен у Luca-S; снято %s' % (len(colors), date),
    'colors': colors,
}
with open('assets/catalog/lucas_floss.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write('\n')
print(len(colors), 'пропущено', skipped)
