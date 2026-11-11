#!/usr/bin/env python3
"""Собирает assets/catalog/gamma_floss.json из таблицы цветов firma-gamma.ru.

Запуск: python3 tool/build_gamma_floss_catalog.py <gamma_floss.csv> <дата снятия данных, ГГГГ-ММ-ДД>
CSV (колонки floss, hex, beads) снят со страницы «Карта соответствия цветов бисера и мулине Gamma»
(https://firma-gamma.ru/articles/colormap-biser-muline/). Звёздочка у номера — отметка сайта
(«похожий цвет» в соответствии бисеру): для каталога ниток она отбрасывается, повторы склеиваются.
Названий у цветов сайт не даёт, поэтому имя — «Гамма <номер>».
"""
import csv
import json
import sys

src, date = sys.argv[1], sys.argv[2]
colors = {}
for row in csv.DictReader(open(src, encoding='utf-8')):
    code = row['floss'].strip().rstrip('*')
    rgb = row['hex'].strip().lower()
    if colors.setdefault(code, rgb) != rgb:
        raise SystemExit('разные цвета у номера %s' % code)
out = {
    'version': 1,
    'material': 'floss',
    'brand': 'Гамма',
    'series': 'Мулине',
    'source': 'firma-gamma.ru, карта соответствия цветов бисера и мулине Gamma, снято %s (использование согласовано '
              'с заказчиком, приложение некоммерческое)' % date,
    'colors': [{'code': c, 'name': 'Гамма %s' % c, 'rgb': colors[c]} for c in sorted(colors)],
}
with open('assets/catalog/gamma_floss.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write('\n')
print(len(colors))
