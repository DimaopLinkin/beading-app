#!/usr/bin/env python3
"""Собирает assets/catalog/dmc_floss.json из пакета craft-color-codes (npm, данные CC BY 4.0).

Запуск: python3 tool/build_floss_catalog.py <путь к data/json/dmc-floss.json из пакета> <версия пакета>
Происхождение значений и оговорки — в assets/catalog/README.md.
"""
import json
import sys

src, version = sys.argv[1], sys.argv[2]
data = json.load(open(src, encoding='utf-8'))
colors = []
for c in data['colors']:
    r, g, b = c['rgb']
    colors.append({'code': str(c['code']), 'name': c['name'].strip(), 'rgb': '#%02x%02x%02x' % (r, g, b)})
out = {
    'version': 1,
    'material': 'floss',
    'brand': 'DMC',
    'series': 'Mouliné',
    'source': 'craft-color-codes@%s (CC BY 4.0, MakeBead): dmc-floss' % version,
    'colors': colors,
}
with open('assets/catalog/dmc_floss.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write('\n')
print(len(colors))
