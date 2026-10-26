"""Block out a sprite from 3D ellipsoids and capsules, then cel-shade it to palette ramps.

Screen axes: x right, y down, z toward the viewer. The light comes from the top left
and a little from the front, matching the hand-drawn sprites. Each part is drawn into a
z-buffer, so near parts cover far ones and get a contour line where depth jumps.
"""

import math

import numpy as np
from PIL import Image

import pal

LIGHT = np.array([-0.55, -0.7, 0.55])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


class Material:
    def __init__(self, ramp, bias=0.0, contrast=1.0, line=None, spec=None, spec_at=0.93, edge=None, facets=0):
        """ramp: palette names dark to light. line: colour for contour lines on this part
        (defaults to the ramp's darkest). edge: outline colour outside this part (defaults
        to the scene outline). spec: highlight colour for the brightest spots.
        facets: snap normals to this many directions for a cut-stone look."""
        self.ramp = list(ramp)
        self.bias = bias
        self.contrast = contrast
        self.line = line or self.ramp[0]
        self.spec = spec
        self.spec_at = spec_at
        self.edge = edge
        self.facets = facets


class Scene:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.z = np.full((h, w), -np.inf)
        self.n = np.zeros((h, w, 3))
        self.mat = np.full((h, w), -1, dtype=int)
        self.mats = []
        ys, xs = np.mgrid[0:h, 0:w]
        self.px = xs + 0.5
        self.py = ys + 0.5
        self.paint = {}  # (x, y) -> palette name, applied after shading

    def material(self, *a, **k):
        self.mats.append(Material(*a, **k))
        return len(self.mats) - 1

    # --- primitives -------------------------------------------------------------------

    def ellipsoid(self, cx, cy, cz, rx, ry, rz, mat, rot=0.0, clip=None):
        """rot: degrees, turns the ellipse in the screen plane. clip(px, py) -> bool mask to keep."""
        dx = self.px - cx
        dy = self.py - cy
        if rot:
            a = math.radians(rot)
            ca, sa = math.cos(a), math.sin(a)
            dx, dy = dx * ca + dy * sa, -dx * sa + dy * ca
        q = (dx / rx) ** 2 + (dy / ry) ** 2
        inside = q <= 1.0
        if clip is not None:
            inside &= clip(self.px, self.py)
        zz = cz + rz * np.sqrt(np.clip(1.0 - q, 0.0, 1.0))
        nx = dx / rx**2
        ny = dy / ry**2
        nz = (zz - cz) / rz**2
        if rot:
            nx, ny = nx * ca - ny * sa, nx * sa + ny * ca
        self._put(inside, zz, nx, ny, nz, mat)

    def sphere(self, cx, cy, cz, r, mat, **k):
        self.ellipsoid(cx, cy, cz, r, r, r, mat, **k)

    def capsule(self, p0, p1, r0, r1, mat, step=0.35):
        """Tapered tube between two 3D points, built from spheres."""
        (x0, y0, z0), (x1, y1, z1) = p0, p1
        length = math.dist(p0, p1)
        n = max(2, int(length / step) + 1)
        for i in range(n):
            t = i / (n - 1)
            self.sphere(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z0 + (z1 - z0) * t, r0 + (r1 - r0) * t, mat)

    def chain(self, points, radii, mat):
        """Capsules through a list of 3D points with a radius per point."""
        for i in range(len(points) - 1):
            self.capsule(points[i], points[i + 1], radii[i], radii[i + 1], mat)

    def box(self, x0, y0, x1, y1, z, mat, normal=(0, 0, 1)):
        """Flat rectangle facing `normal` at depth z (for walls, planks)."""
        m = (self.px >= x0) & (self.px < x1) & (self.py >= y0) & (self.py < y1)
        zz = np.full_like(self.px, float(z))
        n = np.array(normal, dtype=float)
        n /= np.linalg.norm(n)
        self._put(m, zz, np.full_like(zz, n[0]), np.full_like(zz, n[1]), np.full_like(zz, n[2]), mat)

    def poly(self, pts, z, mat, normal=(0, 0, 1)):
        """Flat polygon (screen points) at depth z facing `normal`."""
        from PIL import ImageDraw

        im = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([(x, y) for x, y in pts], fill=255)
        m = np.array(im) > 0
        zz = np.full_like(self.px, float(z))
        n = np.array(normal, dtype=float)
        n /= np.linalg.norm(n)
        self._put(m, zz, np.full_like(zz, n[0]), np.full_like(zz, n[1]), np.full_like(zz, n[2]), mat)

    def _put(self, inside, zz, nx, ny, nz, mat):
        upd = inside & (zz > self.z)
        if not upd.any():
            return
        ln = np.sqrt(nx**2 + ny**2 + nz**2) + 1e-9
        self.z[upd] = zz[upd]
        self.n[upd, 0] = (nx / ln)[upd]
        self.n[upd, 1] = (ny / ln)[upd]
        self.n[upd, 2] = (nz / ln)[upd]
        self.mat[upd] = mat

    # --- output -----------------------------------------------------------------------

    def shade_index(self):
        n = self.n.copy()
        for mi, m in enumerate(self.mats):
            if m.facets:
                sel = self.mat == mi
                n[sel] = _snap(n[sel], m.facets)
        lam = np.einsum("hwc,c->hw", n, LIGHT)
        return 0.5 * lam + 0.5  # half lambert: 0 = facing away, 1 = facing the light

    def render(self, outline="ink1", edge=2.0, lines=True):
        h, w = self.h, self.w
        out = np.zeros((h, w, 4), dtype=np.uint8)
        s = self.shade_index()
        for mi, m in enumerate(self.mats):
            sel = self.mat == mi
            if not sel.any():
                continue
            v = np.clip((s[sel] - 0.5) * m.contrast + 0.5 + m.bias, 0.0, 0.9999)
            idx = (v * len(m.ramp)).astype(int)
            cols = np.array([pal.c(c) for c in m.ramp], dtype=np.uint8)
            px = cols[idx]
            if m.spec:
                hot = s[sel] >= m.spec_at
                px[hot] = pal.c(m.spec)
            out[sel] = px
        solid = self.mat >= 0
        if lines:
            # contour where a neighbour is much nearer: draw the line on the far pixel
            zs = np.where(solid, self.z, -1e9)
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                zn = np.roll(np.roll(zs, dy, 0), dx, 1)
                far = solid & (zn > -1e8) & (zn - zs > edge)
                for mi, m in enumerate(self.mats):
                    sel = far & (self.mat == mi)
                    out[sel] = pal.c(m.line)
        if outline:
            grow = np.zeros_like(solid)
            src = np.full(self.mat.shape, -1)
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nb = np.roll(np.roll(self.mat, dy, 0), dx, 1)
                take = (src < 0) & (nb >= 0)
                src[take] = nb[take]
            ring = (src >= 0) & ~solid
            out[ring] = pal.c(outline)
            for mi, m in enumerate(self.mats):
                if m.edge:
                    out[ring & (src == mi)] = pal.c(m.edge)
        im = Image.fromarray(out, "RGBA").copy()
        px = im.load()
        for (x, y), name in self.paint.items():
            px[x, y] = pal.c(name) if name else (0, 0, 0, 0)
        return im


def _snap(n, k):
    """Snap unit normals to k fixed directions spread over the front hemisphere."""
    dirs = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(k):
        z = 1 - (i + 0.5) / k  # 1 .. 0: front hemisphere only
        r = math.sqrt(1 - z * z)
        dirs.append((r * math.cos(golden * i), r * math.sin(golden * i), z))
    d = np.array(dirs)
    best = np.argmax(n @ d.T, axis=1)
    return d[best]


def add_outline(im, color="ink1"):
    a = np.array(im)
    solid = a[..., 3] > 0
    grow = np.zeros_like(solid)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        grow |= np.roll(np.roll(solid, dy, 0), dx, 1)
    a[grow & ~solid] = pal.c(color)
    return Image.fromarray(a, "RGBA").copy()


def spikes(im, keep, every=3, length=2, lean=1, phase=0):
    """Grow fur tufts up from the top edge: at every `every` columns where keep(x, y) holds,
    extend the edge pixel `length` px up, leaning `lean` px sideways per step."""
    a = np.array(im)
    alpha = a[..., 3] > 0
    h, w = alpha.shape
    out = a.copy()
    for x in range(w):
        if (x + phase) % every:
            continue
        ys = np.nonzero(alpha[:, x])[0]
        if not len(ys):
            continue
        y = ys[0]
        if not keep(x, y):
            continue
        col = a[y, x]
        for k in range(1, length + 1):
            xx = x + lean * k // 2 if lean else x
            yy = y - k
            if 0 <= xx < w and 0 <= yy < h and not alpha[yy, xx]:
                out[yy, xx] = col
    return Image.fromarray(out, "RGBA").copy()
