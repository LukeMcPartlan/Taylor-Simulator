#!/usr/bin/env python3
"""Generates placeholder parallax background layers.

Output: parralaxing placeholders/
  sky.png        960x540 vertical gradient sky
  sun.png        256x256 sun disc with glow (transparent)
  clouds.png     1920x270 tileable cloud strip (transparent)
  mountains.png  1920x270 distant mountain silhouettes (transparent)
  hills.png      1920x270 rolling hills (transparent)
  forest.png     1920x270 distant forest treeline (transparent)

All strips are SEAMLESS horizontally (periodic features), so they tile
cleanly with ParallaxLayer motion_mirroring.

Re-run any time: python3 tools/make_parallax.py
"""
import math
import os
import random

from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "parralaxing placeholders")
os.makedirs(OUT, exist_ok=True)

rng = random.Random(4242)
W, H = 1920, 270


def save(im, name):
    p = os.path.join(OUT, name)
    im.save(p)
    print("wrote", name, im.size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# --- sky: vertical gradient -----------------------------------------------
sky = Image.new("RGBA", (960, 540), (0, 0, 0, 255))
d = ImageDraw.Draw(sky)
top, bottom = (70, 130, 200), (200, 230, 250)
for y in range(540):
    d.line([(0, y), (960, y)], fill=lerp(top, bottom, y / 539) + (255,))
save(sky, "sky.png")

# --- sun: disc + glow -------------------------------------------------------
sun = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
d = ImageDraw.Draw(sun)
for r, c in ((120, (255, 240, 180, 40)), (95, (255, 240, 180, 80)), (70, (255, 245, 200, 160))):
    d.ellipse([128 - r, 128 - r, 128 + r, 128 + r], fill=c)
d.ellipse([128 - 55, 128 - 55, 128 + 55, 128 + 55], fill=(255, 250, 220, 255))
save(sun, "sun.png")


# Periodic ridge height: sum of sines with integer wave counts -> tiles perfectly.
def ridge_fn(base, waves, seed):
    r = random.Random(seed)
    comps = [(n, amp, r.random() * 6.28) for n, amp in waves]  # fixed phases

    def h(x):
        y = base
        for n, amp, phase in comps:
            y += amp * math.sin(2 * math.pi * n * x / W + phase)
        return y

    return h


def ridge_polygon(h, step=8):
    pts = [(0, H)]
    x = 0
    while x <= W:
        pts.append((x, h(x)))
        x += step
    pts.append((W, H))
    return pts


def paint_clouds():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(46):
        cx = rng.randrange(W)
        cy = rng.randrange(30, 200)
        r = rng.randrange(28, 70)
        shade = rng.choice([(245, 245, 250), (235, 238, 245), (250, 250, 252)])
        alpha = rng.randrange(150, 220)
        puffs = [((rng.randrange(-r, r), rng.randrange(-r // 2, r // 2)),
                  rng.randrange(r // 2, r)) for _ in range(7)]
        for xoff in (-W, 0, W):  # wrap copies -> seamless
            for (ox, oy), rr in puffs:
                d.ellipse([cx + xoff + ox - rr, cy + oy - rr,
                           cx + xoff + ox + rr, cy + oy + rr // 2],
                          fill=shade + (alpha,))
    return im


def paint_mountains():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # DRAMATIC: tall jagged peaks, deep valleys.
    far = ridge_fn(150, [(3, 70), (7, 22), (11, 8)], seed=11)
    d.polygon(ridge_polygon(far, step=4), fill=(110, 125, 150, 255))
    # snow caps: one hugging segment per contiguous above-snowline run
    snowline = 110
    run = []
    runs = []
    x = 0
    while x <= W:
        y = far(x)
        if y < snowline:
            run.append((x, y))
        elif run:
            runs.append(run)
            run = []
        x += 4
    if run:
        runs.append(run)
    for seg in runs:
        bottom = max(p[1] for p in seg) + 12
        cap = [(seg[0][0], bottom)] + seg + [(seg[-1][0], bottom)]
        d.polygon(cap, fill=(235, 240, 248, 255))
    near = ridge_fn(205, [(2, 60), (5, 26), (9, 10)], seed=23)
    d.polygon(ridge_polygon(near, step=4), fill=(85, 100, 125, 255))
    return im


def paint_hills():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    back = ridge_fn(225, [(2, 60), (6, 16)], seed=37)
    d.polygon(ridge_polygon(back, step=4), fill=(95, 150, 95, 255))
    front = ridge_fn(245, [(3, 50), (8, 12)], seed=51)
    d.polygon(ridge_polygon(front, step=4), fill=(80, 135, 85, 255))
    return im


def paint_forest():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 210, W, H], fill=(55, 95, 60, 255))
    for _ in range(130):
        cx = rng.randrange(W)
        h = rng.randrange(80, 185)
        w = rng.randrange(18, 34)
        col = rng.choice([(45, 85, 55), (55, 100, 62), (40, 78, 50)])
        for xoff in (-W, 0, W):  # wrap copies -> seamless
            d.polygon([(cx + xoff - w // 2, 230), (cx + xoff + w // 2, 230),
                       (cx + xoff, 230 - h)], fill=col + (255,))
            d.rectangle([cx + xoff - 3, 230, cx + xoff + 3, 245],
                        fill=(80, 60, 40, 255))
    return im


save(paint_clouds(), "clouds.png")
save(paint_mountains(), "mountains.png")
save(paint_hills(), "hills.png")
save(paint_forest(), "forest.png")
