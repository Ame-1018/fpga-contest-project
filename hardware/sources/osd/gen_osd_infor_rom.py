# 生成 osd_infor_rom 的初始化文件。
# 深度仍是 1024，每个地址 32 bit。左右各放一个 16x32 字，bit31 和 bit15 是左像素。
# 偶数编号在高 16 位。汉字、数字都按这个格式放，菜单一格一个字。
import os
from PIL import Image, ImageDraw, ImageFont

CHARS = list(
    "返回开关转场模式速度色彩亮对比温调风格阈值原图灰二反标志横向纵"
    "字幕宽颜音频波形默认虹缩放高按键串口"
)
DIGITS = [str(d) for d in range(10)]
assert len(CHARS) == 49
assert len(set(CHARS)) == 49

FONT_PATH = r"C:\Windows\Fonts\simhei.ttf"
HAN_SIZE = 15
DIG_SIZE = 16
DEPTH = 1024
CELL_W = 16
CELL_H = 32

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MIF_PATH = os.path.join(ROOT, "TD_PRJ", "al_ip", "osd_infor_rom", "osd_infor_rom.mif")
MEM_PATH = os.path.join(os.path.dirname(__file__), "osd_infor_init.mem")
DATH_PATH = os.path.join(ROOT, "TD_PRJ", "al_ip", "osd_infor_rom", "osd_infor_rom.mif.dath")
PREVIEW_PATH = os.path.join(os.path.dirname(__file__), "osd_infor_preview.png")


def render(text, size):
    img = Image.new("L", (CELL_W, CELL_H), 0)
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_PATH, size)
    bbox = draw.textbbox((0, 0), text, font=font)
    x = (CELL_W - (bbox[2] - bbox[0])) // 2 - bbox[0]
    y = (CELL_H - (bbox[3] - bbox[1])) // 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=255)
    rows = []
    for yy in range(CELL_H):
        word = 0
        for xx in range(CELL_W):
            if img.getpixel((xx, yy)) >= 96:
                word |= 1 << (CELL_W - 1 - xx)
        rows.append(word)
    return rows


def place(words, gid, rows):
    slot = gid // 2
    shift = 16 if (gid % 2) == 0 else 0
    base = slot * CELL_H
    for r, bits in enumerate(rows):
        words[base + r] |= (bits & 0xFFFF) << shift


def main():
    words = [0] * DEPTH
    for i, ch in enumerate(CHARS):
        place(words, i, render(ch, HAN_SIZE))
    for d, ch in enumerate(DIGITS):
        place(words, len(CHARS) + d, render(ch, DIG_SIZE))
    for i, ch in enumerate(["确", "认"]):
        place(words, len(CHARS) + len(DIGITS) + i, render(ch, HAN_SIZE))

    with open(MEM_PATH, "w", encoding="ascii", newline="\n") as mem:
        for w in words:
            mem.write(f"{w:08X}\n")

    with open(MIF_PATH, "w", encoding="ascii", newline="\n") as mif:
        mif.write("WIDTH = 32;\n")
        mif.write("DEPTH = 1024;\n")
        mif.write("ADDRESS_RADIX = HEX;\n")
        mif.write("DATA_RADIX = HEX;\n")
        mif.write("CONTENT BEGIN\n")
        for addr, w in enumerate(words):
            mif.write(f"{addr:X} : {w:08X};\n")
        mif.write("END;\n")

    with open(DATH_PATH, "w", encoding="ascii", newline="\n") as dath:
        for w in words:
            dath.write(f"{w:08x}\n")

    nshow = len(CHARS) + len(DIGITS) + 2
    cols = 16
    rows_n = (nshow + cols - 1) // cols
    sheet = Image.new("RGB", (CELL_W * cols, CELL_H * rows_n), (20, 24, 32))
    px = sheet.load()
    for i in range(nshow):
        ox = (i % cols) * CELL_W
        oy = (i // cols) * CELL_H
        base = (i // 2) * CELL_H
        shift = 16 if (i % 2) == 0 else 0
        for r in range(CELL_H):
            bits = (words[base + r] >> shift) & 0xFFFF
            for c in range(CELL_W):
                if (bits >> (CELL_W - 1 - c)) & 1:
                    px[ox + c, oy + r] = (255, 255, 255)
    sheet.save(PREVIEW_PATH)
    print("chars", "".join(CHARS))
    print("count", len(CHARS), "digits_from", len(CHARS))
    print("mif", MIF_PATH)


if __name__ == "__main__":
    main()
