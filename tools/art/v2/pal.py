"""v2 palette: hue-shifted ramps, dark to light.

Shadows lean blue/purple and highlights lean warm, so colours read less like toys
than the v1 Endesga 32 set. Every opaque pixel in a v2 sprite must be one of these.
Refer to a colour as "<ramp><index>", e.g. "skin3" or "ink1".
"""

RAMPS = {
    # outlines and the darkest darks
    "ink": ["#120e1c", "#1f1830", "#2e2445"],
    # cool neutrals: UI panels, steel, cloth whites
    "cool": ["#1a1b2e", "#262a42", "#353b5a", "#4b5476", "#6a7695", "#8f9cb5", "#b8c4d4", "#dfe6ee", "#f8fbff"],
    "skin": ["#5a2e38", "#a45a55", "#d98a76", "#f2b99a", "#fddcc4"],
    "hair": ["#141428", "#22243f", "#333a5e", "#4d5a8a", "#7a8cc0"],
    "red": ["#3d0f22", "#6e1830", "#a8263a", "#d9453f", "#f27a5e", "#ffb08f"],
    "blue": ["#0f1d3d", "#182f63", "#234a91", "#3270c2", "#5a9fe0", "#94cdf5", "#d2efff"],
    "gold": ["#3d2410", "#74461a", "#b07424", "#e0a93a", "#f7d66b", "#fff4b8"],
    "wood": ["#26171a", "#432722", "#683f2e", "#91603f", "#b98756", "#dcb47f"],
    "grass": ["#0f2a2a", "#173f33", "#22593b", "#337540", "#4f9445", "#79b24c", "#aed161", "#dbe98a"],
    "sea": ["#0b1f45", "#0f3466", "#144f8a", "#1c6fa8", "#2a93c2", "#45b6d1", "#7fd8dc", "#c4f1ea"],
    "sand": ["#6b4b3a", "#9c7352", "#c9a06b", "#e6c88e", "#f6e6b8"],
    "dirt": ["#3b2626", "#5c3b30", "#80573f", "#a57a55", "#c9a170"],
    "stone": ["#2b2530", "#463d48", "#665a62", "#8a7d80", "#ada1a0", "#d1c8c1", "#ede7df"],
    "roof": ["#3d1a1e", "#6b2a26", "#9a3f2e", "#c4603e", "#e08a5a", "#f2b386"],
    "violet": ["#1f1236", "#3a1f5e", "#5c308c", "#8550bd", "#b383e6", "#dcbcff"],
    "pink": ["#5a1e45", "#93336a", "#cf5a8f", "#f08fb5", "#ffc9dc"],
    "teal": ["#0d3038", "#145a5c", "#1f8a7d", "#3dbd9a", "#7fe3bf", "#c6f7e2"],
}

WHITE = "#ffffff"


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


COLORS = {f"{name}{i}": hx for name, ramp in RAMPS.items() for i, hx in enumerate(ramp)}
COLORS["white"] = WHITE
RGB = {name: _rgb(hx) for name, hx in COLORS.items()}
ALLOWED = set(RGB.values())


def c(name):
    """RGBA tuple for a palette name like "skin3" (or an existing RGBA tuple)."""
    if isinstance(name, tuple):
        return name if len(name) == 4 else name + (255,)
    return RGB[name] + (255,)


def ramp(name):
    return [c(f"{name}{i}") for i in range(len(RAMPS[name]))]
