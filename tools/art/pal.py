"""Endesga 32 palette (https://lospec.com/palette-list/endesga-32) and the
one-character keys used to draw sprites as text grids.

Every pixel in the game art must be one of these 32 colors (or transparent).
"""

# key, hex, Thai/English role name
COLORS = [
    ("r", "be4a2f", "rust"),
    ("o", "d77643", "orange clay"),
    ("c", "ead4aa", "cream"),
    ("t", "e4a672", "tan / sand"),
    ("b", "b86f50", "brown"),
    ("d", "733e39", "dark brown"),
    ("D", "3e2731", "deep brown"),
    ("R", "a22633", "dark red"),
    ("e", "e43b44", "red"),
    ("O", "f77622", "orange"),
    ("y", "feae34", "amber"),
    ("Y", "fee761", "yellow"),
    ("g", "63c74d", "light green"),
    ("G", "3e8948", "green"),
    ("h", "265c42", "dark green"),
    ("H", "193c3e", "deep green"),
    ("B", "124e89", "dark blue"),
    ("u", "0099db", "blue"),
    ("a", "2ce8f5", "cyan"),
    ("w", "ffffff", "white"),
    ("l", "c0cbdc", "light grey"),
    ("s", "8b9bb4", "grey"),
    ("S", "5a6988", "slate"),
    ("n", "3a4466", "dark slate"),
    ("N", "262b44", "navy"),
    ("k", "181425", "ink (outline)"),
    ("x", "ff0044", "hot red"),
    ("p", "68386c", "purple"),
    ("m", "b55088", "magenta"),
    ("P", "f6757a", "pink"),
    ("f", "e8b796", "skin light"),
    ("F", "c28569", "skin"),
]

KEY = {k: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for k, h, _ in COLORS}
KEY["."] = (0, 0, 0, 0)
HEX = {k: h for k, h, _ in COLORS}
RGBA_TO_KEY = {v: k for k, v in KEY.items()}

# Ramps from dark to light, used for shading rules and palette swaps.
RAMPS = {
    "green": "Hhg",       # deep green, dark green, light green (+G between h and g)
    "grass": "HhGg",
    "water": "NBua",
    "earth": "Ddbtc",
    "warm": "Rrotc",
    "fire": "ReOyY",
    "stone": "kNnSslw",
    "skin": "dFf",
    "magic": "pmP",
}


def rgba(key):
    return KEY[key]
