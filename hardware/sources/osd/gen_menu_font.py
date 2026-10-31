# 8x16 菜单字模。ASCII 32～90，每字 16 行，每行 8 bit，高位在左。
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
MEM = os.path.join(ROOT, "menu_font_8x16.mem")
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\consola.ttf",
    r"C:\Windows\Fonts\Consolas.ttf",
    r"C:\Windows\Fonts\simhei.ttf",
]


def load_font():
    for path in FONT_CANDIDATES:
        if os.path.isfile(path):
            return ImageFont.truetype(path, 12)
    return ImageFont.load_default()


def render(ch, font):
    img = Image.new("L", (8, 16), 0)
    draw = ImageDraw.Draw(img)
    bbox = draw.textbbox((0, 0), ch, font=font)
    x = (8 - (bbox[2] - bbox[0])) // 2 - bbox[0]
    y = (16 - (bbox[3] - bbox[1])) // 2 - bbox[1]
    draw.text((x, y), ch, font=font, fill=255)
    rows = []
    for yy in range(16):
        bits = 0
        for xx in range(8):
            if img.getpixel((xx, yy)) >= 96:
                bits |= 1 << (7 - xx)
        rows.append(bits)
    return rows


def main():
    font = load_font()
    lines = []
    for code in range(32, 91):
        for bits in render(chr(code), font):
            lines.append(f"{bits:02X}")
    with open(MEM, "w", encoding="ascii", newline="\n") as mem:
        mem.write("\n".join(lines) + "\n")
    print(f"wrote {len(lines)} rows")


if __name__ == "__main__":
    main()
