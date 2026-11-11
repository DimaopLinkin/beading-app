#!/usr/bin/env python3
"""Собирает assets/catalog/gamma_floss.json (мулине «Гамма»).

Запуск: python3 tool/build_gamma_floss_catalog.py <gamma_floss.csv> <crosti_gamma.csv> <дата снятия данных>

* gamma_floss.csv (колонки floss, hex, beads) снят с firma-gamma.ru, страница «Карта соответствия цветов бисера
  и мулине Gamma»: 209 номеров, цвет берём отсюда как главный. Звёздочка у номера («похожий цвет» в соответствии
  бисеру) отбрасывается, повторы склеиваются.
* crosti_gamma.csv (колонки id, floss, name, hex) снят с crosti.ru/tools/tables/gamma: все 598 номеров с русскими
  названиями; цвета в общей части совпадают с firma-gamma (207 из 209, остальные два различаются на 0–2 единицы
  и 227 у номера 5199 — берём цвет firma-gamma).
Номер хранится строкой: ведущие нули важны.
"""
import csv
import json
import sys

firma_csv, crosti_csv, date = sys.argv[1], sys.argv[2], sys.argv[3]
firma = {}
for row in csv.DictReader(open(firma_csv, encoding='utf-8')):
    code = row['floss'].strip().rstrip('*')
    rgb = row['hex'].strip().lower()
    if firma.setdefault(code, rgb) != rgb:
        raise SystemExit('разные цвета у номера %s' % code)
colors = []
for row in sorted(csv.DictReader(open(crosti_csv, encoding='utf-8')), key=lambda r: r['floss']):
    code = row['floss']
    rgb = firma.get(code, row['hex'].strip().lower())
    colors.append({'code': code, 'name': row['name'].strip(), 'rgb': rgb})
missing = set(firma) - {c['code'] for c in colors}
if missing:
    raise SystemExit('нет в crosti: %s' % sorted(missing))
out = {
    'version': 1,
    'material': 'floss',
    'brand': 'Гамма',
    'series': 'Мулине',
    'source': 'firma-gamma.ru (карта цветов мулине, %d номеров) и crosti.ru (таблица цветов «Гамма», %d номеров, '
              'названия), снято %s; использование согласовано с заказчиком (приложение некоммерческое)'
              % (len(firma), len(colors), date),
    'colors': colors,
}
with open('assets/catalog/gamma_floss.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write('\n')
print(len(colors))
