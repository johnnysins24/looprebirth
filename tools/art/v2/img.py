"""Small image helpers for v2 sprites (PIL RGBA, 1-bit alpha)."""

import numpy as np
from PIL import Image

import pal

CLEAR = (0, 0, 0, 0)


def new(w, h, fill=CLEAR):
    return Image.new("RGBA", (w, h), pal.c(fill) if fill != CLEAR else CLEAR)


def grid(rows, legend, width=None):
    """Turn text rows into an image. legend maps a char to a palette name; '.' and ' ' are clear."""
    w = width or max(len(r) for r in rows)
    im = new(w, len(rows))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            if ch not in legend:
                raise KeyError(f"char {ch!r} at {x},{y} has no colour")
            if legend[ch] is not None:
                px[x, y] = pal.c(legend[ch])
    return im


def paste(dst, src, x, y):
    """Paste src onto dst at (x, y), keeping dst where src is clear."""
    dst.alpha_composite(src, (x, y)) if x >= 0 and y >= 0 else _paste_clip(dst, src, x, y)
    return dst


def _paste_clip(dst, src, x, y):
    sx, sy = max(0, -x), max(0, -y)
    crop = src.crop((sx, sy, src.width, src.height))
    dst.alpha_composite(crop, (x + sx, y + sy))


def under(dst, src, x=0, y=0):
    """Paste src beneath dst (dst stays on top)."""
    out = new(*dst.size)
    out.alpha_composite(src, (x, y))
    out.alpha_composite(dst)
    return out


def flip_h(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def recolor(im, mapping):
    """Swap palette colours: mapping {from_name: to_name}."""
    a = np.array(im)
    out = a.copy()
    for f, t in mapping.items():
        fr = np.array(pal.c(f), dtype=np.uint8)
        mask = np.all(a == fr, axis=-1)
        out[mask] = pal.c(t)
    return Image.fromarray(out, "RGBA").copy()


def outline(im, color="ink1", diagonal=False):
    """Add a 1 px outline outside the opaque shape."""
    a = np.array(im)
    solid = a[..., 3] > 0
    grow = np.zeros_like(solid)
    shifts = [(0, 1), (0, -1), (1, 0), (-1, 0)]
    if diagonal:
        shifts += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    for dy, dx in shifts:
        grow |= np.roll(np.roll(solid, dy, 0), dx, 1)
    ring = grow & ~solid
    out = a.copy()
    out[ring] = pal.c(color)
    return Image.fromarray(out, "RGBA").copy()


def bad_pixels(im):
    """Pixels that are semi-transparent or not in the v2 palette."""
    a = np.array(im.convert("RGBA"))
    bad = []
    alpha = a[..., 3]
    ys, xs = np.nonzero((alpha > 0) & (alpha < 255))
    bad += [(int(x), int(y), "alpha") for x, y in zip(xs, ys)]
    opaque = a[alpha == 255][:, :3]
    if len(opaque):
        allowed = np.array(sorted(pal.ALLOWED), dtype=np.uint8)
        packed = (opaque[:, 0].astype(np.int32) << 16) | (opaque[:, 1].astype(np.int32) << 8) | opaque[:, 2]
        ok = (allowed[:, 0].astype(np.int32) << 16) | (allowed[:, 1].astype(np.int32) << 8) | allowed[:, 2]
        miss = ~np.isin(packed, ok)
        if miss.any():
            ys, xs = np.nonzero(alpha == 255)
            for i in np.nonzero(miss)[0][:20]:
                bad.append((int(xs[i]), int(ys[i]), "colour"))
    return bad


def zoom(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def checker(w, h, a="cool6", b="cool7", size=4):
    im = new(w, h)
    px = im.load()
    ca, cb = pal.c(a), pal.c(b)
    for y in range(h):
        for x in range(w):
            px[x, y] = ca if ((x // size + y // size) % 2) else cb
    return im


def row(images, gap=2, bg=CLEAR, pad=0, align="bottom"):
    """Lay images left to right."""
    w = sum(i.width for i in images) + gap * (len(images) - 1) + pad * 2
    h = max(i.height for i in images) + pad * 2
    out = new(w, h) if bg == CLEAR else Image.new("RGBA", (w, h), pal.c(bg))
    x = pad
    for i in images:
        y = pad + (h - pad * 2 - i.height if align == "bottom" else 0)
        out.alpha_composite(i, (x, y))
        x += i.width + gap
    return out


class Canvas:
    """Pixel-by-pixel drawing in palette names."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = new(w, h)
        self.px = self.im.load()

    def set(self, x, y, name):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = pal.c(name) if name else CLEAR

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def rect(self, x0, y0, x1, y1, name):
        """Filled, inclusive corners."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, name)

    def hline(self, x0, x1, y, name):
        self.rect(x0, y, x1, y, name)

    def vline(self, x, y0, y1, name):
        self.rect(x, y0, x, y1, name)

    def stamp(self, x, y, rows, legend):
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch not in ". ":
                    self.set(x + i, y + j, legend[ch])

    def outline(self, color="ink1"):
        self.im = outline(self.im, color)
        self.px = self.im.load()


def poly_mask(w, h, pts):
    from PIL import ImageDraw

    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=255)
    return np.array(m) > 0


def _canvas_poly(self, pts, name):
    m = poly_mask(self.w, self.h, pts)
    ys, xs = np.nonzero(m)
    for x, y in zip(xs, ys):
        self.set(int(x), int(y), name)
    return m


def _canvas_line(self, x0, y0, x1, y1, name):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        t = i / n if n else 0
        self.set(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), name)


Canvas.poly = _canvas_poly
Canvas.line = _canvas_line
