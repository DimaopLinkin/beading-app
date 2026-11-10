#!/usr/bin/env python3
"""Собирает assets/catalog/{miyuki_delica_11,toho_round_11}.json из пакета beadloo-assets (MIT).

Запуск: python3 tool/build_full_catalog.py <путь к клону adamaszczos/beadloo-assets> <коммит>
Источник, лицензия и точность — в docs/decisions/0005-full-bead-catalog.md.

Что берётся из пакета: артикул, группа цвета, тип стекла, отделка, статус «снят с производства» (файлы
`beads/<brand>/<type>/11/<code>.metadata.json`) и 48x48-фото бусин (`<code>_48x48.jpg`). RGB считается заново по
фото тем же приёмом, что в самом пакете (центр кадра, OKLab, усечённое среднее по светлоте без бликов и щелей между
бусинами; scripts/beads/common/lib/colorSampler.ts, функция estimateBodyColor).
Торговых названий в пакете нет, поэтому название собирается из официальных признаков («Gray, Opaque, Metallic»;
у Toho в группе цвета стоит само название, например «Lt Topaz»). Названия стартового набора T13 не переносятся:
сверка с фото показала, что часть пар «артикул — название» там не совпадала с реальной бусиной.
"""
import glob
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image

CROP, N = 0.6, 64
SPEC_L, SPEC_C = 0.92, 0.04
BRIGHT_HI, BRIGHT_HI_METALLIC = 0.9, 0.76
DARK_MIN, DARK_MAX, SEP_LO, SEP_HI, BINS = 0.12, 0.75, 0.08, 0.3, 64


def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(np.maximum(c, 1e-12), 1 / 2.4) - 0.055)


def rgb_to_oklab(px):
    lr, lg, lb = (to_lin(px[:, i] / 255.0) for i in range(3))
    l = np.cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
    m = np.cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
    s = np.cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
    return np.stack([
        0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
    ], axis=1)


def oklab_to_rgb(lab):
    L, a, b = lab
    l_, m_, s_ = L + 0.3963377774 * a + 0.2158037573 * b, L - 0.1055613458 * a - 0.0638541728 * b, L - 0.0894841775 * a - 1.291485548 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    lin = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s]
    return [int(round(min(255, max(0, float(to_srgb(min(1, max(0, v)))) * 255)))) for v in lin]


def otsu(sorted_l):
    n = len(sorted_l)
    hist = np.zeros(BINS)
    for v in sorted_l:
        hist[max(0, min(BINS - 1, int(math.floor(v * BINS))))] += 1
    total = float(sum(i * hist[i] for i in range(BINS)))
    wb = sumb = 0.0
    maxv, tb = -1.0, 0
    for i in range(BINS):
        wb += hist[i]
        if wb == 0:
            continue
        wf = n - wb
        if wf == 0:
            break
        sumb += i * hist[i]
        mb, mf = sumb / wb, (total - sumb) / wf
        v = wb * wf * (mb - mf) ** 2
        if v > maxv:
            maxv, tb = v, i
    th = (tb + 1) / BINS
    below = sorted_l[sorted_l < th]
    above = sorted_l[sorted_l >= th]
    return (len(below) / max(1, n),
            float(below.mean()) if len(below) else 0.0,
            float(above.mean()) if len(above) else (float(sorted_l[-1]) if n else 0.0))


def estimate(lab, metallic):
    chroma = np.hypot(lab[:, 1], lab[:, 2])
    keep = ~((lab[:, 0] > SPEC_L) & (chroma < SPEC_C))
    surv = lab[keep] if keep.sum() >= len(lab) * 0.05 else lab
    surv = surv[np.argsort(surv[:, 0], kind='stable')]
    gap, dm, bm = otsu(surv[:, 0])
    bim = max(0.0, min(1.0, ((bm - dm) - SEP_LO) / (SEP_HI - SEP_LO)))
    dark = max(DARK_MIN, min(DARK_MAX, bim * (gap + 0.05)))
    hi_cut = BRIGHT_HI_METALLIC if metallic else BRIGHT_HI
    lo = int(math.floor(len(surv) * dark))
    hi = max(lo + 1, int(math.ceil(len(surv) * hi_cut)))
    return oklab_to_rgb(surv[lo:hi].mean(axis=0))


def sample_hex(path, metallic):
    im = Image.open(path).convert('RGB')
    w, h = im.size
    side = max(1, int(min(w, h) * CROP))
    left, top = (w - side) // 2, (h - side) // 2
    im = im.crop((left, top, left + side, top + side)).resize((N, N), Image.LANCZOS)
    px = np.asarray(im, dtype=np.float64).reshape(-1, 3)
    r, g, b = estimate(rgb_to_oklab(px), metallic)
    return '#%02x%02x%02x' % (r, g, b)


def is_metal(meta):
    g, f = meta.get('glassGroup', '').lower(), meta.get('finish', '').lower()
    gf = meta.get('galvanized', '').lower()
    galv = ('galvaniz' in gf and 'non' not in gf) or bool(re.search('galvaniz|duracoat', f))
    pl = meta.get('plating', '').lower()
    plated = 'plat' in pl and 'non' not in pl
    silver = bool(re.search('silver-?line', f))
    metal = g == 'metallic' or galv or plated or silver or bool(re.search('metallic|permalux|bronze|hematite', f))
    return metal and not silver


# Порядок важен: что сильнее всего определяет вид бусины, идёт первым. Значения — из белого списка в
# test/data/catalog/bundled_catalog_test.dart.
FINISH_RULES = [
    (r'metallic', 'metallic'),
    (r'galvaniz|duracoat|plating|plated', 'galvanized'),
    (r'silver-?line', 'silver_lined'),
    (r'gold-?line|copperline|gold-lined', 'gold_lined'),
    (r'color-lined|inside-color', 'inside_dyed'),
    (r'frosted|matte', 'matte'),
    (r'rainbow|special coating', 'rainbow'),
    (r'ceylon', 'ceylon'),
    (r'luster|glazed', 'luster'),
    (r'outside-dyed|glass enamel', 'opaque'),
]


def finish_of(meta):
    f = meta.get('finish', '').lower()
    for pattern, value in FINISH_RULES:
        if re.search(pattern, f):
            return value
    return 'transparent' if meta.get('glassGroup', '').lower() == 'transparent' else 'opaque'


def name_of(meta):
    parts = [meta.get('colorGroup', ''), meta.get('glassGroup', '')]
    f = meta.get('finish', '')
    if f and f not in ('Non-Extra Finish', 'Not Specified'):
        parts.append(f)
    return ', '.join(p for p in parts if p)


def build(src, brand, series, rel, code_of, out_path, commit):
    colors, seen = [], set()
    for meta_path in sorted(glob.glob(os.path.join(src, 'beads', rel, '*.metadata.json'))):
        stem = os.path.basename(meta_path)[: -len('.metadata.json')]
        photo = os.path.join(os.path.dirname(meta_path), stem + '_48x48.jpg')
        if not os.path.exists(photo):
            continue
        meta = json.load(open(meta_path, encoding='utf-8'))
        code = code_of(stem)
        if code.upper() in seen:
            raise SystemExit('повтор артикула ' + code)
        seen.add(code.upper())
        item = {'code': code, 'name': name_of(meta),
                'rgb': sample_hex(photo, is_metal(meta)), 'finish': finish_of(meta)}
        if meta.get('status') == 'Discontinued':
            item['discontinued'] = True
        colors.append(item)

    def key(c):
        m = re.match(r'^([A-Za-z]*)(\d+)(.*)$', c['code'])
        return (m.group(1), int(m.group(2)), m.group(3)) if m else (c['code'], 0, '')

    colors.sort(key=key)
    doc = {'version': 2, 'material': 'bead', 'brand': brand, 'series': series, 'sizeCode': '11/0',
           'source': 'adamaszczos/beadloo-assets@' + commit, 'colors': colors}
    with open(out_path, 'w', encoding='utf-8') as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=1)
        fh.write('\n')
    print(out_path, len(colors))


if __name__ == '__main__':
    src, commit = sys.argv[1], sys.argv[2]
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'catalog')
    build(src, 'Miyuki', 'Delica', 'miyuki/delica/11', lambda s: s,
          os.path.join(root, 'miyuki_delica_11.json'), commit)
    build(src, 'Toho', 'Round', 'toho/round/11', lambda s: re.sub(r'^TR-11-', '', s),
          os.path.join(root, 'toho_round_11.json'), commit)
