#!/usr/bin/env python3
"""Собирает assets/catalog/pnk_floss.json (мулине «ПНК им. Кирова») из таблицы crosti.ru/tools/tables/pnkik.

Запуск: python3 tool/build_pnk_floss_catalog.py <crosti_pnk.csv> <дата снятия данных>
CSV: колонки id, number, name (пусто: у источника названий нет), hex. Оговорки — в assets/catalog/README.md.
"""
import csv
import json
import sys

src, date = sys.argv[1], sys.argv[2]
colors = [
    {'code': r['number'].strip(), 'name': 'Цвет ' + r['number'].strip(), 'rgb': r['hex'].strip().lower()}
    for r in csv.DictReader(open(src, encoding='utf-8'))
]
codes = [c['code'] for c in colors]
if len(set(codes)) != len(codes):
    raise SystemExit('повтор номера')
out = {
    'version': 1,
    'material': 'floss',
    'brand': 'ПНК Кирова',
    'series': 'Мулине',
    'source': 'crosti.ru, таблица цветов «ПНК им. Кирова» (%d номеров), снято %s' % (len(colors), date),
    'colors': sorted(colors, key=lambda c: c['code']),
}
with open('assets/catalog/pnk_floss.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write('\n')
print(len(colors))
