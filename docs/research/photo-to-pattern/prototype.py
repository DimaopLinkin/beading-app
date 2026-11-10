"""Прототип «фото → схема»: сравнение текущего конвейера T24 с предложенным (docs/research/photo-to-pattern.md).

Это не код приложения, а эталон для Dart-задач T51–T58: каждый шаг — короткая функция на numpy, её легко
перенести и сверить результат. Зависимости: numpy, pillow, scikit-image (только картинки-примеры и Lab).

    python3 -I docs/research/photo-to-pattern/prototype.py OUT_DIR

Пишет листы сравнения OUT_DIR/<пример>-<ремесло>.png и метрики в OUT_DIR/metrics.md.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from skimage import color, data

# ---------------------------------------------------------------- цвет


def to_lab(rgb: np.ndarray) -> np.ndarray:
    return color.rgb2lab(rgb.astype(np.float64) / 255.0)


def to_rgb(lab: np.ndarray) -> np.ndarray:
    return np.clip(color.lab2rgb(lab) * 255.0, 0, 255).round().astype(np.uint8)


def de2000(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    return color.deltaE_ciede2000(a, b)


def srgb_to_linear(x: np.ndarray) -> np.ndarray:
    x = x / 255.0
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(x: np.ndarray) -> np.ndarray:
    y = np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(np.clip(x, 0, None), 1 / 2.4) - 0.055)
    return np.clip(y * 255.0, 0, 255)


# ---------------------------------------------------------------- ресэмплинг


def area_resize(img: np.ndarray, w: int, h: int, linear: bool) -> np.ndarray:
    """Среднее по площади (как CellSampler). linear=True — усреднение в линейном свете."""
    src = srgb_to_linear(img.astype(np.float64)) if linear else img.astype(np.float64)
    hs, ws = src.shape[:2]
    ys = np.linspace(0, hs, h + 1)
    xs = np.linspace(0, ws, w + 1)
    res = np.zeros((h, w, 3))
    # Интегральное изображение даёт точное среднее по прямоугольнику с дробными краями.
    integ = np.zeros((hs + 1, ws + 1, 3))
    integ[1:, 1:] = src.cumsum(0).cumsum(1)

    def at(y: float, x: float) -> np.ndarray:
        y0, x0 = int(np.floor(y)), int(np.floor(x))
        y0, x0 = min(y0, hs - 1), min(x0, ws - 1)
        fy, fx = y - y0, x - x0
        a = integ[y0, x0] * (1 - fy) * (1 - fx) + integ[y0 + 1, x0] * fy * (1 - fx)
        b = integ[y0, x0 + 1] * (1 - fy) * fx + integ[y0 + 1, x0 + 1] * fy * fx
        return a + b

    for r in range(h):
        for c in range(w):
            s = at(ys[r + 1], xs[c + 1]) - at(ys[r], xs[c + 1]) - at(ys[r + 1], xs[c]) + at(ys[r], xs[c])
            res[r, c] = s / ((ys[r + 1] - ys[r]) * (xs[c + 1] - xs[c]))
    return linear_to_srgb(res) if linear else np.clip(res, 0, 255)


# ---------------------------------------------------------------- квантование


def kmeans_lab(x: np.ndarray, wts: np.ndarray, k: int, seed: int = 0, iters: int = 20) -> np.ndarray:
    """Взвешенный k-means в Lab с инициализацией k-means++ (детерминирован по зерну)."""
    rng = np.random.default_rng(seed)
    p = wts / wts.sum()
    centers = [x[rng.choice(len(x), p=p)]]
    d2 = ((x - centers[0]) ** 2).sum(1)
    for _ in range(1, k):
        q = d2 * wts
        if q.sum() <= 0:
            break
        centers.append(x[rng.choice(len(x), p=q / q.sum())])
        d2 = np.minimum(d2, ((x - centers[-1]) ** 2).sum(1))
    c = np.array(centers)
    for _ in range(iters):
        lab = ((x[:, None, :] - c[None]) ** 2).sum(2).argmin(1)
        for j in range(len(c)):
            m = lab == j
            if m.any():
                c[j] = (x[m] * wts[m, None]).sum(0) / wts[m].sum()
    return c


def ensure_accents(x: np.ndarray, centers: np.ndarray, k_total: int, min_de: float = 12.0) -> np.ndarray:
    """Акценты: если у заметной группы пикселей ошибка > min_de, она получает свой цвет (глаза, блики, губы)."""
    c = centers
    while len(c) < k_total:
        err = de2000(x[:, None, :], c[None]).min(1)
        far = err > min_de
        if far.sum() < max(4, len(x) * 0.002):
            break
        c = np.vstack([c, x[far][err[far].argmax()]])
    return c


# ---------------------------------------------------------------- очистка


def neighbors4(h: int, w: int):
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        yield dy, dx


def icm_smooth(cost: np.ndarray, labels: np.ndarray, lam: np.ndarray, iters: int = 4) -> np.ndarray:
    """Сглаживание по модели Поттса (ICM): цена цвета клетки + λ за каждого соседа другого цвета."""
    h, w, k = cost.shape
    lab = labels.copy()
    for _ in range(iters):
        pen = np.zeros((h, w, k))
        for dy, dx in neighbors4(h, w):
            nb = np.full((h, w), -1)
            ys = slice(max(dy, 0), h + min(dy, 0))
            yd = slice(max(-dy, 0), h + min(-dy, 0))
            xs = slice(max(dx, 0), w + min(dx, 0))
            xd = slice(max(-dx, 0), w + min(-dx, 0))
            nb[yd, xd] = lab[ys, xs]
            onehot = np.zeros((h, w, k))
            valid = nb >= 0
            onehot[valid, nb[valid]] = 1
            pen += (1 - onehot) * valid[..., None]
        new = (cost + lam[..., None] * pen).argmin(2)
        if (new == lab).all():
            break
        lab = new
    return lab


def components(lab: np.ndarray):
    h, w = lab.shape
    seen = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            if seen[y, x]:
                continue
            stack, comp = [(y, x)], []
            seen[y, x] = True
            while stack:
                cy, cx = stack.pop()
                comp.append((cy, cx))
                for dy, dx in neighbors4(h, w):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and lab[ny, nx] == lab[y, x]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            yield comp


def remove_islands(lab: np.ndarray, pal: np.ndarray, protect: np.ndarray, min_island: int) -> np.ndarray:
    """Острова меньше min_island клеток → цвет самого близкого по ΔE соседа; защищённые клетки не трогаем."""
    out = lab.copy()
    h, w = lab.shape
    for comp in components(lab):
        if len(comp) >= min_island or any(protect[y, x] for y, x in comp) or _thin_line(comp):
            continue
        own = lab[comp[0]]
        nbs = set()
        for y, x in comp:
            for dy, dx in neighbors4(h, w):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and lab[ny, nx] != own:
                    nbs.add(int(out[ny, nx]))
        if not nbs:
            continue
        nb = min(nbs, key=lambda j: float(de2000(pal[own], pal[j])))
        for y, x in comp:
            out[y, x] = nb
    return out


def _thin_line(comp: list[tuple[int, int]]) -> bool:
    """Тонкая линия (усы, стебель, оправа): компонента шириной в одну клетку и длиной от трёх."""
    ys = {y for y, _ in comp}
    xs = {x for _, x in comp}
    return len(comp) >= 3 and (len(ys) == 1 or len(xs) == 1)


def singles(lab: np.ndarray) -> int:
    return sum(1 for comp in components(lab) if len(comp) == 1)


# ---------------------------------------------------------------- конвейеры


@dataclass
class Result:
    labels: np.ndarray
    palette_lab: np.ndarray


def current_t24(img: np.ndarray, w: int, h: int, k: int, dither: bool, catalog: np.ndarray | None = None) -> Result:
    """Как сейчас в dev: среднее по ячейке в sRGB → k-means в Lab по ячейкам → ближайший цвет (+дизеринг)."""
    cells = area_resize(img, w, h, linear=False)
    lab = to_lab(cells)
    flat = lab.reshape(-1, 3)
    pal = kmeans_lab(flat, np.ones(len(flat)), k)
    if catalog is not None:
        # Как в T24: каждому центру ближайшая позиция каталога по ΔE2000, повторы схлопываются.
        idx = de2000(pal[:, None, :], catalog[None]).argmin(1)
        pal = catalog[np.unique(idx)]
    if not dither:
        return Result(((flat[:, None] - pal[None]) ** 2).sum(2).argmin(1).reshape(h, w), pal)
    work = lab.copy()
    out = np.zeros((h, w), int)
    for y in range(h):
        for x in range(w):
            j = int(((work[y, x] - pal) ** 2).sum(1).argmin())
            out[y, x] = j
            e = work[y, x] - pal[j]
            for dy, dx, f in ((0, 1, 7), (1, -1, 3), (1, 0, 5), (1, 1, 1)):
                if 0 <= y + dy < h and 0 <= x + dx < w:
                    work[y + dy, x + dx] += e * f / 16
    return Result(out, pal)


def bilateral_lab(lab: np.ndarray, radius: int, sigma_s: float, sigma_r: float, passes: int) -> np.ndarray:
    """Сглаживание с сохранением краёв в Lab: однотонные области становятся ровными, границы остаются резкими."""
    out = lab.copy()
    h, w = lab.shape[:2]
    for _ in range(passes):
        acc = np.zeros_like(out)
        wsum = np.zeros((h, w, 1))
        pad = np.pad(out, ((radius, radius), (radius, radius), (0, 0)), mode="edge")
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                sh = pad[radius + dy : radius + dy + h, radius + dx : radius + dx + w]
                ws = np.exp(-(dy * dy + dx * dx) / (2 * sigma_s**2))
                wr = np.exp(-((sh - out) ** 2).sum(2, keepdims=True) / (2 * sigma_r**2))
                acc += sh * ws * wr
                wsum += ws * wr
        out = acc / wsum
    return out


def vivid(lab: np.ndarray, chroma: float = 1.08) -> np.ndarray:
    """Чуть поднять насыщенность: бисер и нитки читаются тусклее экрана. Светлоту не растягиваем: первая версия
    прототипа растягивала её по перцентилям и «выбеливала» кожу и шерсть."""
    out = lab.copy()
    out[..., 1:] *= chroma
    return out


def edge_strength(lab: np.ndarray) -> np.ndarray:
    gy = np.zeros(lab.shape[:2])
    gx = np.zeros(lab.shape[:2])
    gy[1:-1] = np.linalg.norm(lab[2:] - lab[:-2], axis=2)
    gx[:, 1:-1] = np.linalg.norm(lab[:, 2:] - lab[:, :-2], axis=2)
    return np.hypot(gx, gy)


def kmedoids_catalog(x: np.ndarray, wts: np.ndarray, centers: np.ndarray, catalog: np.ndarray, iters: int = 8):
    """Палитра сразу из каталога: центр кластера — ближайшая ещё не занятая позиция, затем пересчёт кластеров."""
    k = min(len(centers), len(catalog))

    def snap(c: np.ndarray) -> np.ndarray:
        d = de2000(c[:, None, :], catalog[None])
        taken: list[int] = []
        for i in np.argsort(d.min(1)):  # сначала центры, у которых есть очень близкая позиция
            for j in np.argsort(d[i]):
                if int(j) not in taken:
                    taken.append(int(j))
                    break
        return np.array(taken[:k])

    chosen = snap(centers[:k])
    for _ in range(iters):
        pal = catalog[chosen]
        lab = ((x[:, None, :] - pal[None]) ** 2).sum(2).argmin(1)
        means = np.array(
            [(x[lab == j] * wts[lab == j, None]).sum(0) / wts[lab == j].sum() if (lab == j).any() else pal[j]
             for j in range(len(pal))]
        )
        new = snap(means)
        if set(new.tolist()) == set(chosen.tolist()):
            break
        chosen = new
    return catalog[chosen]


def proposed(
    img: np.ndarray,
    w: int,
    h: int,
    k: int,
    *,
    detail: float,
    importance: np.ndarray | None = None,
    catalog: np.ndarray | None = None,
    sub: int = 6,
) -> Result:
    """Предложенный конвейер: рабочее разрешение → сглаживание с краями → яркость → палитра по пикселям с акцентами
    → цвет ячейки голосованием → сглаживание Поттса (сильнее в однотонных местах) → острова → слияние."""
    work = area_resize(img, w * sub, h * sub, linear=True)
    lab = bilateral_lab(to_lab(work), radius=2, sigma_s=2.0, sigma_r=9.0, passes=2)
    lab = vivid(lab)
    flat = lab.reshape(-1, 3)
    # Вес пикселя: маска важности (лицо, объект) × контраст (детали важнее ровного фона).
    imp = np.ones((h * sub, w * sub)) if importance is None else _resize_mask(importance, w * sub, h * sub)
    edges_px = edge_strength(lab)
    wts = (imp * (1 + edges_px / (edges_px.mean() + 1e-6))).reshape(-1)
    rng = np.random.default_rng(1)
    pick = rng.choice(len(flat), size=min(len(flat), 20000), replace=False)
    sample, sw = flat[pick], wts[pick]
    base = max(2, k - max(1, k // 5))
    pal = kmeans_lab(sample, sw, base)
    pal = ensure_accents(sample, pal, k)
    if catalog is not None:
        pal = kmedoids_catalog(sample, sw, pal, catalog)

    # Голосование: каждый пиксель выбирает ближайший цвет, ячейка берёт цену «средней ΔE её пикселей до цвета».
    # Евклид в Lab (ΔE76), как в ADR-0004 и T53: ΔE2000 на каждый пиксель слишком дорог для телефона.
    d = np.sqrt(((flat[:, None, :] - pal[None]) ** 2).sum(2))
    cost = d.reshape(h, sub, w, sub, len(pal)).mean((1, 3))
    labels = cost.argmin(2)

    # Где картинка однотонная — сглаживаем сильнее, на контрастных краях — слабее (детали остаются).
    edges = edges_px.reshape(h, sub, w, sub).max((1, 3))
    cell_imp = imp.reshape(h, sub, w, sub).mean((1, 3))
    flatness = 1 / (1 + edges / 12)
    lam = (0.6 + 2.4 * (1 - detail)) * flatness / cell_imp
    labels = icm_smooth(cost, labels, lam)

    # Тонкие контрастные детали (глаза, блики) и всё под маской «важное» очистка не трогает.
    protect = (edges > np.percentile(edges, 97 - 10 * detail)) | (cell_imp > 1.5)
    labels = remove_islands(labels, pal, protect, min_island=2 if detail > 0.6 else 3)

    # Слияние почти одинаковых цветов с малой площадью.
    used = np.unique(labels)
    for a in used:
        for b in used:
            if a < b and (labels == a).any() and (labels == b).any():
                if float(de2000(pal[a], pal[b])) < 5 and min((labels == a).sum(), (labels == b).sum()) < labels.size * 0.02:
                    small, big = (a, b) if (labels == a).sum() < (labels == b).sum() else (b, a)
                    labels[labels == small] = big
    return Result(labels, pal)


def _resize_mask(mask: np.ndarray, w: int, h: int) -> np.ndarray:
    return np.asarray(Image.fromarray(mask.astype(np.float32), mode="F").resize((w, h), Image.BILINEAR))


def ellipse_mask(shape: tuple[int, int], cx: float, cy: float, rx: float, ry: float, weight: float) -> np.ndarray:
    """Имитация маски лица из Apple Vision (T48): эллипс с весом weight, вне его 1."""
    yy, xx = np.mgrid[0 : shape[0], 0 : shape[1]]
    inside = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1
    return np.where(inside, weight, 1.0)


# ---------------------------------------------------------------- предпросмотр


def render_flat(res: Result, cell: int) -> Image.Image:
    rgb = to_rgb(res.palette_lab[None])[0]
    im = Image.fromarray(rgb[res.labels].astype(np.uint8))
    return im.resize((im.width * cell, im.height * cell), Image.NEAREST)


def render_beads(res: Result, cell: int) -> Image.Image:
    """Реалистичный вид: круглые бусины с бликом и тенью, нить между ними."""
    rgb = to_rgb(res.palette_lab[None])[0]
    h, w = res.labels.shape
    im = Image.new("RGB", (w * cell, h * cell), (226, 222, 214))
    dr = ImageDraw.Draw(im)
    for y in range(h):
        for x in range(w):
            c = tuple(int(v) for v in rgb[res.labels[y, x]])
            x0, y0 = x * cell, y * cell
            dark = tuple(int(v * 0.72) for v in c)
            dr.rounded_rectangle([x0 + 1, y0 + 1, x0 + cell - 1, y0 + cell - 1], radius=cell // 3, fill=dark)
            dr.rounded_rectangle([x0 + 1, y0 + 1, x0 + cell - 2, y0 + cell - 2], radius=cell // 3, fill=c)
            hl = tuple(min(255, int(v + (255 - v) * 0.55)) for v in c)
            r = max(1, cell // 6)
            dr.ellipse([x0 + cell // 4, y0 + cell // 4, x0 + cell // 4 + r, y0 + cell // 4 + r], fill=hl)
    return im


def render_stitches(res: Result, cell: int) -> Image.Image:
    """Реалистичный вид вышивки: канва Аида и крестики двумя стежками, верхний стежок светлее."""
    rgb = to_rgb(res.palette_lab[None])[0]
    h, w = res.labels.shape
    im = Image.new("RGB", (w * cell, h * cell), (238, 234, 224))
    dr = ImageDraw.Draw(im)
    for y in range(h + 1):
        dr.line([0, y * cell, w * cell, y * cell], fill=(222, 216, 204))
    for x in range(w + 1):
        dr.line([x * cell, 0, x * cell, h * cell], fill=(222, 216, 204))
    lw = max(2, cell // 3)
    for y in range(h):
        for x in range(w):
            c = tuple(int(v) for v in rgb[res.labels[y, x]])
            top = tuple(min(255, int(v * 1.08 + 6)) for v in c)
            x0, y0, x1, y1 = x * cell + 1, y * cell + 1, (x + 1) * cell - 1, (y + 1) * cell - 1
            dr.line([x0, y1, x1, y0], fill=c, width=lw)
            dr.line([x0, y0, x1, y1], fill=top, width=lw)
    return im


# ---------------------------------------------------------------- листы сравнения


def _font() -> ImageFont.ImageFont:
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf"):
        if Path(path).exists():
            return ImageFont.truetype(path, 20)
    return ImageFont.load_default(size=20)


def label(im: Image.Image, text: str) -> Image.Image:
    font = _font()
    out = Image.new("RGB", (im.width, im.height + 34), (255, 255, 255))
    out.paste(im, (0, 34))
    ImageDraw.Draw(out).text((6, 5), text, fill=(20, 20, 20), font=font)
    return out


def sheet(parts: list[Image.Image]) -> Image.Image:
    hgt = max(p.height for p in parts)
    out = Image.new("RGB", (sum(p.width for p in parts) + 12 * (len(parts) - 1), hgt), (255, 255, 255))
    x = 0
    for p in parts:
        out.paste(p, (x, 0))
        x += p.width + 12
    return out


def mean_de(img: np.ndarray, res: Result) -> float:
    h, w = res.labels.shape
    ref = to_lab(area_resize(img, w, h, linear=True))
    return float(de2000(ref, res.palette_lab[res.labels]).mean())


def _load_catalog() -> np.ndarray:
    """Каталоги бисера из assets/catalog (Toho Round 11/0 и Miyuki Delica 11/0) в Lab."""
    root = Path(__file__).resolve().parents[3] / "assets" / "catalog"
    rgb = []
    for name in ("toho_round_11.json", "miyuki_delica_11.json"):
        for c in json.loads((root / name).read_text())["colors"]:
            h = c["rgb"].lstrip("#")
            rgb.append([int(h[i : i + 2], 16) for i in (0, 2, 4)])
    return to_lab(np.array(rgb, dtype=np.uint8)[None])[0]


def main(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    examples = {
        "portrait": data.astronaut()[30:330, 110:350],  # лицо крупно (NASA, общественное достояние)
        "cat": data.chelsea(),
        "coffee": data.coffee(),
    }
    # Лицо на кадре портрета (как вернул бы VNDetectFaceRectangles): глаза и улыбка получают вес 4.
    masks = {"portrait": ellipse_mask(examples["portrait"].shape[:2], cx=120, cy=118, rx=62, ry=80, weight=4.0)}
    catalog = _load_catalog()
    crafts = {"beads": (36, 10, render_beads, 14), "stitch": (64, 16, render_stitches, 10)}
    rows = ["| Пример | Ремесло | Вариант | Цветов | Одиночных клеток | Средняя ΔE2000 |", "|---|---|---|---|---|---|"]
    for name, img in examples.items():
        for craft, (cols, k, render, cell) in crafts.items():
            h = max(1, round(cols * img.shape[0] / img.shape[1]))
            variants = {
                "сейчас (T24)": current_t24(img, cols, h, k, dither=False),
                "сейчас + дизеринг": current_t24(img, cols, h, k, dither=True),
                "предложено, детально": proposed(img, cols, h, k, detail=0.8),
                "предложено, проще": proposed(img, cols, h, k, detail=0.3),
            }
            if craft == "beads":
                variants["T24 + каталог Toho/Delica"] = current_t24(img, cols, h, k, dither=False, catalog=catalog)
                variants["предложено + каталог"] = proposed(img, cols, h, k, detail=0.8, catalog=catalog)
            if name in masks:
                variants["предложено + маска лица"] = proposed(img, cols, h, k, detail=0.8, importance=masks[name])
            src = Image.fromarray(img).resize((cols * cell, h * cell), Image.LANCZOS)
            parts = [label(src, "фото")]
            for vname, res in variants.items():
                n = len(np.unique(res.labels))
                parts.append(label(render(res, cell), f"{vname}: {n} цв., {singles(res.labels)} одиноч."))
                rows.append(
                    f"| {name} | {craft} | {vname} | {n} | {singles(res.labels)} | {mean_de(img, res):.1f} |"
                )
            sheet(parts).save(out_dir / f"{name}-{craft}.png")
            print(name, craft, "ok", flush=True)
    (out_dir / "metrics.md").write_text("\n".join(rows) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "out"))
