#!/usr/bin/env python3
"""Draws the game's two pixel fonts as BMFonts (a .fnt and its .png), which
Godot imports as they are and draws without any blur:

    assets/fonts/body.fnt      a hand-drawn proportional 5x7, for everything small
    assets/fonts/heading.fnt   Bungee, rasterised without antialiasing, for headings

    python3 tools/make_font.py [--assets ../Assets]
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "assets", "fonts")

# Each glyph: rows from the top, the seven of the capital height, then the
# two below the baseline if it has any. A glyph is as wide as its rows.
BODY = {
    " ": "...",
    "A": ".##./#..#/#..#/####/#..#/#..#/#..#",
    "B": "###./#..#/#..#/###./#..#/#..#/###.",
    "C": ".###/#.../#.../#.../#.../#.../.###",
    "D": "###./#..#/#..#/#..#/#..#/#..#/###.",
    "E": "####/#.../#.../###./#.../#.../####",
    "F": "####/#.../#.../###./#.../#.../#...",
    "G": ".###/#.../#.../#.##/#..#/#..#/.###",
    "H": "#..#/#..#/#..#/####/#..#/#..#/#..#",
    "I": "###/.#./.#./.#./.#./.#./###",
    "J": "..##/...#/...#/...#/...#/#..#/.##.",
    "K": "#..#/#..#/#.#./##../#.#./#..#/#..#",
    "L": "#.../#.../#.../#.../#.../#.../####",
    "M": "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",
    "N": "#..#/##.#/##.#/#.##/#.##/#..#/#..#",
    "O": ".##./#..#/#..#/#..#/#..#/#..#/.##.",
    "P": "###./#..#/#..#/###./#.../#.../#...",
    "Q": ".##./#..#/#..#/#..#/#..#/#.#./.#.#",
    "R": "###./#..#/#..#/###./#.#./#..#/#..#",
    "S": ".###/#.../#.../.##./...#/...#/###.",
    "T": "#####/..#../..#../..#../..#../..#../..#..",
    "U": "#..#/#..#/#..#/#..#/#..#/#..#/.##.",
    "V": "#...#/#...#/#...#/#...#/.#.#./.#.#./..#..",
    "W": "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",
    "X": "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
    "Y": "#...#/#...#/.#.#./..#../..#../..#../..#..",
    "Z": "####/...#/..#./.#../#.../#.../####",
    "a": "..../..../.###/#..#/#..#/#..#/.###",
    "b": "#.../#.../###./#..#/#..#/#..#/###.",
    "c": "..../..../.###/#.../#.../#.../.###",
    "d": "...#/...#/.###/#..#/#..#/#..#/.###",
    "e": "..../..../.##./#..#/####/#.../.###",
    "f": "..#/.#./###/.#./.#./.#./.#.",
    "g": "..../..../.###/#..#/#..#/#..#/.###/...#/.##.",
    "h": "#.../#.../###./#..#/#..#/#..#/#..#",
    "i": "#/./#/#/#/#/#",
    "j": "..#/.../..#/..#/..#/..#/..#/..#/##.",
    "k": "#.../#.../#..#/#.#./##../#.#./#..#",
    "l": "##/.#/.#/.#/.#/.#/.#",
    "m": "...../...../####./#.#.#/#.#.#/#.#.#/#.#.#",
    "n": "..../..../###./#..#/#..#/#..#/#..#",
    "o": "..../..../.##./#..#/#..#/#..#/.##.",
    "p": "..../..../###./#..#/#..#/#..#/###./#.../#...",
    "q": "..../..../.###/#..#/#..#/#..#/.###/...#/...#",
    "r": "..../..../#.##/##../#.../#.../#...",
    "s": "..../..../.###/#.../.##./...#/###.",
    "t": ".#./.#./###/.#./.#./.#./..#",
    "u": "..../..../#..#/#..#/#..#/#..#/.###",
    "v": "..../..../#..#/#..#/#..#/.#.#/..#.",
    "w": "...../...../#...#/#.#.#/#.#.#/#.#.#/.#.#.",
    "x": "..../..../#..#/#..#/.##./#..#/#..#",
    "y": "..../..../#..#/#..#/#..#/#..#/.###/...#/.##.",
    "z": "..../..../####/...#/.##./#.../####",
    "0": ".##./#..#/#.##/##.#/##.#/#..#/.##.",
    "1": ".#./##./.#./.#./.#./.#./###",
    "2": ".##./#..#/...#/..#./.#../#.../####",
    "3": "###./...#/...#/.##./...#/...#/###.",
    "4": "#..#/#..#/#..#/####/...#/...#/...#",
    "5": "####/#.../#.../###./...#/...#/###.",
    "6": ".##./#.../#.../###./#..#/#..#/.##.",
    "7": "####/...#/...#/..#./..#./.#../.#..",
    "8": ".##./#..#/#..#/.##./#..#/#..#/.##.",
    "9": ".##./#..#/#..#/.###/...#/...#/.##.",
    ".": "././././././/#".replace("//", "/./") if False else "././././././#",
    ",": "././././././#/#",
    ":": "./././#/./#/.",
    ";": "../../../.#/../.#/.#/#.",
    "!": "#/#/#/#/#/./#",
    "?": ".##./#..#/...#/..#./.#../..../.#..",
    "'": "#/#/./././././.".replace("/./././././.", "/./././././."),
    '"': "#.#/#.#/.../.../.../.../...",
    "-": "..../..../..../####/..../..../....",
    "+": "..../..../.#../###./.#../..../....",
    "=": "..../..../####/..../####/..../....",
    "/": "...#/...#/..#./..#./.#../.#../#...",
    "(": ".#/#./#./#./#./#./.#",
    ")": "#./.#/.#/.#/.#/.#/#.",
    "[": "##/#./#./#./#./#./##",
    "]": "##/.#/.#/.#/.#/.#/##",
    "%": "#..#/#..#/...#/..#./.#../#..#/#..#",
    "*": "..../#.#./.#../#.#./..../..../....",
    "#": ".#.#./#####/.#.#./.#.#./.#.#./#####/.#.#.",
    "&": ".##./#..#/#.#./.#../#.#./#..#/.#.#",
    "<": "..#/.#./#../.#./..#/.../...",
    ">": "#../.#./..#/.#./#../.../...",
    "_": "..../..../..../..../..../..../####",
    "x": "..../..../#..#/#..#/.##./#..#/#..#",
    "×": "..../..../#.#./.#../#.#./..../....",
}

ROWS = 9
ASCENT = 7
LINE_HEIGHT = 10


def write_fnt(name, glyphs, cell_h, base, line_height, size):
    """Lays the glyphs out in rows in a PNG and writes the BMFont text beside it."""
    columns = 512
    image = Image.new("RGBA", (columns, 8), (0, 0, 0, 0))
    x = y = 1
    lines = []
    rows_used = cell_h + 2
    placed = {}
    for ch, (bitmap, advance) in glyphs.items():
        w, h = bitmap.size
        if x + w + 1 >= columns:
            x = 1
            y += rows_used
        placed[ch] = (x, y, w, h, advance)
        x += w + 2
    image = Image.new("RGBA", (columns, y + rows_used), (0, 0, 0, 0))
    for ch, (bitmap, advance) in glyphs.items():
        px, py, w, h, _ = placed[ch]
        image.paste(bitmap, (px, py))
    image.save(os.path.join(OUT, name + ".png"))
    lines.append(f'info face="{name}" size={size} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0')
    lines.append(f'common lineHeight={line_height} base={base} scaleW={image.width} scaleH={image.height} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4')
    lines.append(f'page id=0 file="{name}.png"')
    lines.append(f"chars count={len(placed)}")
    for ch, (px, py, w, h, advance) in placed.items():
        lines.append(f"char id={ord(ch)} x={px} y={py} width={w} height={h} xoffset=0 yoffset=0 xadvance={advance} page=0 chnl=15")
    with open(os.path.join(OUT, name + ".fnt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{name}: {len(placed)} glyphs, {image.width}x{image.height}")


def body_font():
    glyphs = {}
    for ch, spec in BODY.items():
        rows = spec.split("/")
        width = max(len(r) for r in rows)
        bitmap = Image.new("RGBA", (width, ROWS), (0, 0, 0, 0))
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                if c == "#":
                    bitmap.putpixel((x, y), (255, 255, 255, 255))
        glyphs[ch] = (bitmap, width + 1)
    write_fnt("body", glyphs, ROWS, ASCENT, LINE_HEIGHT, 8)


def heading_font(assets):
    path = os.path.join(assets, "Fonts", "Bungee", "Bungee-Regular.ttf")
    size = 14
    font = ImageFont.truetype(path, size)
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,:;!?'-+/()&%×"
    ascent, descent = font.getmetrics()
    height = ascent + descent + 1
    glyphs = {}
    for ch in chars:
        advance = max(int(round(font.getlength(ch))), 2) + 1
        bitmap = Image.new("L", (advance + 2, height), 0)
        draw = ImageDraw.Draw(bitmap)
        draw.fontmode = "1"
        draw.text((0, 0), ch, font=font, fill=255)
        rgba = Image.new("RGBA", bitmap.size, (255, 255, 255, 0))
        rgba.putalpha(bitmap.point(lambda v: 255 if v > 127 else 0))
        glyphs[ch] = (rgba, advance)
    write_fnt("heading", glyphs, height, ascent, height, 14)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets", default=os.path.join(REPO, "..", "Assets"))
    args = parser.parse_args()
    assets = args.assets
    if not os.path.isdir(assets):
        # In a worktree, the assets are beside the main checkout.
        folder = REPO
        while folder != os.path.dirname(folder):
            folder = os.path.dirname(folder)
            if os.path.isdir(os.path.join(folder, "Assets")):
                assets = os.path.join(folder, "Assets")
                break
    os.makedirs(OUT, exist_ok=True)
    body_font()
    heading_font(assets)


if __name__ == "__main__":
    main()
