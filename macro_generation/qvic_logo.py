"""Generate the QvIC Labs silicon-art macro (met4) from macro_generation/qvic_logo.png.

Follows https://tinytapeout.com/guides/creating-silicon-art/ (SKY shuttles).
Run from the repository root: python macro_generation/qvic_logo.py
"""

from pathlib import Path

import gdstk
from PIL import Image

CELL_NAME = "qvic_logo"
ART_LAYER, ART_DATATYPE = 71, 20  # met4.drawing
BOUNDARY_LAYER, BOUNDARY_DATATYPE = 235, 4  # prBoundary

PIXEL = 0.5  # um; met4 minimum width and spacing are 0.3 um, minimum area 0.24 um^2
COLUMNS = 60  # 60 x 0.5 = 30 um, fits between two met4 power-stripe pairs
PADDING = 1.0  # um of empty space around the art inside the macro
LIT = 90  # a channel above this is part of a letter (background stays below ~30)
SPLIT_ROW = 175  # artwork row between QVIC and LABS

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "macros"


def lit_mask(image: Image.Image) -> Image.Image:
    """Letters are bright or saturated (blue, gold, grey) on a near-black background."""
    return image.convert("RGB").point(lambda v: 255 if v > LIT else 0).convert("L").point(lambda v: 255 if v else 0)


def bitmap(path: Path) -> list[list[bool]]:
    """QVIC from the artwork, downsampled; LABS redrawn with a pixel font so it stays legible."""
    image = Image.open(path)
    mask = lit_mask(image)
    left, top, right, bottom = mask.getbbox()
    split = SPLIT_ROW
    letters = mask.crop((left, top, right, split))
    letters = letters.crop(letters.getbbox())
    rows = round(COLUMNS * letters.height / letters.width)
    small = letters.resize((COLUMNS, rows), Image.BOX)
    grid = [[small.getpixel((x, y)) > 110 for x in range(COLUMNS)] for y in range(rows)]

    # Centre LABS under the span it occupies in the artwork.
    labs = mask.crop((left, split, right, bottom)).getbbox()
    scale = COLUMNS / (right - left)
    centre = round((labs[0] + labs[2]) / 2 * scale)
    text = render("LABS", gap=2)
    x0 = max(0, min(COLUMNS - len(text[0]), centre - len(text[0]) // 2))
    grid += [[False] * COLUMNS for _ in range(2)]
    for line in text:
        grid.append([x0 <= x < x0 + len(line) and line[x - x0] for x in range(COLUMNS)])
    return remove_diagonal_contacts(grid)


FONT = {
    "L": ["#..", "#..", "#..", "#..", "###"],
    "A": ["###", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "###", "#.#", "###"],
    "S": ["###", "#..", "###", "..#", "###"],
}


def render(text: str, gap: int) -> list[list[bool]]:
    lines = [[] for _ in range(5)]
    for i, char in enumerate(text):
        for row, pattern in enumerate(FONT[char]):
            if i:
                lines[row] += [False] * gap
            lines[row] += [c == "#" for c in pattern]
    return lines


def remove_diagonal_contacts(grid: list[list[bool]]) -> list[list[bool]]:
    """Fill one cell wherever two lit pixels touch only at a corner (a DRC error)."""
    for y in range(len(grid) - 1):
        for x in range(len(grid[0]) - 1):
            a, b = grid[y][x], grid[y][x + 1]
            c, d = grid[y + 1][x], grid[y + 1][x + 1]
            if (a and d and not b and not c) or (b and c and not a and not d):
                grid[y][x] = grid[y][x + 1] = True
    return grid


def write_lef(path: Path, width: float, height: float) -> None:
    # The met4 obstruction keeps the router off the art.
    path.write_text(
        f"""VERSION 5.8 ;
NAMESCASESENSITIVE ON ;
DIVIDERCHAR "/" ;
BUSBITCHARS "[]" ;
UNITS
   DATABASE MICRONS 1000 ;
END UNITS

MACRO {CELL_NAME}
   CLASS BLOCK ;
   FOREIGN {CELL_NAME} 0 0 ;
   SIZE {width:.3f} BY {height:.3f} ;
   SYMMETRY X Y ;
   OBS
      LAYER met4 ;
         RECT 0.000 0.000 {width:.3f} {height:.3f} ;
   END
END {CELL_NAME}

END LIBRARY
""",
        encoding="ascii",
    )


def main() -> None:
    grid = bitmap(HERE / "qvic_logo.png")
    rows = len(grid)
    width = round(COLUMNS * PIXEL + 2 * PADDING, 2)
    height = round(rows * PIXEL + 2 * PADDING, 2)

    lib = gdstk.Library()
    cell = lib.new_cell(CELL_NAME)
    cell.add(gdstk.rectangle((0, 0), (width, height), layer=BOUNDARY_LAYER, datatype=BOUNDARY_DATATYPE))
    pixels = []
    for y, row in enumerate(grid):
        top = height - PADDING - y * PIXEL  # image rows go downwards
        x = 0
        while x < COLUMNS:
            if not row[x]:
                x += 1
                continue
            start = x
            while x < COLUMNS and row[x]:
                x += 1
            left = PADDING + start * PIXEL
            pixels.append(gdstk.rectangle((left, top - PIXEL), (PADDING + x * PIXEL, top)))
    for polygon in gdstk.boolean(pixels, [], "or", layer=ART_LAYER, datatype=ART_DATATYPE):
        cell.add(polygon)

    OUT.mkdir(exist_ok=True)
    lib.write_gds(OUT / f"{CELL_NAME}.gds")
    cell.write_svg(OUT / f"{CELL_NAME}.svg", background="#000000")
    write_lef(OUT / f"{CELL_NAME}.lef", width, height)
    print(f"{CELL_NAME}: {width} x {height} um, {COLUMNS} x {rows} pixels")
    for row in grid:
        print("".join("#" if lit else "." for lit in row))


if __name__ == "__main__":
    main()
