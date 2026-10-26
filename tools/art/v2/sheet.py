"""v2 style sheet: every style-test asset enlarged on one page.

    python3 tools/art/v2/sheet.py [--fonts DIR] [--out DIR]
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import enemies  # noqa: E402
import hero  # noqa: E402
import icons  # noqa: E402
import img  # noqa: E402
import mockup  # noqa: E402
import objects  # noqa: E402
import pal  # noqa: E402
import portrait  # noqa: E402
import ui  # noqa: E402

WIDTH = 1920
PAD = 32


class Sheet:
    def __init__(self, fonts):
        self.fonts = fonts
        self.parts = []  # (image, x, y)
        self.texts = []  # (x, y, text, size, colour, bold, anchor)
        self.y = PAD

    def font(self, size, bold=True):
        name = "Sarabun-Bold.ttf" if bold else "Sarabun-Regular.ttf"
        return ImageFont.truetype(os.path.join(self.fonts["dir"], name), size, layout_engine=ImageFont.Layout.RAQM)

    def title(self, text, note=""):
        self.texts.append((PAD, self.y + 20, text, 34, "gold4", True, "lm"))
        if note:
            self.texts.append((WIDTH - PAD, self.y + 22, note, 22, "cool6", False, "rm"))
        self.y += 52

    def row(self, items, k, bg="grass4", gap=24, captions=None):
        """Sprites scaled by k (or (image, k) pairs), bottom-aligned on one band of ground colour."""
        big = [img.zoom(*i) if isinstance(i, tuple) else img.zoom(i, k) for i in items]
        h = max(b.height for b in big)
        band = Image.new("RGBA", (WIDTH - 2 * PAD, h + 32), pal.c(bg) if bg else pal.c("cool1"))
        x = 16
        for n, b in enumerate(big):
            band.alpha_composite(b, (x, 16 + h - b.height))
            if captions and captions[n]:
                self.texts.append((PAD + x + b.width / 2, self.y + h + 32 + 18, captions[n], 22, "cool7", False, "mm"))
            x += b.width + gap
        self.parts.append((band, PAD, self.y))
        self.y += band.height + (44 if captions else 20)
        return band

    def render(self):
        out = Image.new("RGBA", (WIDTH, self.y + PAD), pal.c("cool0"))
        for im, x, y in self.parts:
            out.alpha_composite(im, (x, y))
        d = ImageDraw.Draw(out)
        for (x, y, s, size, colour, bold, anchor) in self.texts:
            d.text((x, y), s, font=self.font(size, bold), fill=pal.c(colour), anchor=anchor)
        return out


def card_with_name(name, kind, level, art, k, font):
    big = img.zoom(ui.card(kind, level, art), k)
    px, py, pw, ph = ui.PLATE
    d = ImageDraw.Draw(big)
    cx, cy = (px + pw / 2) * k, (py + ph / 2) * k
    d.text((cx + k, cy + k), name, font=font, fill=pal.c("ink0"), anchor="mm")
    d.text((cx, cy), name, font=font, fill=pal.c("white"), anchor="mm")
    return big


def sheet(fonts):
    s = Sheet(fonts)
    s.title("ตัวละครและศัตรู", "กรอบ 32x48 · portrait 56x56 · ศัตรูหันซ้ายเข้าหาฮีโร่ · ขยาย 5 เท่า")
    s.row([hero.front(), hero.side(), hero.back(), (portrait.framed(60), 4),
           enemies.slime(), enemies.slime(True), enemies.wolf(), enemies.wolf(True)], 5, gap=22,
          captions=["ฮีโร่ หน้า", "ข้าง", "หลัง", "portrait บนแผงสถานะ", "สไลม์", "สไลม์ elite", "หมาป่า", "หมาป่า elite"])
    s.title("วัตถุบนแผนที่", "กรอบ 32x48 ยืนบนช่อง 32 px · ขยาย 6 เท่า")
    s.row([objects.tree(0), objects.rock(), objects.house(), objects.campfire(), objects.meadow(), objects.spring(), objects.shrine()], 6,
          gap=38, captions=["ต้นไม้", "หิน", "บ้าน", "กองไฟ (แคมป์)", "ทุ่งดอกไม้", "บ่อน้ำ", "ศาลเจ้า"])
    s.title("การ์ด", "64x88 · สีป้ายชื่อบอกประเภท · โล่ทองมุมซ้าย = เลเวล · ขยาย 3 เท่า")
    font = s.font(33)
    cards = [card_with_name(n, kind, lv, art(), 3, font) for (n, kind, lv, art) in mockup.HAND_CARDS]
    band = Image.new("RGBA", (WIDTH - 2 * PAD, cards[0].height + 32), pal.c("cool1"))
    gap = (band.width - 32 - sum(c.width for c in cards)) // (len(cards) - 1)
    x = 16
    for c in cards:
        band.alpha_composite(c, (x, 16))
        x += c.width + gap
    s.parts.append((band, PAD, s.y))
    s.y += band.height + 20
    s.title("ไอคอน", "16x16 บน HUD · 24x24 ในช่องของ/สกิล/แจ้งเตือน · ขยาย 5 เท่า")
    s.row(list(icons.SMALL.values()), 5, bg=None, gap=48)
    s.row(list(icons.BIG.values()), 5, bg=None, gap=78)
    s.title("แผนที่", "พื้นหญ้า ชายหาด คลื่น ทะเล ถนน · ขยาย 2 เท่า")
    m = mockup.map_layer()
    s.row([m.crop((96, 64, 96 + 448, 64 + 224)), m.crop((416, 96, 416 + 480 - 64, 96 + 224))], 2, bg=None, gap=32)
    return s.render()


def main():
    font_dir = os.path.join(mockup.ROOT, "assets", "art", "fonts")
    out_dir = os.path.join(mockup.ROOT, "docs", "art", "v2")
    if "--fonts" in sys.argv:
        font_dir = sys.argv[sys.argv.index("--fonts") + 1]
    if "--out" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out_dir, exist_ok=True)
    sheet({"dir": font_dir}).save(os.path.join(out_dir, "style_sheet_v2.png"), optimize=True)
    print("ok")


if __name__ == "__main__":
    main()
