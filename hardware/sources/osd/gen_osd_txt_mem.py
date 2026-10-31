# 生成 OSD 字幕和 128x128 logo 的初始化文件。
# 字幕高 32、宽 2048，每个字占 32x32。32 行 x 64 个 32bit 字，共 2048 深。
# 字内 bit31 是最左边的像素。地址是 {行[4:0], 列字[5:0]}。
# logo 先把边缘 11 收成红或藏青，再按每字节 4 像素写入 4096x8。
# 两个 mif 分别放进对应 IP 目录，供 ERAM32K 初始化。

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OSD = Path(__file__).resolve().parent
IP = ROOT / "TD_PRJ" / "al_ip"
TEXT = "欢迎各位评委莅临指导，敬请检阅本队视频显示方案效果！"
CELL = 32
WIDTH = 2048
HEIGHT = 32
BG = (0xE6, 0xE6, 0xE6)
RED = (0xED, 0x1C, 0x24)
NAVY = (0x1C, 0x2D, 0x4E)


def render_text():
    font = ImageFont.truetype(r"C:\Windows\Fonts\simhei.ttf", 28)
    img = Image.new("L", (WIDTH, HEIGHT), 0)
    draw = ImageDraw.Draw(img)
    for i, ch in enumerate(TEXT):
        box = draw.textbbox((0, 0), ch, font=font)
        cw = box[2] - box[0]
        chh = box[3] - box[1]
        x = i * CELL + (CELL - cw) // 2 - box[0]
        y = (HEIGHT - chh) // 2 - box[1]
        draw.text((x, y), ch, font=font, fill=255)
    bits = [[1 if img.getpixel((x, y)) >= 128 else 0 for x in range(WIDTH)] for y in range(HEIGHT)]
    return bits


def pack_words(bits):
    words = []
    for y in range(HEIGHT):
        for col in range(WIDTH // 32):
            val = 0
            for b in range(32):
                if bits[y][col * 32 + b]:
                    val |= 1 << (31 - b)
            words.append(val)
    return words


def write_mif(path, words, width):
    digits = width // 4
    lines = [
        "WIDTH = %d;" % width,
        "DEPTH = %d;" % len(words),
        "ADDRESS_RADIX = HEX;",
        "DATA_RADIX = HEX;",
        "CONTENT BEGIN",
    ]
    for addr, word in enumerate(words):
        lines.append("%X : %0*X;" % (addr, digits, word))
    lines.append("END;")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")
    print("mif", path, "depth", len(words), "width", width)


def pix_code(line, px, side):
    if px < 0 or px >= side:
        return 0
    shift = (side - 1 - px) * 2
    return (line >> shift) & 3


def nearest_fg(rows, y, px, side):
    # 与 VPU_OSD.nearest_fg 相同：八邻域纯色投票，红票不少于藏青票时用红。
    votes_red = 0
    votes_navy = 0
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            yy = y + dy
            if yy < 0 or yy >= side:
                continue
            code = pix_code(rows[yy], px + dx, side)
            if code == 1:
                votes_red += 1
            elif code == 2:
                votes_navy += 1
    if votes_red and votes_red >= votes_navy:
        return 1
    if votes_navy:
        return 2
    return 1


def edge_hue(rows, side):
    codes = [[pix_code(rows[y], x, side) for x in range(side)] for y in range(side)]
    hue = [[codes[y][x] if codes[y][x] in (1, 2) else 0 for x in range(side)] for y in range(side)]
    for _ in range(3):
        nxt = [row[:] for row in hue]
        for y in range(side):
            for x in range(side):
                if codes[y][x] != 3 or hue[y][x] in (1, 2):
                    continue
                votes = {1: 0, 2: 0}
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy = y + dy
                        xx = x + dx
                        if 0 <= yy < side and 0 <= xx < side and hue[yy][xx] in (1, 2):
                            votes[hue[yy][xx]] += 1
                if votes[1] or votes[2]:
                    nxt[y][x] = 1 if votes[1] >= votes[2] else 2
        hue = nxt
    bad = 0
    for y in range(side):
        for x in range(side):
            if codes[y][x] == 3 and nearest_fg(rows, y, x, side) != hue[y][x]:
                bad += 1
    return bad


def parse_rom(path, width_bits):
    text = path.read_text(encoding="utf-8")
    token = "%d'h" % width_bits
    rows = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("7'd") or token not in line:
            continue
        addr = int(line.split(":", 1)[0].replace("7'd", "").strip())
        hexpart = line.split(token, 1)[1].split(";", 1)[0].replace("_", "")
        rows[addr] = int(hexpart, 16)
    side = width_bits // 2
    if len(rows) < side:
        raise SystemExit("ROM rows missing in %s: %d" % (path.name, len(rows)))
    return [rows.get(i, 0) for i in range(side)]


def resolve_codes(rows, side):
    # 边缘 11 在这里按八邻域投票收成 01 或 10。显示时不再混合底图。
    codes = []
    edge_n = 0
    for y in range(side):
        row = []
        for x in range(side):
            code = pix_code(rows[y], x, side)
            if code == 3:
                edge_n += 1
                code = nearest_fg(rows, y, x, side)
            row.append(code)
        codes.append(row)
    return codes, edge_n


def pack_logo(codes):
    # 从左到右、从上到下。每个字节 4 个像素，左边的像素在高位。
    lines = []
    side = len(codes)
    for y in range(side):
        if side % 4:
            raise SystemExit("side not multiple of 4")
        for col in range(side // 4):
            word = 0
            for k in range(4):
                word = (word << 2) | (codes[y][col * 4 + k] & 3)
            lines.append("%02X" % word)
    return lines


def write_logo_mem(lines, path, depth=4096):
    if len(lines) > depth:
        raise SystemExit("logo mem %d exceeds %d" % (len(lines), depth))
    body = lines + ["00"] * (depth - len(lines))
    path.write_text("\n".join(body) + "\n", encoding="ascii")
    print("logo mem", path.name, "used", len(lines), "depth", depth)


def write_gold(codes, path):
    raw = bytearray()
    for row in codes:
        for code in row:
            if code == 1:
                raw.extend(RED)
            elif code == 2:
                raw.extend(NAVY)
            else:
                raw.extend(BG)
    path.write_bytes(raw)
    print("gold", path.name, "bytes", len(raw))


def main():
    bits = render_text()
    ink = sum(sum(row) for row in bits)
    words = pack_words(bits)
    if len(words) != 2048:
        raise SystemExit("text depth %d" % len(words))
    if len(TEXT) > WIDTH // CELL:
        raise SystemExit("text longer than %d cells" % (WIDTH // CELL))
    mem_path = OSD / "osd_txt_init.mem"
    mem_path.write_text("\n".join("%08X" % word for word in words) + "\n", encoding="ascii")
    write_mif(IP / "osd_txt_ram" / "osd_txt_ram.mif", words, 32)
    preview = Image.new("RGB", (WIDTH, HEIGHT), (0x14, 0x20, 0x33))
    for y in range(HEIGHT):
        for x in range(WIDTH):
            if bits[y][x]:
                preview.putpixel((x, y), (255, 255, 255))
    preview.resize((WIDTH, HEIGHT * 4), Image.Resampling.NEAREST).save(OSD / "osd_txt_init_preview.png")
    print("text", TEXT)
    print("chars", len(TEXT), "ink", ink, "mem", mem_path.name)
    raw96 = parse_rom(OSD / "OSD_LOGO_ROM_96x96.v", 192)
    raw128 = parse_rom(OSD / "OSD_LOGO_ROM_128x128.v", 256)
    codes96, edge96 = resolve_codes(raw96, 96)
    codes128, edge128 = resolve_codes(raw128, 128)
    if any(code == 3 for row in codes96 for code in row):
        raise SystemExit("96 still has edge code")
    if any(code == 3 for row in codes128 for code in row):
        raise SystemExit("128 still has edge code")
    write_logo_mem(pack_logo(codes96), OSD / "osd_logo_init.mem")
    write_gold(codes96, OSD / "osd_logo_gold_96.bin")
    logo_bytes = [int(item, 16) for item in pack_logo(codes128)]
    if len(logo_bytes) != 4096:
        raise SystemExit("logo bytes %d" % len(logo_bytes))
    (OSD / "osd_logo_128_init.mem").write_text(
        "\n".join("%02X" % item for item in logo_bytes) + "\n", encoding="ascii"
    )
    write_mif(IP / "rom_anlogic_logo_128x128" / "rom_anlogic_logo_128x128.mif", logo_bytes, 8)
    write_gold(codes128, OSD / "osd_logo_gold_128.bin")
    bad96 = edge_hue(raw96, 96)
    bad128 = edge_hue(raw128, 128)
    print("resolved edge", edge96, edge128)
    print("edge hue mismatch", bad96, bad128)
    if bad96 or bad128:
        raise SystemExit("edge hue does not match the 8-neighbor vote")


if __name__ == "__main__":
    main()
