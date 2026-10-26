"""Small pixel-art toolkit: text-grid sprites, palette-safe compositing, sheets.

A sprite is written as a block of text, one character per pixel, using the keys
in pal.py ('.' = transparent). Example:

    S('''
    .kk.
    kyyk
    .kk.
    ''')
"""
import textwrap

from PIL import Image

import pal

TRANSPARENT = (0, 0, 0, 0)


def rows(text):
    lines = textwrap.dedent(text).strip("\n").split("\n")
    lines = [ln.rstrip() for ln in lines]
    width = max(len(ln) for ln in lines)
    # Allow trailing transparency to be omitted.
    lines = [ln.ljust(width, ".") for ln in lines]
    for ln in lines:
        for ch in ln:
            if ch not in pal.KEY:
                raise ValueError(f"unknown color key {ch!r} in line {ln!r}")
    return lines


def S(text):
    """Text grid -> RGBA image."""
    lines = rows(text)
    im = Image.new("RGBA", (len(lines[0]), len(lines)), TRANSPARENT)
    px = im.load()
    for y, ln in enumerate(lines):
        for x, ch in enumerate(ln):
            px[x, y] = pal.KEY[ch]
    return im


def blank(w, h, key="."):
    return Image.new("RGBA", (w, h), pal.KEY[key])


def paste(dst, src, x=0, y=0):
    """Hard-edged paste: opaque source pixels replace destination pixels."""
    sp = src.load()
    dp = dst.load()
    W, H = dst.size
    for j in range(src.height):
        for i in range(src.width):
            c = sp[i, j]
            if c[3] == 0:
                continue
            X, Y = x + i, y + j
            if 0 <= X < W and 0 <= Y < H:
                dp[X, Y] = c
    return dst


def under(dst, src, x=0, y=0):
    """Paste src only where dst is transparent (draw behind)."""
    sp = src.load()
    dp = dst.load()
    W, H = dst.size
    for j in range(src.height):
        for i in range(src.width):
            c = sp[i, j]
            if c[3] == 0:
                continue
            X, Y = x + i, y + j
            if 0 <= X < W and 0 <= Y < H and dp[X, Y][3] == 0:
                dp[X, Y] = c
    return dst


def flip_h(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def flip_v(im):
    return im.transpose(Image.FLIP_TOP_BOTTOM)


def recolor(im, mapping):
    """Swap palette keys, e.g. recolor(slime, {'u': 'm', 'a': 'P'})."""
    lut = {pal.KEY[a]: pal.KEY[b] for a, b in mapping.items()}
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            c = px[x, y]
            if c in lut:
                px[x, y] = lut[c]
    return out


def outline(im, key="k", diagonal=False):
    """Add a 1px outline in `key` around opaque pixels (inside the canvas)."""
    out = im.copy()
    src = im.load()
    px = out.load()
    W, H = im.size
    col = pal.KEY[key]
    nbrs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        nbrs += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    for y in range(H):
        for x in range(W):
            if src[x, y][3]:
                continue
            for dx, dy in nbrs:
                X, Y = x + dx, y + dy
                if 0 <= X < W and 0 <= Y < H and src[X, Y][3]:
                    px[x, y] = col
                    break
    return out


def shift(im, dx, dy, w=None, h=None):
    w = w or im.width
    h = h or im.height
    out = blank(w, h)
    paste(out, im, dx, dy)
    return out


def crop(im, x, y, w, h):
    return im.crop((x, y, x + w, y + h))


def sheet(frames, cols=None, fw=None, fh=None):
    """Lay frames out left-to-right, top-to-bottom. `frames` may be a list of
    rows (list of lists) to make one sheet row per animation."""
    if frames and isinstance(frames[0], (list, tuple)):
        grid = [list(r) for r in frames]
    else:
        cols = cols or len(frames)
        grid = [frames[i:i + cols] for i in range(0, len(frames), cols)]
    fw = fw or max(f.width for r in grid for f in r)
    fh = fh or max(f.height for r in grid for f in r)
    ncol = max(len(r) for r in grid)
    out = blank(fw * ncol, fh * len(grid))
    for j, r in enumerate(grid):
        for i, f in enumerate(r):
            paste(out, f, i * fw, j * fh)
    return out


def zoom(im, z):
    return im.resize((im.width * z, im.height * z), Image.NEAREST)


def bad_pixels(im):
    """Pixels whose color is not in the palette (alpha must be 0 or 255)."""
    allowed = set(pal.KEY.values())
    px = im.load()
    bad = []
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3] == 0:
                continue
            if c not in allowed:
                bad.append((x, y, c))
    return bad


class Canvas:
    """Procedural drawing with palette keys."""

    def __init__(self, w, h, key="."):
        self.im = blank(w, h, key)
        self.px = self.im.load()
        self.w, self.h = w, h

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return pal.RGBA_TO_KEY.get(self.px[x, y], "?")
        return None

    def set(self, x, y, key):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = pal.KEY[key]

    def rect(self, x, y, w, h, key):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.set(i, j, key)

    def hline(self, x0, x1, y, key):
        for i in range(x0, x1 + 1):
            self.set(i, y, key)

    def vline(self, x, y0, y1, key):
        for j in range(y0, y1 + 1):
            self.set(x, j, key)

    def frame(self, x, y, w, h, key):
        self.hline(x, x + w - 1, y, key)
        self.hline(x, x + w - 1, y + h - 1, key)
        self.vline(x, y, y + h - 1, key)
        self.vline(x + w - 1, y, y + h - 1, key)

    def paste(self, src, x=0, y=0):
        paste(self.im, src, x, y)

    def under(self, src, x=0, y=0):
        under(self.im, src, x, y)

    def image(self):
        return self.im


def band(im, y0, y1, dx=0, dy=0, x0=0, x1=None, keep=False):
    """Move the pixels of rows y0..y1 (and columns x0..x1) by (dx, dy).
    keep=True leaves the original pixels under the moved band (stretch)."""
    x1 = im.width - 1 if x1 is None else x1
    out = im.copy()
    piece = im.crop((x0, y0, x1 + 1, y1 + 1))
    if not keep:
        clear = blank(x1 - x0 + 1, y1 - y0 + 1)
        out.paste(clear, (x0, y0))
    paste(out, piece, x0 + dx, y0 + dy)
    return out


def put(im, points, key):
    """Set a list of (x, y) pixels to a palette key."""
    out = im.copy()
    p = out.load()
    for x, y in points:
        if 0 <= x < out.width and 0 <= y < out.height:
            p[x, y] = pal.KEY[key]
    return out


def rot90(im, times=1):
    """Rotate counter-clockwise in 90 degree steps (exact for pixel art)."""
    out = im
    for _ in range(times % 4):
        out = out.transpose(Image.ROTATE_90)
    return out
