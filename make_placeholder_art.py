#!/usr/bin/env python3
"""Placeholder art generator for Taylor Simulator.

Creates 16-bit-style pixel art under placeholder art/:
  Furniture/high_chair.png, changing_table.png  (baby stations; everything
      else moved to Luke's production art/furniture/)
  Sprites/*.png                  (minigame item sprites)
  phone/display_*.png            (FakeTok phone screens)

House tiles now come from tools/make_house_tiles.py ("Placeholder house
tiles" TileSet); parallax layers from tools/make_parallax.py.

Re-run any time: python3 make_placeholder_art.py
"""
import os, random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "PlaceholderArt")
TILES = os.path.join(ROOT, "Tiles")
FURN = os.path.join(ROOT, "Furniture")
SPR = os.path.join(ROOT, "Sprites")
for d in (TILES, FURN, SPR):
    os.makedirs(d, exist_ok=True)

# --- palette ---------------------------------------------------------------
O = (38, 28, 20)          # outline dark brown
WOOD_L = (200, 155, 106); WOOD_D = (138, 95, 60); WOOD_DD = (94, 64, 38)
WALL = (217, 201, 168); BRICK = (168, 91, 74)
WP_P = (232, 160, 180); WP_PD = (201, 106, 134)
WP_B = (150, 180, 220); WP_BD = (110, 140, 190)
CARPET_R = (180, 74, 74); CARPET_RD = (140, 52, 52)
CARPET_B = (74, 106, 180); CARPET_BD = (54, 80, 140)
TILE_W = (232, 232, 232); TILE_G = (150, 150, 160); KTILE = (122, 184, 217); KTILE_D = (90, 150, 185)
GRASS_L = (106, 176, 76); GRASS_D = (74, 138, 58); GRASS_DD = (58, 112, 46)
DIRT = (138, 98, 56); DIRT_D = (107, 74, 40)
CANOPY = (62, 122, 52); CANOPY_L = (90, 154, 72); CANOPY_D = (44, 94, 38)
TRUNK = (107, 74, 40); TRUNK_D = (80, 54, 28)
METAL = (184, 184, 192); METAL_D = (90, 90, 102); METAL_L = (220, 220, 228)
CARD = (200, 155, 94); CARD_D = (160, 116, 66); TAPE = (232, 217, 168)
WHITE = (244, 244, 244); PAPER = (232, 228, 212); PAPER_D = (198, 192, 168)
WATER = (90, 160, 220); WATER_D = (50, 110, 180); WATER_L = (150, 200, 240)
YELLOW = (240, 200, 80); RED = (205, 80, 80); BLUE = (80, 130, 220)
GREEN = (110, 180, 100); PURPLE = (150, 110, 190)
SKIN = (244, 200, 160)

rng = random.Random(7)

def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def R(im, x, y, w, h, c):
    ImageDraw.Draw(im).rectangle([x, y, x + w - 1, y + h - 1], fill=c)

def OR(im, x, y, w, h, c=O):
    ImageDraw.Draw(im).rectangle([x, y, x + w - 1, y + h - 1], outline=c)

def C(im, cx, cy, r, c):
    ImageDraw.Draw(im).ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)

def PX(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c + ((255,) if len(c) == 3 else ()))

def speckle(im, x, y, w, h, colors, n):
    for _ in range(n):
        PX(im, x + rng.randrange(w), y + rng.randrange(h), rng.choice(colors))

def save(im, path):
    im.save(path)
    print("wrote", os.path.relpath(path, os.path.dirname(ROOT)))

# ===========================================================================
# TILES (16px grid)
# ===========================================================================
def tile_sheet(name, painters):
    cols = 16
    rows = (len(painters) + cols - 1) // cols
    im = new(cols * 16, rows * 16)
    for i, fn in enumerate(painters):
        ox, oy = (i % cols) * 16, (i // cols) * 16
        fn(im, ox, oy)
    save(im, os.path.join(TILES, name))

def t_wood_light(im, ox, oy):
    R(im, ox, oy, 16, 16, WOOD_L); OR(im, ox, oy, 16, 16)
    for x in range(0, 16, 4):
        for y in range(16): PX(im, ox + x, oy + y, WOOD_D)
    speckle(im, ox, oy, 16, 16, [WOOD_D, WOOD_L], 14)

def t_wood_dark(im, ox, oy):
    R(im, ox, oy, 16, 16, WOOD_D); OR(im, ox, oy, 16, 16)
    for x in range(0, 16, 4):
        for y in range(16): PX(im, ox + x, oy + y, WOOD_DD)
    speckle(im, ox, oy, 16, 16, [WOOD_DD], 12)

def t_plank_v(im, ox, oy):
    R(im, ox, oy, 16, 16, WOOD_L); OR(im, ox, oy, 16, 16)
    for y in range(0, 16, 5):
        for x in range(16): PX(im, ox + x, oy + y, WOOD_D)
    PX(im, ox + 7, oy + 3, WOOD_DD); PX(im, ox + 7, oy + 11, WOOD_DD)

def t_carpet_r(im, ox, oy):
    R(im, ox, oy, 16, 16, CARPET_R); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [CARPET_RD], 40)

def t_carpet_b(im, ox, oy):
    R(im, ox, oy, 16, 16, CARPET_B); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [CARPET_BD], 40)

def t_checker(im, ox, oy):
    R(im, ox, oy, 16, 16, TILE_W); OR(im, ox, oy, 16, 16)
    R(im, ox, oy, 8, 8, TILE_G); R(im, ox + 8, oy + 8, 8, 8, TILE_G)

def t_kitchen(im, ox, oy):
    R(im, ox, oy, 16, 16, KTILE); OR(im, ox, oy, 16, 16)
    R(im, ox, oy, 16, 2, KTILE_D); R(im, ox, oy + 14, 16, 2, KTILE_D)
    PX(im, ox + 3, oy + 4, WATER_L); PX(im, ox + 11, oy + 9, WATER_L)

def t_wp_pink(im, ox, oy):
    R(im, ox, oy, 16, 16, WP_P); OR(im, ox, oy, 16, 16)
    for x in range(2, 16, 5): R(im, ox + x, oy, 2, 16, WP_PD)
    PX(im, ox + 1, oy + 3, WHITE); PX(im, ox + 9, oy + 11, WHITE)

def t_wp_blue(im, ox, oy):
    R(im, ox, oy, 16, 16, WP_B); OR(im, ox, oy, 16, 16)
    for y in range(2, 16, 5): R(im, ox, oy + y, 16, 2, WP_BD)

def t_brick(im, ox, oy):
    R(im, ox, oy, 16, 16, WALL); OR(im, ox, oy, 16, 16)
    for yy, off in ((0, 0), (5, 8), (10, 0)):
        for xx in range(-8, 16, 8):
            R(im, ox + xx + off, oy + yy, 8, 5, BRICK)
    speckle(im, ox, oy, 16, 16, [(140, 70, 58)], 10)

def t_plaster(im, ox, oy):
    R(im, ox, oy, 16, 16, WALL); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [(200, 182, 148)], 26)

def t_concrete(im, ox, oy):
    R(im, ox, oy, 16, 16, TILE_G); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [METAL_D, TILE_W], 30)

def t_window(im, ox, oy):
    R(im, ox, oy, 16, 16, WALL); OR(im, ox, oy, 16, 16)
    R(im, ox + 2, oy + 2, 12, 12, WATER); OR(im, ox + 2, oy + 2, 12, 12, WOOD_DD)
    R(im, ox + 7, oy + 2, 2, 12, WOOD_DD); R(im, ox + 2, oy + 7, 12, 2, WOOD_DD)
    PX(im, ox + 4, oy + 4, WATER_L); PX(im, ox + 5, oy + 4, WATER_L)

def t_door(im, ox, oy):
    R(im, ox, oy, 16, 16, WALL); OR(im, ox, oy, 16, 16)
    R(im, ox + 3, oy + 1, 10, 15, WOOD_D); OR(im, ox + 3, oy + 1, 10, 15)
    R(im, ox + 5, oy + 3, 6, 5, WOOD_L); R(im, ox + 5, oy + 10, 6, 4, WOOD_L)
    PX(im, ox + 11, oy + 8, YELLOW)

def t_roof(im, ox, oy):
    R(im, ox, oy, 16, 16, (52, 48, 60)); OR(im, ox, oy, 16, 16)
    for y in range(0, 16, 4):
        for x in range(16):
            if (x + y) % 8 < 4: PX(im, ox + x, oy + y, (70, 64, 80))

def t_grass_l(im, ox, oy):
    R(im, ox, oy, 16, 16, GRASS_L); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [GRASS_D, GRASS_DD], 26)

def t_grass_d(im, ox, oy):
    R(im, ox, oy, 16, 16, GRASS_D); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [GRASS_DD, GRASS_L], 26)

def t_grass_tuft(im, ox, oy):
    t_grass_l(im, ox, oy)
    for x, h in ((3, 5), (6, 7), (10, 5), (13, 6)):
        R(im, ox + x, oy + 12 - h, 2, h, GRASS_DD)

def t_grass_flower(im, ox, oy):
    t_grass_l(im, ox, oy)
    for x, y, c in ((4, 5, RED), (11, 9, YELLOW), (7, 12, WHITE)):
        PX(im, ox + x, oy + y, c); PX(im, ox + x + 1, oy + y, GRASS_DD)

def t_dirt(im, ox, oy):
    R(im, ox, oy, 16, 16, DIRT); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [DIRT_D], 34)

def t_dirt_dark(im, ox, oy):
    R(im, ox, oy, 16, 16, DIRT_D); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [DIRT], 30)

def t_path(im, ox, oy):
    R(im, ox, oy, 16, 16, (196, 170, 120)); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [(170, 144, 100), (215, 190, 140)], 36)

def t_bush(im, ox, oy):
    t_grass_l(im, ox, oy)
    C(im, ox + 8, oy + 8, 6, CANOPY); C(im, ox + 5, oy + 6, 3, CANOPY_L)
    speckle(im, ox + 2, oy + 2, 12, 12, [CANOPY_D], 12)

def t_trunk(im, ox, oy):
    t_grass_l(im, ox, oy)
    R(im, ox + 5, oy, 6, 16, TRUNK); OR(im, ox + 5, oy, 6, 16)
    for y in range(1, 16, 4): PX(im, ox + 8, oy + y, TRUNK_D)

def t_canopy_l(im, ox, oy):
    R(im, ox, oy, 16, 16, CANOPY_L); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [CANOPY, CANOPY_D], 30)

def t_canopy_d(im, ox, oy):
    R(im, ox, oy, 16, 16, CANOPY); OR(im, ox, oy, 16, 16)
    speckle(im, ox, oy, 16, 16, [CANOPY_D, CANOPY_L], 30)

def t_canopy_edge(im, ox, oy):
    t_grass_l(im, ox, oy)
    C(im, ox + 8, oy + 4, 8, CANOPY); C(im, ox + 5, oy + 2, 3, CANOPY_L)

def t_leaves(im, ox, oy):
    t_grass_d(im, ox, oy)
    speckle(im, ox, oy, 16, 16, [CANOPY_L, CANOPY], 22)

def t_stone(im, ox, oy):
    t_grass_l(im, ox, oy)
    R(im, ox + 3, oy + 6, 10, 7, METAL); OR(im, ox + 3, oy + 6, 10, 7)
    PX(im, ox + 5, oy + 8, METAL_L); PX(im, ox + 9, oy + 10, METAL_D)

def t_stump(im, ox, oy):
    t_grass_l(im, ox, oy)
    R(im, ox + 4, oy + 7, 8, 6, TRUNK); OR(im, ox + 4, oy + 7, 8, 6)
    R(im, ox + 4, oy + 7, 8, 2, (150, 115, 70))

def t_sapling(im, ox, oy):
    t_grass_l(im, ox, oy)
    R(im, ox + 7, oy + 6, 2, 8, TRUNK_D)
    C(im, ox + 8, oy + 5, 4, CANOPY_L); PX(im, ox + 6, oy + 3, CANOPY)

# NOTE: house_tiles/tree_tiles sheets retired 2026-09-24 — the house now
# uses Tiles/Housetileset.png and the "Placeholder house tiles" TileSet.

# ===========================================================================
# FURNITURE (station + decor sprites)
# ===========================================================================
def furniture(name, w, h, fn):
    im = new(w, h)
    fn(im)
    save(im, os.path.join(FURN, name))

def f_washer(im):  # 48x56 laundry
    w, h = 48, 56
    R(im, 2, 2, w - 4, h - 2, METAL_L); OR(im, 2, 2, w - 4, h - 2)
    R(im, 2, 2, w - 4, 10, METAL); R(im, 34, 4, 8, 6, (60, 60, 70))
    C(im, w // 2, 34, 14, METAL_D); C(im, w // 2, 34, 11, (40, 50, 70))
    C(im, w // 2 - 3, 31, 4, WATER_L)
    R(im, 6, h - 6, 8, 4, METAL_D); R(im, w - 14, h - 6, 8, 4, METAL_D)

def f_dryer(im):  # 48x56 laundry pair
    w, h = 48, 56
    R(im, 2, 2, w - 4, h - 2, WHITE); OR(im, 2, 2, w - 4, h - 2)
    R(im, 2, 2, w - 4, 10, PAPER_D); R(im, 6, 4, 8, 6, RED)
    C(im, w // 2, 34, 14, METAL_D); C(im, w // 2, 34, 11, (200, 170, 120))
    C(im, w // 2 - 3, 31, 4, (240, 220, 170))

def f_sink(im):  # 56x48 dishes
    w, h = 56, 48
    R(im, 2, 18, w - 4, h - 20, WOOD_D); OR(im, 2, 18, w - 4, h - 20)
    R(im, 2, 18, w - 4, 6, METAL_L); OR(im, 2, 18, w - 4, 6)
    R(im, 12, 24, w - 24, 12, METAL_D); OR(im, 12, 24, w - 24, 12)
    R(im, 14, 26, w - 28, 3, WATER)
    R(im, w // 2 - 3, 2, 6, 16, METAL); OR(im, w // 2 - 3, 2, 6, 16)
    R(im, w // 2 - 3, 2, 12, 5, METAL); OR(im, w // 2 - 3, 2, 12, 5)
    PX(im, w // 2 + 6, 9, WATER); PX(im, w // 2 + 6, 12, WATER)

def f_bookshelf(im):  # 48x64 book
    w, h = 48, 64
    R(im, 2, 2, w - 4, h - 2, WOOD_D); OR(im, 2, 2, w - 4, h - 2)
    cols = [RED, BLUE, GREEN, YELLOW, PURPLE, (220, 130, 60)]
    for s in range(3):
        y = 8 + s * 18
        R(im, 5, y + 14, w - 10, 3, WOOD_DD)
        x = 6
        i = s * 2
        while x < w - 10:
            bw = 4 + (i * 3) % 3
            R(im, x, y, bw, 14, cols[i % len(cols)]); OR(im, x, y, bw, 14)
            x += bw + 1; i += 1

def f_high_chair(im):  # 36x52 feed_baby
    w, h = 36, 52
    R(im, 6, h - 6, 5, 6, WOOD_DD); R(im, w - 11, h - 6, 5, 6, WOOD_DD)
    R(im, 8, 20, w - 16, 4, WOOD_D)
    R(im, 4, 8, w - 8, 12, RED); OR(im, 4, 8, w - 8, 12)
    R(im, 4, 4, w - 8, 6, WOOD_D); OR(im, 4, 4, w - 8, 6)
    R(im, 2, 16, w - 4, 5, WOOD_L); OR(im, 2, 16, w - 4, 5)

def f_changing_table(im):  # 56x48 change_baby
    w, h = 56, 48
    R(im, 4, h - 8, 6, 8, WOOD_DD); R(im, w - 10, h - 8, 6, 8, WOOD_DD)
    R(im, 2, 22, w - 4, 6, WOOD_D); OR(im, 2, 22, w - 4, 6)
    R(im, 6, 8, w - 12, 14, (150, 190, 230)); OR(im, 6, 8, w - 12, 14)
    R(im, 6, 8, w - 12, 4, (120, 165, 210))
    R(im, w - 20, 24, 12, 8, WHITE); OR(im, w - 20, 24, 12, 8)
    R(im, 8, 30, 14, 10, WOOD_L); OR(im, 8, 30, 14, 10)
    R(im, 10, 32, 10, 2, PURPLE)

def f_phone(im):  # 28x44 phone (tiktok)
    w, h = 28, 44
    R(im, 2, 2, w - 4, h - 2, (40, 40, 50)); OR(im, 2, 2, w - 4, h - 2)
    R(im, 5, 7, w - 10, h - 16, (120, 200, 240))
    PX(im, 8, 10, WHITE); PX(im, 12, 14, RED); PX(im, 16, 20, YELLOW)
    C(im, w // 2, h - 5, 2, METAL_D)

def f_toilet(im):  # 36x60 basement_toilet
    w, h = 36, 60
    R(im, 8, 2, w - 16, 16, WHITE); OR(im, 8, 2, w - 16, 16)
    R(im, 14, 5, 8, 3, METAL)
    R(im, 4, 20, w - 8, 14, WHITE); OR(im, 4, 20, w - 8, 14)
    R(im, 8, 23, w - 16, 8, WATER); OR(im, 8, 23, w - 16, 8)
    R(im, 10, 34, w - 20, 24, WHITE); OR(im, 10, 34, w - 20, 24)
    R(im, 6, h - 4, w - 12, 4, PAPER_D)

def f_mop_bucket(im):  # 44x52 mop_kitchen
    w, h = 44, 52
    R(im, 26, 2, 4, 34, WOOD_L); OR(im, 26, 2, 4, 34)
    for i in range(6):
        R(im, 20 + i * 2, 34, 3, 12, PAPER_D if i % 2 else PAPER)
    R(im, 6, 30, 20, 20, RED); OR(im, 6, 30, 20, 20)
    R(im, 6, 30, 20, 4, (160, 50, 50))
    R(im, 8, 36, 16, 8, WATER)

def f_trash_can(im):  # 36x52 take_out_trash
    w, h = 36, 52
    R(im, 2, 8, w - 4, 6, METAL_D); OR(im, 2, 8, w - 4, 6)
    R(im, 12, 2, 12, 8, METAL_D); OR(im, 12, 2, 12, 8)
    R(im, 6, 14, w - 12, h - 16, METAL); OR(im, 6, 14, w - 12, h - 16)
    for y in range(18, h - 4, 6): R(im, 8, y, w - 16, 2, METAL_D)
    PX(im, 10, 20, METAL_L)

def f_microwave(im):  # 52x36 microwave
    w, h = 52, 36
    R(im, 2, 2, w - 4, h - 2, METAL_D); OR(im, 2, 2, w - 4, h - 2)
    R(im, 5, 6, w - 22, h - 12, (30, 30, 40)); OR(im, 5, 6, w - 22, h - 12)
    R(im, 7, 8, w - 26, h - 16, (90, 110, 140))
    PX(im, 10, 11, WATER_L); PX(im, 14, 11, WATER_L)
    for i in range(3):
        R(im, w - 13, 7 + i * 7, 7, 4, GREEN if i == 0 else METAL_L)

def f_box_stack(im):  # 60x52 amazon_boxes
    w, h = 60, 52
    def box(x, y, bw, bh):
        R(im, x, y, bw, bh, CARD); OR(im, x, y, bw, bh)
        R(im, x + bw // 2 - 2, y, 4, bh, TAPE)
        R(im, x, y, bw, 3, (220, 175, 110))
    box(4, h - 22, 30, 20); box(28, h - 40, 28, 20); box(8, h - 52 + 12 - 8, 24, 16)

def f_bed(im):  # 72x52 decor
    w, h = 72, 52
    R(im, 2, 6, 8, h - 8, WOOD_D); OR(im, 2, 6, 8, h - 8)
    R(im, w - 10, 14, 8, h - 16, WOOD_D); OR(im, w - 10, 14, 8, h - 16)
    R(im, 8, 24, w - 16, h - 26, WOOD_L); OR(im, 8, 24, w - 16, h - 26)
    R(im, 10, 10, 20, 12, WHITE); OR(im, 10, 10, 20, 12)
    R(im, 28, 24, w - 36, h - 26, (90, 130, 200)); OR(im, 28, 24, w - 36, h - 26)
    R(im, 28, 24, w - 36, 5, (120, 160, 220))

def f_couch(im):  # 72x44 decor
    w, h = 72, 44
    R(im, 2, 8, w - 4, 22, (150, 90, 60)); OR(im, 2, 8, w - 4, 22)
    R(im, 2, 2, 12, 30, (140, 82, 54)); OR(im, 2, 2, 12, 30)
    R(im, w - 14, 2, 12, 30, (140, 82, 54)); OR(im, w - 14, 2, 12, 30)
    R(im, 14, 12, 18, 18, (165, 100, 66)); OR(im, 14, 12, 18, 18)
    R(im, w - 32, 12, 18, 18, (165, 100, 66)); OR(im, w - 32, 12, 18, 18)
    R(im, 6, h - 8, 8, 8, WOOD_DD); R(im, w - 14, h - 8, 8, 8, WOOD_DD)

def f_table(im):  # 64x44 decor
    w, h = 64, 44
    R(im, 2, 16, w - 4, 8, WOOD_L); OR(im, 2, 16, w - 4, 8)
    R(im, 8, 24, 6, h - 24, WOOD_D); R(im, w - 14, 24, 6, h - 24, WOOD_D)
    R(im, 20, 8, 14, 8, WHITE); OR(im, 20, 8, 14, 8)
    PX(im, 40, 10, RED); PX(im, 44, 12, YELLOW)

def f_lamp(im):  # 28x52 decor
    w, h = 28, 52
    R(im, w // 2 - 2, 22, 4, h - 26, METAL_D)
    R(im, w // 2 - 8, h - 8, 16, 5, METAL_D); OR(im, w // 2 - 8, h - 8, 16, 5)
    R(im, 4, 4, w - 8, 20, YELLOW); OR(im, 4, 4, w - 8, 20)
    R(im, 7, 7, w - 14, 14, (250, 230, 150))

def f_tv(im):  # 60x44 decor
    w, h = 60, 44
    R(im, 20, h - 8, 20, 8, WOOD_DD)
    R(im, 2, 2, w - 4, h - 12, (40, 40, 50)); OR(im, 2, 2, w - 4, h - 12)
    R(im, 6, 6, w - 12, h - 20, (110, 160, 210))
    PX(im, 12, 12, WHITE); PX(im, 30, 20, RED); PX(im, 40, 16, YELLOW)

def f_fridge(im):  # 44x68 decor
    w, h = 44, 68
    R(im, 2, 2, w - 4, h - 2, WHITE); OR(im, 2, 2, w - 4, h - 2)
    R(im, 2, 2, w - 4, 22, METAL_L); OR(im, 2, 2, w - 4, 22)
    R(im, 2, 24, w - 4, 2, METAL_D)
    R(im, 6, 8, 3, 10, METAL_D); R(im, 6, 30, 3, 14, METAL_D)
    PX(im, 30, 40, (200, 220, 240))

def f_crib(im):  # 60x44 decor
    w, h = 60, 44
    R(im, 2, 30, w - 4, 6, WOOD_L); OR(im, 2, 30, w - 4, 6)
    for x in range(4, w - 4, 6): R(im, x, 8, 3, 24, WOOD_L)
    R(im, 2, 6, w - 4, 4, WOOD_D); OR(im, 2, 6, w - 4, 4)
    R(im, 20, 32, 20, 4, (150, 190, 230))

furniture("high_chair.png", 36, 52, f_high_chair)
furniture("changing_table.png", 56, 48, f_changing_table)
print("furniture done")

# ===========================================================================
# SPRITES (minigame items)
# ===========================================================================
def sprite(name, w, h, fn):
    im = new(w, h)
    fn(im)
    save(im, os.path.join(SPR, name))

def s_amazon_box(im):  # 44x36
    w, h = 44, 36
    R(im, 2, 6, w - 4, h - 8, CARD); OR(im, 2, 6, w - 4, h - 8)
    R(im, 2, 6, w - 4, 4, (220, 175, 110))
    R(im, w // 2 - 2, 6, 4, h - 8, TAPE)
    R(im, 2, 2, 10, 4, CARD_D); R(im, w - 12, 2, 10, 4, CARD_D)

def s_ball(im):  # 18x18
    C(im, 9, 9, 8, RED); C(im, 7, 7, 5, (230, 120, 120))
    PX(im, 6, 5, WHITE); PX(im, 7, 4, WHITE)
    d = ImageDraw.Draw(im)
    d.arc([2, 2, 16, 16], 200, 340, fill=O)

def s_garbage_ball(im):  # 26x26 crumpled paper
    C(im, 13, 13, 11, PAPER); C(im, 9, 10, 6, PAPER_D); C(im, 17, 15, 5, WHITE)
    speckle(im, 3, 3, 20, 20, [PAPER_D, O], 18)
    d = ImageDraw.Draw(im)
    d.arc([4, 4, 22, 22], 0, 360, fill=O)

def s_garbage_pile(im):  # 48x32
    C(im, 14, 22, 9, PAPER_D); C(im, 26, 20, 10, PAPER); C(im, 36, 23, 7, PAPER_D)
    PX(im, 26, 12, GREEN); PX(im, 30, 14, GREEN)
    R(im, 10, 26, 30, 3, (160, 150, 130))

def s_diaper(im):  # 36x28
    w, h = 36, 28
    R(im, 4, 4, w - 8, h - 8, WHITE); OR(im, 4, 4, w - 8, h - 8)
    R(im, 4, h // 2 - 3, w - 8, 6, (225, 230, 240))
    R(im, 2, 2, 6, 8, (200, 210, 225)); OR(im, 2, 2, 6, 8)
    R(im, w - 8, 2, 6, 8, (200, 210, 225)); OR(im, w - 8, 2, 6, 8)

def s_powder(im):  # 24x36 bottle
    w, h = 24, 36
    R(im, 8, 2, 8, 6, (180, 140, 200)); OR(im, 8, 2, 8, 6)
    R(im, 4, 8, w - 8, h - 10, (235, 220, 245)); OR(im, 4, 8, w - 8, h - 10)
    R(im, 4, 16, w - 8, 10, (150, 110, 190))
    PX(im, 7, 12, WHITE); PX(im, 7, 20, WHITE)

def s_wipe(im):  # 32x24 packet
    w, h = 32, 24
    R(im, 2, 4, w - 4, h - 8, (120, 180, 235)); OR(im, 2, 4, w - 4, h - 8)
    R(im, w // 2 - 6, h // 2 - 4, 12, 8, WHITE); OR(im, w // 2 - 6, h // 2 - 4, 12, 8)
    R(im, 2, 4, w - 4, 4, (90, 150, 210))

def s_clothes(im):  # 36x36 onesie
    w, h = 36, 36
    R(im, 10, 6, 16, 22, GREEN); OR(im, 10, 6, 16, 22)
    R(im, 2, 8, 8, 10, GREEN); OR(im, 2, 8, 8, 10)
    R(im, w - 10, 8, 8, 10, GREEN); OR(im, w - 10, 8, 8, 10)
    R(im, 14, 26, 8, 6, GREEN); OR(im, 14, 26, 8, 6)
    for x in (15, 19):
        PX(im, x, 29, (60, 120, 60))
    PX(im, 14, 10, YELLOW); PX(im, 21, 10, YELLOW)

def s_basket(im):  # 48x40 laundry basket
    w, h = 48, 40
    R(im, 4, 10, w - 8, h - 12, (170, 120, 70)); OR(im, 4, 10, w - 8, h - 12)
    for y in range(14, h - 4, 6):
        for x in range(8, w - 8, 8):
            R(im, x, y, 4, 3, WOOD_DD)
    R(im, 2, 6, w - 4, 6, WOOD_D); OR(im, 2, 6, w - 4, 6)

def s_shirt(im):  # 36x32 garment (tintable white base)
    w, h = 36, 32
    R(im, 11, 6, 14, 22, (235, 235, 240)); OR(im, 11, 6, 14, 22)
    R(im, 3, 8, 8, 10, (235, 235, 240)); OR(im, 3, 8, 8, 10)
    R(im, w - 11, 8, 8, 10, (235, 235, 240)); OR(im, w - 11, 8, 8, 10)
    R(im, 14, 6, 8, 4, (210, 210, 220))

def s_pants(im):  # 30x36 garment
    w, h = 30, 36
    R(im, 7, 4, 16, 12, (225, 225, 235)); OR(im, 7, 4, 16, 12)
    R(im, 7, 14, 7, 18, (225, 225, 235)); OR(im, 7, 14, 7, 18)
    R(im, 16, 14, 7, 18, (225, 225, 235)); OR(im, 16, 14, 7, 18)

def s_sock(im):  # 22x28 garment
    w, h = 22, 28
    R(im, 6, 2, 9, 16, (235, 235, 240)); OR(im, 6, 2, 9, 16)
    R(im, 6, 14, 14, 8, (235, 235, 240)); OR(im, 6, 14, 14, 8)
    R(im, 6, 2, 9, 4, (210, 210, 220))

def s_drop(im):  # 28x36 water drop (whack-a-leak)
    w, h = 28, 36
    C(im, w // 2, h - 12, 9, WATER)
    R(im, w // 2 - 6, 8, 12, 12, WATER)
    for i in range(6):
        R(im, w // 2 - 6 + i, 8 - i * 2, 12 - i * 2, 2, WATER)
    PX(im, w // 2 - 4, h - 15, WATER_L); PX(im, w // 2 - 3, h - 13, WATER_L)
    d = ImageDraw.Draw(im)
    d.arc([w // 2 - 9, h - 21, w // 2 + 9, h - 3], 0, 360, fill=WATER_D)

def s_dirt(im):  # 28x20 grime splotch (microwave)
    C(im, 14, 10, 9, (82, 56, 30)); C(im, 9, 8, 5, (100, 70, 38))
    C(im, 19, 12, 4, (70, 48, 26))

def s_sponge(im):  # 36x28 brush cursor (microwave)
    w, h = 36, 28
    R(im, 2, 8, w - 4, h - 10, YELLOW); OR(im, 2, 8, w - 4, h - 10)
    speckle(im, 4, 10, w - 8, h - 14, [(210, 170, 60)], 30)
    R(im, 2, h - 8, w - 4, 6, (200, 150, 80)); OR(im, 2, h - 8, w - 4, 6)

def s_bottle(im):  # 24x40 recyclable
    w, h = 24, 40
    R(im, 9, 2, 6, 6, (150, 190, 220)); OR(im, 9, 2, 6, 6)
    R(im, 6, 8, 12, h - 10, (170, 210, 235)); OR(im, 6, 8, 12, h - 10)
    R(im, 6, 18, 12, 8, (120, 170, 210))
    PX(im, 8, 12, WATER_L)

def s_can(im):  # 24x32 recyclable
    w, h = 24, 32
    R(im, 5, 4, 14, h - 8, METAL_L); OR(im, 5, 4, 14, h - 8)
    R(im, 5, 10, 14, 10, RED)
    R(im, 5, 4, 14, 3, METAL_D)

def s_newspaper(im):  # 36x28 recyclable
    w, h = 36, 28
    R(im, 3, 5, w - 6, h - 10, PAPER); OR(im, 3, 5, w - 6, h - 10)
    for y in (9, 14, 19):
        R(im, 7, y, w - 14, 2, PAPER_D)

def s_banana(im):  # 34x24 trash
    w, h = 34, 24
    R(im, 4, 12, 10, 4, YELLOW); R(im, 20, 12, 10, 4, YELLOW)
    R(im, 12, 8, 10, 8, (225, 185, 70)); OR(im, 12, 8, 10, 8)
    PX(im, 4, 11, (160, 120, 50)); PX(im, 30, 11, (160, 120, 50))

def s_fishbone(im):  # 38x20 trash
    w, h = 38, 20
    R(im, 4, 9, w - 8, 2, PAPER_D)
    for x in range(8, w - 8, 6):
        R(im, x, 4, 2, 5, PAPER_D); R(im, x, 11, 2, 5, PAPER_D)
    R(im, w - 8, 5, 6, 10, PAPER_D); OR(im, w - 8, 5, 6, 10)

def s_styrofoam(im):  # 32x24 trash
    w, h = 32, 24
    R(im, 4, 8, w - 8, h - 14, WHITE); OR(im, 4, 8, w - 8, h - 14)
    speckle(im, 6, 10, w - 12, h - 18, [PAPER_D], 20)

def s_glass(im):  # 34x22 broken glass (trash)
    w, h = 34, 22
    for i, (x, y, ww, hh) in enumerate([(4, 10, 10, 8), (14, 6, 8, 10), (22, 10, 8, 8)]):
        R(im, x, y, ww, hh, (150, 190, 215)); OR(im, x, y, ww, hh)
        PX(im, x + 2, y + 2, WHITE)

def s_cardboard(im):  # 36x26 flat cardboard (recycle)
    w, h = 36, 26
    R(im, 3, 6, w - 6, h - 12, CARD); OR(im, 3, 6, w - 6, h - 12)
    R(im, 3, 6, w - 6, 3, (220, 175, 110))
    R(im, w // 2 - 2, 6, 4, h - 12, TAPE)

def s_chipbag(im):  # 30x34 chip bag (trash)
    w, h = 30, 34
    R(im, 5, 4, w - 10, h - 8, RED); OR(im, 5, 4, w - 10, h - 8)
    R(im, 5, 4, w - 10, 5, (230, 120, 120))
    R(im, 8, 14, w - 16, 8, YELLOW); OR(im, 8, 14, w - 16, 8)

def s_milkjug(im):  # 26x40 milk jug (recycle)
    w, h = 26, 40
    R(im, 9, 2, 8, 6, WHITE); OR(im, 9, 2, 8, 6)
    R(im, 5, 8, 16, h - 10, WHITE); OR(im, 5, 8, 16, h - 10)
    R(im, 5, 18, 16, 10, (150, 190, 235))
    PX(im, 8, 12, (200, 225, 245))

def s_battery(im):  # 20x34 battery (trash)
    w, h = 20, 34
    R(im, 7, 2, 6, 4, METAL_D)
    R(im, 4, 6, 12, h - 10, (60, 180, 80)); OR(im, 4, 6, 12, h - 10)
    R(im, 4, h - 12, 12, 6, (40, 40, 50))
    PX(im, 7, 12, WHITE)

sprite("amazon_box.png", 44, 36, s_amazon_box)
sprite("ball.png", 18, 18, s_ball)
sprite("garbage_ball.png", 26, 26, s_garbage_ball)
sprite("diaper.png", 36, 28, s_diaper)
sprite("baby_powder.png", 24, 36, s_powder)
sprite("baby_wipe.png", 32, 24, s_wipe)
sprite("baby_clothes.png", 36, 36, s_clothes)
sprite("laundry_basket.png", 48, 40, s_basket)
sprite("garment_shirt.png", 36, 32, s_shirt)
sprite("garment_pants.png", 30, 36, s_pants)
sprite("garment_sock.png", 22, 28, s_sock)
sprite("leak_drop.png", 28, 36, s_drop)
sprite("dirt_spot.png", 28, 20, s_dirt)
sprite("sponge.png", 36, 28, s_sponge)
sprite("bottle_recycle.png", 24, 40, s_bottle)
sprite("can_recycle.png", 24, 32, s_can)
sprite("newspaper.png", 36, 28, s_newspaper)
sprite("banana_peel.png", 34, 24, s_banana)
sprite("styrofoam.png", 32, 24, s_styrofoam)
sprite("glass_shard.png", 34, 22, s_glass)
sprite("cardboard_flat.png", 36, 26, s_cardboard)
sprite("chip_bag.png", 30, 34, s_chipbag)
sprite("milk_jug.png", 26, 40, s_milkjug)
sprite("battery.png", 20, 34, s_battery)
print("sprites done")
print("ALL PLACEHOLDER ART GENERATED")
