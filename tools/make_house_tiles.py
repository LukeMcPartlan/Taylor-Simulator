#!/usr/bin/env python3
"""Generates the 'Placeholder house tiles' tile sheet + manifest.

Sheet: placeholder art/Tiles/house_tile_sheet.png (16px grid, 16 cols x 2 rows)
Manifest: placeholder art/Tiles/house_tile_sheet.json (tile name -> grid pos + flags)

Tiles:
  row 0: 4 black-marbled kitchen floor variants, 6 green / 6 brown wall paints
  row 1: 6 blue wall paints, 2 plain pink, 2 pink-panther-face (basement),
         2 stair-up-right, 2 stair-up-left (ONE-WAY collision)

Re-run any time: python3 tools/make_house_tiles.py
"""
import json
import os
import random

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(REPO, "placeholder art", "Tiles")
os.makedirs(TILES, exist_ok=True)

T = 16
rng = random.Random(20260924)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def R(im, x, y, w, h, c):
    ImageDraw.Draw(im).rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def PX(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c + ((255,) if len(c) == 3 else ()))


def speckle(im, ox, oy, colors, n):
    for _ in range(n):
        PX(im, ox + rng.randrange(T), oy + rng.randrange(T), rng.choice(colors))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


# --- painters ---------------------------------------------------------------
def p_marble(variant):
    def paint(im, ox, oy):
        base = (16, 16, 20)
        R(im, ox, oy, T, T, base)
        # marble veins: 2-3 jagged light lines
        for _ in range(2 + variant % 2):
            x, y = ox + rng.randrange(T), oy + rng.randrange(T)
            for _ in range(14):
                PX(im, x, y, (200, 200, 210) if rng.random() < 0.7 else (120, 120, 135))
                x += rng.choice((-1, 0, 1))
                y += rng.choice((-1, 0, 1))
                x = max(ox, min(ox + T - 1, x))
                y = max(oy, min(oy + T - 1, y))
        speckle(im, ox, oy, [(40, 40, 48), (90, 90, 100)], 18)
        # tile grout edge
        for i in range(T):
            PX(im, ox + i, oy + T - 1, (5, 5, 8))
            PX(im, ox + T - 1, oy + i, (5, 5, 8))
    return paint


def p_wall(color):
    def paint(im, ox, oy):
        R(im, ox, oy, T, T, color)
        # subtle top light / bottom shade
        for x in range(T):
            PX(im, ox + x, oy, shade(color, 1.12))
            PX(im, ox + x, oy + T - 1, shade(color, 0.85))
        speckle(im, ox, oy, [shade(color, 0.9), shade(color, 1.08)], 12)
    return paint


def p_pink_plain(im, ox, oy):
    p_wall((235, 150, 180))(im, ox, oy)


def p_panther_face(alt):
    def paint(im, ox, oy):
        p_wall((235, 150, 180))(im, ox, oy)
        cx, cy = ox + 8, oy + 8 + (1 if alt else 0)
        face, dark, white, black = (245, 175, 200), (215, 120, 160), (250, 250, 250), (30, 30, 30)
        # ears
        R(im, cx - 6, cy - 6, 3, 3, face); R(im, cx + 3, cy - 6, 3, 3, face)
        R(im, cx - 6, cy - 6, 3, 1, dark); R(im, cx + 3, cy - 6, 3, 1, dark)
        # head
        for dx in range(-5, 6):
            for dy in range(-4, 5):
                if dx * dx + dy * dy <= 20:
                    PX(im, cx + dx, cy + dy, face)
        # muzzle
        for dx in range(-3, 4):
            for dy in range(0, 3):
                if dx * dx + dy * dy <= 8:
                    PX(im, cx + dx, cy + 2 + dy, shade(face, 1.06))
        # eyes
        R(im, cx - 4, cy - 2, 3, 3, white); R(im, cx + 1, cy - 2, 3, 3, white)
        PX(im, cx - 3, cy - 1, black); PX(im, cx + 2, cy - 1, black)
        # nose
        PX(im, cx, cy + 2, black); PX(im, cx - 1, cy + 2, black); PX(im, cx + 1, cy + 2, black)
        # whiskers
        for sx in (-1, 1):
            for wy in (1, 3):
                for wx in range(1, 5):
                    PX(im, cx + sx * (4 + wx), cy + wy, (90, 60, 75))
    return paint


def p_stair(up_right):
    def paint(im, ox, oy):
        # 4 steps of 4px across the 16px tile
        step_c, edge = (150, 110, 75), (100, 70, 45)
        for s in range(4):
            x0 = ox + s * 4 if up_right else ox + (3 - s) * 4
            h = 4 * (s + 1)
            R(im, x0, oy + T - h, 4, h, step_c)
            for y in range(oy + T - h, oy + T):
                PX(im, x0, y, edge)
            for x in range(x0, x0 + 4):
                PX(im, x, oy + T - h, shade(step_c, 1.15))
        speckle(im, ox, oy, [(120, 88, 58)], 10)
    return paint


# --- layout -----------------------------------------------------------------
GREENS = [(74, 140, 82), (58, 120, 70), (95, 165, 100), (45, 100, 60), (110, 180, 115), (65, 130, 95)]
BROWNS = [(150, 110, 75), (130, 95, 62), (170, 130, 90), (112, 80, 52), (140, 105, 70), (120, 88, 58)]
BLUES = [(90, 140, 200), (70, 120, 180), (110, 160, 215), (55, 100, 160), (100, 150, 205), (80, 130, 190)]

painters = []   # (name, painter_fn, flags)
for i in range(4):
    painters.append(("marble_%d" % i, p_marble(i), {"collide": "full"}))
for i, c in enumerate(GREENS):
    painters.append(("wall_green_%d" % i, p_wall(c), {"collide": "full"}))
for i, c in enumerate(BROWNS):
    painters.append(("wall_brown_%d" % i, p_wall(c), {"collide": "full"}))
for i, c in enumerate(BLUES):
    painters.append(("wall_blue_%d" % i, p_wall(c), {"collide": "full"}))
for i in range(2):
    painters.append(("basement_pink_%d" % i, p_pink_plain, {"collide": "full"}))
for i in range(2):
    painters.append(("basement_panther_%d" % i, p_panther_face(i), {"collide": "full"}))
for i in range(2):
    painters.append(("stair_up_right_%d" % i, p_stair(True), {"collide": "one_way"}))
for i in range(2):
    painters.append(("stair_up_left_%d" % i, p_stair(False), {"collide": "one_way"}))

COLS = 16
rows = (len(painters) + COLS - 1) // COLS
im = new(COLS * T, rows * T)
manifest = {}
for i, (name, fn, flags) in enumerate(painters):
    ox, oy = (i % COLS) * T, (i // COLS) * T
    fn(im, ox, oy)
    manifest[name] = {"at": [i % COLS, i // COLS], "collide": flags["collide"]}

sheet_path = os.path.join(TILES, "house_tile_sheet.png")
im.save(sheet_path)
with open(os.path.join(TILES, "house_tile_sheet.json"), "w") as f:
    json.dump({"tile_size": T, "tiles": manifest}, f, indent=1)
print("wrote house_tile_sheet.png (%d tiles) + manifest" % len(painters))
