#!/usr/bin/env python3
"""Собирает assets/catalog/anchor_floss.json (мулине Anchor) из таблицы crosti.ru/tools/tables/anchor.

Запуск: python3 tool/build_anchor_floss_catalog.py <crosti_anchor.csv> <дата снятия данных>
CSV: колонки id, number, name (английское), hex. Происхождение оговорок — в assets/catalog/README.md.
"""
import csv
import json
import sys

src, date = sys.argv[1], sys.argv[2]
colors = [
    {'code': r['number'].strip(), 'name': r['name'].strip(), 'rgb': r['hex'].strip().lower()}
    for r in csv.DictReader(open(src, encoding='utf-8'))
]
codes = [c['code'] for c in colors]
if len(set(codes)) != len(codes):
    raise SystemExit('повтор номера')
out = {
    'version': 1,
    'material': 'floss',
    'brand': 'Anchor',
    'series': 'Stranded Cotton',
    'source': 'crosti.ru, таблица цветов Anchor (%d номеров), снято %s' % (len(colors), date),
    'colors': sorted(colors, key=lambda c: int(c['code'])),
}
with open('assets/catalog/anchor_floss.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write('\n')
print(len(colors))
