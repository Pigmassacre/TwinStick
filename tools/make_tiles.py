#!/usr/bin/env python3
"""Draws the mine's tiles: one atlas per depth (assets/tiles/<depth>.png), its
normal map (<depth>_n.png) and what glows in it (<depth>_e.png).

The Timberworks is the original game's floor, wall and roof from
art/original; the depths below it are drawn here in the same manner (dark
outlines, few colours, 16 pixels to a tile).

    python3 tools/make_tiles.py

The layout of an atlas (`Tiles` in src/play/map_view.gd reads it the same way):

    y=0    8 floors
    y=16   8 floors, the plainer ones
    y=32   roofs by which sides are open (bit 1 north, 2 east, 4 south, 8 west), first 8
    y=48   and the other 8
    y=64   8 wall fronts, 24 high (0 to 3 plain, 4 and 5 worn, 6 cracked, 7 with a lamp bracket)
    y=88   8 overlays: rails (0 east-west, 1 north-south, 2-5 the bends), 6 and 7 scatter
    y=104  8 overlays: 0 shadow under a wall, 1 and 2 scatter, 3 rubble, 4-7 cracks and stains
"""
import os
import random
import struct
import zlib

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "assets", "tiles")
ORIG = os.path.join(REPO, "art", "original")
W, H = 128, 120


def hexc(s, a=255):
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def read_ase(path):
    """The first frame of a 32-bit .ase, as an image."""
    d = open(path, "rb").read()
    w, h, depth = struct.unpack("<HHH", d[8:14])
    p = 128
    fs, _, oldc, _, _, newc = struct.unpack("<IHHHHI", d[p:p + 16])
    q = p + 16
    im = Image.new("RGBA", (w, h))
    for _ in range(newc or oldc):
        cs, ct = struct.unpack("<IH", d[q:q + 6])
        body = d[q + 6:q + cs]
        if ct == 0x2005:
            _, x, y, _, typ = struct.unpack("<HhhBH", body[:9])
            bb = body[16:]
            if typ in (0, 2):
                cw, ch = struct.unpack("<HH", bb[:4])
                raw = bb[4:] if typ == 0 else zlib.decompress(bb[4:])
                for j in range(ch):
                    for i in range(cw):
                        c = tuple(raw[(j * cw + i) * 4:(j * cw + i + 1) * 4])
                        if c[3]:
                            im.putpixel((x + i, y + j), c)
        q += cs
    return im


class Tile:
    """A little drawing surface, with what glows on a second layer."""

    def __init__(self, w=16, h=16):
        self.w, self.h = w, h
        self.px = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px.putpixel((x, y), c)

    def light(self, x, y, c):
        self.set(x, y, c)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.glow.putpixel((x, y), c)

    def fill(self, x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.set(x, y, c)

    def get(self, x, y):
        return self.px.getpixel((x, y))


# ---------------------------------------------------------------- floors --

def speckle_floor(rng, base, darks, lights, dashes=4, dash_col=None, specks=26):
    """The original floor's manner: a dirt of few tones, with dark dashes across it."""
    t = Tile()
    for y in range(16):
        for x in range(16):
            r = rng.random()
            t.set(x, y, base[rng.randrange(len(base))] if r < 0.8 else (darks[0] if r < 0.9 else lights[0]))
    for _ in range(specks // 3):
        t.set(rng.randrange(16), rng.randrange(16), rng.choice(lights))
    for _ in range(dashes):
        x, y, n = rng.randrange(14), rng.randrange(16), rng.randrange(2, 5)
        for i in range(n):
            t.set(x + i, y, dash_col or darks[-1])
            if rng.random() < 0.35:
                t.set(x + i, y + 1, darks[0])
    return t


def flag_floor(rng, base, gap, hi, chips=2):
    """Flagstones, cut by people who cared."""
    t = Tile()
    for y in range(16):
        for x in range(16):
            t.set(x, y, base[rng.randrange(len(base))])
    split = rng.choice([7, 8, 8, 9])
    for x in range(16):
        t.set(x, split, gap)
        t.set(x, 15, gap)
    a, b = rng.randrange(4, 12), rng.randrange(4, 12)
    for y in range(split):
        t.set(a, y, gap)
    for y in range(split + 1, 15):
        t.set(b, y, gap)
    for x in range(16):
        if rng.random() < 0.5:
            t.set(x, split + 1, hi)
        if rng.random() < 0.5:
            t.set(x, 0, hi)
    for _ in range(chips):
        t.set(rng.randrange(16), rng.randrange(16), gap)
    return t


def water_floor(rng, base, deep, foam):
    """A hand's depth of black water over stone."""
    t = Tile()
    for y in range(16):
        for x in range(16):
            t.set(x, y, base[(x // 3 + y // 2 + rng.randrange(2)) % len(base)])
    for _ in range(3):
        x, y, n = rng.randrange(13), rng.randrange(16), rng.randrange(3, 7)
        for i in range(n):
            t.set(x + i, y, foam if i % 3 else deep)
    for _ in range(6):
        t.set(rng.randrange(16), rng.randrange(16), deep)
    return t


def flesh_floor(rng, base, vein, glow):
    """What the bottom of the mine has turned into."""
    t = Tile()
    for y in range(16):
        for x in range(16):
            t.set(x, y, base[rng.randrange(len(base))])
    for _ in range(2):
        x, y = rng.randrange(16), rng.randrange(16)
        for _ in range(rng.randrange(5, 11)):
            t.set(x, y, vein)
            if rng.random() < 0.07:
                t.light(x, y, glow)
            x += rng.choice([-1, 0, 1])
            y += rng.choice([-1, 0, 1])
    return t


# ----------------------------------------------------------------- walls --

def plank_wall(orig):
    """The original 16 by 16 planks, with a beam laid across their top."""
    t = Tile(16, 24)
    t.px.paste(orig, (0, 8))
    beam, hi, dark = hexc("5a3a2c"), hexc("7a5240"), hexc("2c1a14")
    t.fill(0, 0, 16, 8, beam)
    t.fill(0, 0, 16, 1, hi)
    t.fill(0, 7, 16, 8, dark)
    t.fill(0, 6, 16, 7, hexc("41281e"))
    t.set(3, 3, hexc("9a9a9e"))
    t.set(12, 3, hexc("9a9a9e"))
    return t


def facet_wall(rng, base, darks, glints, vein=None):
    """Coal: black, faceted, and here and there still burning."""
    t = Tile(16, 24)
    for y in range(24):
        for x in range(16):
            t.set(x, y, base[rng.randrange(len(base))])
    for _ in range(9):
        cx, cy, r = rng.randrange(16), rng.randrange(24), rng.randrange(2, 5)
        shade = rng.choice(darks + base + base)
        for y in range(cy - r, cy + r):
            for x in range(cx - r + abs(y - cy), cx + r - abs(y - cy)):
                t.set(x, y, shade)
        for i in range(r):
            t.set(cx - r + i + 1, cy - i - 1, rng.choice(glints))
    if vein:
        x = rng.randrange(16)
        for y in range(4, 24):
            if rng.random() < 0.7:
                t.light(x, y, rng.choice(vein))
            x = max(0, min(15, x + rng.choice([-1, 0, 1])))
    return t


def block_wall(rng, base, gap, hi, lo, rows=3, moss=None, rune=None):
    """Stone blocks in courses."""
    t = Tile(16, 24)
    for y in range(24):
        for x in range(16):
            t.set(x, y, base[rng.randrange(len(base))])
    course = 24 // rows
    for r in range(rows):
        y0 = r * course
        for x in range(16):
            t.set(x, y0 + course - 1, gap)
            t.set(x, y0, hi)
            t.set(x, y0 + course - 2, lo)
        offset = (r * 5 + rng.randrange(3)) % 8
        for x in range(offset, 16, 8):
            for y in range(y0, y0 + course):
                t.set(x, y, gap)
            for y in range(y0, y0 + course - 1):
                t.set(min(15, x + 1), y, hi)
    if moss:
        for x in range(16):
            n = rng.randrange(0, 7)
            for y in range(n):
                t.set(x, y, rng.choice(moss))
        for _ in range(10):
            t.set(rng.randrange(16), rng.randrange(8, 24), rng.choice(moss))
    if rune and rng.random() < 0.5:
        x, y = rng.randrange(4, 11), rng.randrange(6, 15)
        for dx, dy in ((0, 0), (1, 0), (2, 0), (1, 1), (1, 2), (0, 3), (2, 3), (1, 3)):
            t.light(x + dx, y + dy, rune)
    return t


def rib_wall(rng, base, dark, rib, glow):
    """Ribs. The bottom of the mine is not entirely a mine any more."""
    t = Tile(16, 24)
    for y in range(24):
        for x in range(16):
            t.set(x, y, base[rng.randrange(len(base))])
    for x0 in (1, 6, 11):
        x0 += rng.randrange(0, 2)
        for y in range(24):
            sway = 1 if (y + x0) % 9 < 3 else 0
            t.set(x0 + sway, y, rib[0])
            t.set(x0 + sway + 1, y, rib[1])
            t.set(x0 + sway + 2, y, dark)
    for _ in range(3):
        x, y = rng.randrange(16), rng.randrange(24)
        t.light(x, y, glow)
        t.light(x, min(23, y + 1), glow)
    return t


def worn(t, rng, gap):
    for _ in range(5):
        t.set(rng.randrange(16), rng.randrange(t.h), gap)
    return t


def cracked(t, rng, gap, hi):
    """The hint that something could be done about this wall."""
    x, y = 3 + rng.randrange(3), 3
    while y < t.h - 2:
        t.set(x, y, gap)
        t.set(x + 1, y, hi)
        if rng.random() < 0.3:
            t.set(x - 2 if rng.random() < 0.5 else x + 2, y, gap)
        x = max(1, min(14, x + rng.choice([-1, 0, 1, 2])))
        y += 1
    x, y = 12, 6
    while y < t.h - 6:
        t.set(x, y, gap)
        x = max(1, min(14, x + rng.choice([-2, -1, 0, 1])))
        y += 1
    return t


def bracket(t, iron, hi):
    """A bracket for a wall lamp (the lamp itself is a sprite, so it can be shot out)."""
    t.fill(7, 11, 9, 13, iron)
    t.set(7, 11, hi)
    t.fill(6, 13, 10, 14, iron)
    return t


# ----------------------------------------------------------------- roofs --

def roof_tiles(rng, make_base, edge, edge_hi):
    """A roof for each set of open sides: its edge shows which way the floor is."""
    out = []
    for bits in range(16):
        t = make_base(rng)
        if bits & 1:
            for x in range(16):
                t.set(x, 0, edge_hi)
                t.set(x, 1, edge)
        if bits & 4:
            for x in range(16):
                t.set(x, 15, edge_hi)
                t.set(x, 14, edge)
        if bits & 2:
            for y in range(16):
                t.set(15, y, edge_hi)
                t.set(14, y, edge)
        if bits & 8:
            for y in range(16):
                t.set(0, y, edge_hi)
                t.set(1, y, edge)
        out.append(t)
    return out


# -------------------------------------------------------------- overlays --

def rails(wood, iron, iron_hi):
    def blank():
        return Tile()

    def sleepers_h(t):
        for x in (1, 6, 11):
            t.fill(x, 2, x + 2, 14, wood)

    def sleepers_v(t):
        for y in (1, 6, 11):
            t.fill(2, y, 14, y + 2, wood)
    out = []
    t = blank()
    sleepers_h(t)
    t.fill(0, 4, 16, 5, iron)
    t.fill(0, 3, 16, 4, iron_hi)
    t.fill(0, 11, 16, 12, iron)
    t.fill(0, 10, 16, 11, iron_hi)
    out.append(t)
    t = blank()
    sleepers_v(t)
    t.fill(4, 0, 5, 16, iron)
    t.fill(3, 0, 4, 16, iron_hi)
    t.fill(11, 0, 12, 16, iron)
    t.fill(10, 0, 11, 16, iron_hi)
    out.append(t)
    # The bends: from one side round to another (n-e, e-s, s-w, w-n).
    for quarter in range(4):
        t = blank()
        for radius, col in ((4, iron), (5, iron_hi), (11, iron), (12, iron_hi)):
            for a in range(0, 90, 3):
                ang = np.radians(a)
                x = int(round(radius * np.cos(ang)))
                y = int(round(radius * np.sin(ang)))
                # Drawn for the corner at the top right, then turned.
                px, py = 15 - x, y
                for _ in range(quarter):
                    px, py = 15 - py, px
                t.set(px, py, col)
        out.append(t)
    return out


def scatter(rng, cols, n=7):
    t = Tile()
    for _ in range(n):
        x, y = rng.randrange(16), rng.randrange(16)
        c = rng.choice(cols)
        t.set(x, y, c)
        if rng.random() < 0.4:
            t.set(x + 1, y, c)
    return t


def under_wall():
    """The dark pooled at the foot of a wall, dithered out."""
    t = Tile()
    dark = (0, 0, 0, 255)
    for y in range(5):
        for x in range(16):
            if y < 2 or (y == 2 and (x + y) % 2 == 0) or (y == 3 and (x * 2 + y) % 4 == 0) or (y == 4 and (x + 2) % 8 == 0):
                t.set(x, y, dark)
    return t


def rubble(rng, cols, dark):
    t = Tile()
    for _ in range(7):
        x, y, r = rng.randrange(1, 14), rng.randrange(1, 14), rng.randrange(1, 3)
        c = rng.choice(cols)
        t.fill(x, y, x + r + 1, y + r, c)
        t.fill(x, y + r, x + r + 1, y + r + 1, dark)
    return t


def crack(rng, col):
    t = Tile()
    x, y = rng.randrange(3, 13), rng.randrange(3, 13)
    for _ in range(rng.randrange(7, 14)):
        t.set(x, y, col)
        x += rng.choice([-1, 0, 1, 1])
        y += rng.choice([-1, 0, 1])
    return t


def stain(rng, col):
    t = Tile()
    cx, cy = rng.randrange(5, 11), rng.randrange(5, 11)
    for y in range(16):
        for x in range(16):
            d = (x - cx) ** 2 + (y - cy) ** 2
            if d < 16 and rng.random() < 1.0 - d / 16.0:
                t.set(x, y, col)
    return t


# ------------------------------------------------------------- the depths --

def timberworks(rng):
    orig_floor = Image.open(os.path.join(ORIG, "floor.png")).convert("RGBA")
    orig_wall = Image.open(os.path.join(ORIG, "wall.png")).convert("RGBA")
    orig_roof = read_ase(os.path.join(ORIG, "ase", "wall_roof.ase")).convert("RGBA")
    dirt = [hexc("3d2a26"), hexc("452f2a"), hexc("37251f")]
    darks = [hexc("2e1f1a"), hexc("241713")]
    lights = [hexc("54403a"), hexc("5e4940")]
    floors = []
    for i in range(16):
        if i == 0:
            t = Tile()
            t.px.paste(orig_floor, (0, 0))
        else:
            t = speckle_floor(rng, dirt, darks, lights, dashes=rng.randrange(1, 5) if i < 8 else rng.randrange(0, 2))
        floors.append(t)
    fronts = []
    for i in range(8):
        t = plank_wall(orig_wall)
        if 4 <= i < 6:
            worn(t, rng, hexc("241510"))
        elif i == 6:
            cracked(t, rng, hexc("120a07"), hexc("7a5240"))
        elif i == 7:
            bracket(t, hexc("1e1e22"), hexc("6c6c74"))
        fronts.append(t)

    def roof_base(r):
        t = Tile()
        t.px.paste(orig_roof, (0, 0))
        return t
    roofs = roof_tiles(rng, roof_base, hexc("3a2a22"), hexc("5e4632"))
    return floors, roofs, fronts, rails(hexc("3a2518"), hexc("34343a"), hexc("5c5c64")), [
        scatter(rng, [hexc("54403a"), hexc("2e1f1a")]), scatter(rng, [hexc("6a5a3e"), hexc("4c3c2a")], 5),
        under_wall(), scatter(rng, [hexc("74665a"), hexc("2e1f1a")], 9), scatter(rng, [hexc("5a3a2c"), hexc("7a5240")], 6),
        rubble(rng, [hexc("5a3a2c"), hexc("74665a"), hexc("3d2a26")], hexc("1a100c")),
        crack(rng, hexc("1e130f")), crack(rng, hexc("1e130f")), stain(rng, hexc("2e1f1a")), stain(rng, hexc("33241a")),
    ]


def coal_seam(rng):
    ash = [hexc("26252c"), hexc("2c2a31"), hexc("211f26")]
    floors = []
    for i in range(16):
        t = speckle_floor(rng, ash, [hexc("1a181e"), hexc("121116")], [hexc("3a3840"), hexc("44414a")],
            dashes=rng.randrange(1, 5) if i < 8 else 1, dash_col=hexc("121116"))
        if i < 8 and rng.random() < 0.6:
            t.light(rng.randrange(16), rng.randrange(16), hexc("ff7a24"))
        floors.append(t)
    fronts = []
    base, darks, glints = [hexc("1c1b22"), hexc("24232b")], [hexc("121117"), hexc("0c0b10")], [hexc("4f4e5e"), hexc("6a6880")]
    embers = [hexc("ff7a24"), hexc("ffb347"), hexc("d9481c")]
    for i in range(8):
        t = facet_wall(rng, base, darks, glints, embers if i in (2, 5) else None)
        if i == 6:
            cracked(t, rng, hexc("08070a"), hexc("ff7a24"))
        elif i == 7:
            bracket(t, hexc("0e0e12"), hexc("6c6c74"))
        fronts.append(t)

    def roof_base(r):
        t = Tile()
        t.fill(0, 0, 16, 16, hexc("0f0e13"))
        for _ in range(9):
            t.set(r.randrange(16), r.randrange(16), r.choice([hexc("1a1920"), hexc("08070a")]))
        return t
    roofs = roof_tiles(rng, roof_base, hexc("24232b"), hexc("4f4e5e"))
    return floors, roofs, fronts, rails(hexc("221c18"), hexc("2a2a32"), hexc("4e4e58")), [
        scatter(rng, [hexc("3a3840"), hexc("121116")]), scatter(rng, [hexc("4a2a1a"), hexc("6a3a1a")], 4),
        under_wall(), scatter(rng, [hexc("0c0b10"), hexc("44414a")], 9), scatter(rng, [hexc("121116"), hexc("1c1b22")], 8),
        rubble(rng, [hexc("24232b"), hexc("1c1b22"), hexc("3a3840")], hexc("08070a")),
        crack(rng, hexc("121116")), crack(rng, hexc("4a2a1a")), stain(rng, hexc("1a181e")), stain(rng, hexc("121116")),
    ]


def drowned_gallery(rng):
    deep = [hexc("10292e"), hexc("133137"), hexc("0e2428")]
    floors = []
    for i in range(16):
        floors.append(water_floor(rng, deep, hexc("0a1a1e"), hexc("2a5a5e")))
    fronts = []
    stone = [hexc("37504e"), hexc("3e5a56"), hexc("324a48")]
    moss = [hexc("3f7a4a"), hexc("2f6a3e"), hexc("558f58")]
    for i in range(8):
        t = block_wall(rng, stone, hexc("182a2a"), hexc("56766e"), hexc("2a3e3c"), moss=moss if i % 2 == 0 else None)
        if i in (3, 5):
            # Fungus that feeds on the dark.
            for _ in range(3):
                x, y = rng.randrange(1, 15), rng.randrange(8, 23)
                t.light(x, y, hexc("7ff0d0"))
                t.light(x + 1, y, hexc("3fc0b0"))
        if i == 6:
            cracked(t, rng, hexc("0c1818"), hexc("56766e"))
        elif i == 7:
            bracket(t, hexc("14201f"), hexc("7c8c88"))
        fronts.append(t)

    def roof_base(r):
        t = Tile()
        t.fill(0, 0, 16, 16, hexc("0e1a1c"))
        for _ in range(10):
            t.set(r.randrange(16), r.randrange(16), r.choice([hexc("182a2a"), hexc("0a1214"), hexc("1f4a34")]))
        return t
    roofs = roof_tiles(rng, roof_base, hexc("24403e"), hexc("56766e"))
    return floors, roofs, fronts, rails(hexc("172220"), hexc("283638"), hexc("4a6260")), [
        scatter(rng, [hexc("2a5a5e"), hexc("0a1a1e")], 5), scatter(rng, [hexc("3f7a4a"), hexc("2a5a5e")], 4),
        under_wall(), scatter(rng, [hexc("7ff0d0")], 2), scatter(rng, [hexc("0a1a1e"), hexc("1a3c3e")], 7),
        rubble(rng, [hexc("37504e"), hexc("3e5a56"), hexc("56766e")], hexc("0c1818")),
        crack(rng, hexc("0a1a1e")), crack(rng, hexc("0a1a1e")), stain(rng, hexc("0a1a1e")), stain(rng, hexc("1a3c3e")),
    ]


def old_workings(rng):
    pale = [hexc("3a3346"), hexc("41394e"), hexc("352f40")]
    floors = []
    for i in range(16):
        floors.append(flag_floor(rng, pale, hexc("1d1826"), hexc("544a64")))
    fronts = []
    stone = [hexc("5a506c"), hexc("625876"), hexc("524862")]
    for i in range(8):
        t = block_wall(rng, stone, hexc("231d2e"), hexc("7a6f90"), hexc("40384e"), rows=2, rune=hexc("c78cff") if i in (1, 4) else None)
        if i == 6:
            cracked(t, rng, hexc("14101c"), hexc("7a6f90"))
        elif i == 7:
            bracket(t, hexc("1c1826"), hexc("8a8a98"))
        fronts.append(t)

    def roof_base(r):
        t = Tile()
        t.fill(0, 0, 16, 16, hexc("15111c"))
        for _ in range(8):
            t.set(r.randrange(16), r.randrange(16), r.choice([hexc("1d1826"), hexc("0e0b14")]))
        return t
    roofs = roof_tiles(rng, roof_base, hexc("3a3346"), hexc("7a6f90"))
    return floors, roofs, fronts, rails(hexc("201a26"), hexc("34303e"), hexc("5e5a6a")), [
        scatter(rng, [hexc("544a64"), hexc("1d1826")], 5), scatter(rng, [hexc("c7bfa8"), hexc("8a8270")], 3),
        under_wall(), scatter(rng, [hexc("c78cff")], 1), scatter(rng, [hexc("2a2436"), hexc("544a64")], 7),
        rubble(rng, [hexc("5a506c"), hexc("625876"), hexc("7a6f90")], hexc("14101c")),
        crack(rng, hexc("1d1826")), crack(rng, hexc("1d1826")), stain(rng, hexc("2a2436")), stain(rng, hexc("1d1826")),
    ]


def the_heart(rng):
    flesh = [hexc("1e2a1c"), hexc("243220"), hexc("1a2418")]
    floors = []
    for i in range(16):
        floors.append(flesh_floor(rng, flesh, hexc("3a5228"), hexc("b6ff5a")))
    fronts = []
    base = [hexc("2c3a24"), hexc("34442a"), hexc("263220")]
    for i in range(8):
        t = rib_wall(rng, base, hexc("10180e"), (hexc("7a8a58"), hexc("566a3e")), hexc("b6ff5a"))
        if i == 6:
            cracked(t, rng, hexc("0a0f08"), hexc("b6ff5a"))
        elif i == 7:
            bracket(t, hexc("10180e"), hexc("7a8a58"))
        fronts.append(t)

    def roof_base(r):
        t = Tile()
        t.fill(0, 0, 16, 16, hexc("0c120a"))
        for _ in range(9):
            t.set(r.randrange(16), r.randrange(16), r.choice([hexc("141e10"), hexc("080c06")]))
        return t
    roofs = roof_tiles(rng, roof_base, hexc("2c3a24"), hexc("7a8a58"))
    return floors, roofs, fronts, rails(hexc("182014"), hexc("2c3622"), hexc("54603c")), [
        scatter(rng, [hexc("3a5228"), hexc("10180e")], 5), scatter(rng, [hexc("b6ff5a")], 2),
        under_wall(), scatter(rng, [hexc("566a3e"), hexc("10180e")], 7), scatter(rng, [hexc("10180e"), hexc("1a2418")], 8),
        rubble(rng, [hexc("34442a"), hexc("7a8a58"), hexc("263220")], hexc("0a0f08")),
        crack(rng, hexc("10180e")), crack(rng, hexc("3a5228")), stain(rng, hexc("10180e")), stain(rng, hexc("3a5228")),
    ]


DEPTHS = {
    "timberworks": timberworks,
    "coal_seam": coal_seam,
    "drowned_gallery": drowned_gallery,
    "old_workings": old_workings,
    "the_heart": the_heart,
}


def height_to_normal(height, alpha, strength=2.2):
    """A normal map from what is light and what is dark in the art: dark gaps, raised boards."""
    h = np.asarray(height, dtype=np.float32) / 255.0
    dx = np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)
    dy = np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / length, ny / length, nz / length
    # OpenGL-style, as Godot's NORMAL_MAP wants: green is up the texture.
    r = (nx * 0.5 + 0.5) * 255
    g = (-ny * 0.5 + 0.5) * 255
    b = (nz * 0.5 + 0.5) * 255
    out = np.stack([r, g, b, np.full_like(r, 255)], axis=-1).astype(np.uint8)
    out[alpha == 0] = (128, 128, 255, 255)
    return Image.fromarray(out, "RGBA")


def build(name, maker):
    rng = random.Random(name)
    floors, roofs, fronts, rail_tiles, overlays = maker(rng)
    atlas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 255))

    def put(t, x, y):
        atlas.paste(t.px, (x, y))
        glow.paste(t.glow, (x, y), t.glow)
    for i, t in enumerate(floors):
        put(t, (i % 8) * 16, (i // 8) * 16)
    for i, t in enumerate(roofs):
        put(t, (i % 8) * 16, 32 + (i // 8) * 16)
    for i, t in enumerate(fronts):
        put(t, i * 16, 64)
    for i, t in enumerate(rail_tiles):
        put(t, i * 16, 88)
    for i, t in enumerate(overlays[:2]):
        put(t, (6 + i) * 16, 88)
    for i, t in enumerate(overlays[2:]):
        put(t, i * 16, 104)
    atlas.save(os.path.join(OUT, name + ".png"))
    glow.convert("RGB").save(os.path.join(OUT, name + "_e.png"))
    rgb = np.asarray(atlas.convert("RGB"), dtype=np.float32)
    alpha = np.asarray(atlas)[:, :, 3]
    lum = rgb[:, :, 0] * 0.3 + rgb[:, :, 1] * 0.59 + rgb[:, :, 2] * 0.11
    height_to_normal(lum, alpha).convert("RGB").save(os.path.join(OUT, name + "_n.png"))
    print(name)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, maker in DEPTHS.items():
        build(name, maker)


if __name__ == "__main__":
    main()
