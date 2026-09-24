#!/usr/bin/env python3
"""Generate 16 placeholder 'phone display' images for the FakeTok minigame.

Each is a 360x640 fake-TikTok frame: gradient backdrop, satirical headline
in big bold type, a fake TikTok side rail (heart/comment/share), and a
bottom caption bar. Luke will replace these with real art later.
"""
import os, random, textwrap
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.expanduser("~/workspace/taylor-unified/placeholder art/phone")
os.makedirs(OUT, exist_ok=True)

HEADLINES = [
    "Men: Are they as evil as they seem? (Yes)",
    "Heroic mother slays her 3 vile children",
    "Meet NYC's sexiest new assassin",
    "Girlboss divorces husband for oat milk latte",
    "Scientists confirm touching grass is a red flag",
    "POV: your therapist is just 3 raccoons in a trenchcoat",
    "BREAKING: water found wet, women vindicated",
    "Man discovers 'boundaries', immediately arrested",
    "Influencer cures anxiety with $400 candle (doctors HATE her)",
    "New study: 9 out of 10 boyfriends are just NPCs",
    "Girl math proves rent is actually free",
    "EXCLUSIVE: the moon is a psyop (emotional)",
    "Day in my life as a 23-year-old CEO of vibes",
    "He texted back in 4 minutes?? Red flag. Here's why",
    "Nutritionists BEG you to stop eating air (1 weird trick)",
    "Woman manifests parking spot, economy collapses",
]

BG_PAIRS = [
    ((88, 28, 135), (24, 10, 40)), ((16, 90, 120), (8, 20, 40)),
    ((140, 40, 60), (40, 8, 16)), ((30, 110, 60), (8, 30, 16)),
    ((120, 80, 16), (40, 26, 6)), ((70, 40, 140), (20, 12, 40)),
    ((150, 60, 110), (45, 15, 30)), ((20, 120, 110), (6, 35, 32)),
]

def load_font(size):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def vgrad(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        px[0, y] = 0  # placeholder, filled per-column below
    # faster: draw horizontal bands
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (w, y)], fill=c)
    return img

def main():
    random.seed(20260923)
    W, H = 360, 640
    title_font = load_font(34)
    small_font = load_font(18)
    tiny_font = load_font(14)
    for i, headline in enumerate(HEADLINES):
        top, bottom = BG_PAIRS[i % len(BG_PAIRS)]
        img = vgrad(W, H, top, bottom)
        d = ImageDraw.Draw(img)
        # vignette-ish dark bottom for the caption
        d.rectangle([0, H - 150, W, H], fill=(0, 0, 0, 255))
        # headline, wrapped, white with black outline
        lines = textwrap.wrap(headline, width=18)
        y = 150
        for line in lines:
            tw = d.textlength(line, font=title_font)
            x = (W - tw) / 2
            for ox, oy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
                d.text((x + ox, y + oy), line, font=title_font, fill=(0, 0, 0))
            d.text((x, y), line, font=title_font, fill=(255, 255, 255))
            y += 44
        # big play triangle in the middle
        cx, cy = W // 2, 400
        d.polygon([(cx - 28, cy - 36), (cx - 28, cy + 36), (cx + 36, cy)],
                  fill=(255, 255, 255, 255))
        # fake side rail: heart / comment / share circles with counts
        rx = W - 44
        for j, (glyph, count) in enumerate([("H", "1.2M"), ("C", "88K"), ("S", "402K")]):
            ry = 380 + j * 70
            d.ellipse([rx - 22, ry - 22, rx + 22, ry + 22], fill=(255, 255, 255))
            d.text((rx - 7, ry - 12), glyph, font=small_font, fill=(20, 20, 20))
            cw = d.textlength(count, font=tiny_font)
            d.text((rx - cw / 2, ry + 26), count, font=tiny_font, fill=(255, 255, 255))
        # bottom caption
        d.text((14, H - 120), "@placeholder_faketok", font=small_font, fill=(255, 255, 255))
        d.text((14, H - 92), "original sound - placeholder", font=tiny_font, fill=(220, 220, 220))
        d.text((14, H - 60), "PLACEHOLDER %d/16" % (i + 1), font=tiny_font, fill=(255, 210, 80))
        # progress bar like a video scrubber
        frac = (i + 1) / len(HEADLINES)
        d.rectangle([0, H - 8, W * frac, H], fill=(255, 60, 90))
        img.save(os.path.join(OUT, "display_%02d.png" % (i + 1)))
        print("wrote display_%02d.png" % (i + 1))

if __name__ == "__main__":
    main()
