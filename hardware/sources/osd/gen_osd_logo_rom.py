# 把安路 logo 用 Lanczos 缩成正方形 BMP，并生成 2 bit 行 ROM。
# 00 白底，01 红线，10 藏青字母，11 不使用。
# 一行一次读出，x 小的像素在高位。

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "doc" / "TF卡图片" / "logo" / "安路logo.png"
LOGO_DIR = ROOT / "doc" / "TF卡图片" / "logo"
OSD_DIR = Path(__file__).resolve().parent


def median(vals):
    vals = sorted(vals)
    return vals[len(vals) // 2]


def pure_colors(im):
    reds = []
    navies = []
    width, height = im.size
    for y in range(height):
        for x in range(width):
            r, g, b = im.getpixel((x, y))
            if r > 160 and r > g + 60 and r > b + 60:
                reds.append((r, g, b))
            elif r < 80 and g < 100 and b > r and b > g and b < 160:
                navies.append((r, g, b))
    if not reds or not navies:
        raise SystemExit("failed to find red or navy in source")
    red = tuple(median([c[i] for c in reds]) for i in range(3))
    navy = tuple(median([c[i] for c in navies]) for i in range(3))
    return red, navy


def coverage(pixel, fg):
    bg = (255, 255, 255)
    num = 0
    den = 0
    for p, f, b in zip(pixel, fg, bg):
        d = f - b
        num += (p - b) * d
        den += d * d
    if den == 0:
        return 0.0
    return num / den


def classify(im, red, navy):
    # 覆盖率高的收成纯色。中间一段标成 11，显示时和相邻前景各混一半，斜边不再是一刀切。
    solid = 0.62
    edge = 0.28
    width, height = im.size
    codes = []
    for y in range(height):
        row = []
        for x in range(width):
            p = im.getpixel((x, y))
            tr = coverage(p, red)
            tn = coverage(p, navy)
            if tr >= tn:
                t, kind = tr, 1
            else:
                t, kind = tn, 2
            if t >= solid:
                row.append(kind)
            elif t >= edge:
                row.append(3)
            else:
                row.append(0)
        codes.append(row)
    return codes


def pack_row(row):
    value = 0
    for code in row:
        value = (value << 2) | code
    return value


def hex_row(value, width):
    digits = width // 2
    text = "%0*X" % (digits, value)
    return "_".join(text[i : i + 8] for i in range(0, digits, 8))


def addr_width(height):
    n = 1
    bits = 0
    while n < height:
        n *= 2
        bits += 1
    return bits


def mix_white(fg):
    return tuple((c + 255) // 2 for c in fg)


def edge_hue(codes):
    height = len(codes)
    width = len(codes[0])
    hue = [[codes[y][x] if codes[y][x] in (1, 2) else 0 for x in range(width)] for y in range(height)]
    for _ in range(3):
        nxt = [row[:] for row in hue]
        for y in range(height):
            for x in range(width):
                if codes[y][x] != 3 or hue[y][x] in (1, 2):
                    continue
                votes = {1: 0, 2: 0}
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy = y + dy
                        xx = x + dx
                        if 0 <= yy < height and 0 <= xx < width and hue[yy][xx] in (1, 2):
                            votes[hue[yy][xx]] += 1
                if votes[1] or votes[2]:
                    nxt[y][x] = 1 if votes[1] >= votes[2] else 2
        hue = nxt
    return hue


def write_bmp(path, codes, red, navy):
    height = len(codes)
    width = len(codes[0])
    hue = edge_hue(codes)
    fg = {1: red, 2: navy}
    out = Image.new("RGB", (width, height))
    for y, row in enumerate(codes):
        for x, code in enumerate(row):
            if code == 1:
                color = red
            elif code == 2:
                color = navy
            elif code == 3 and hue[y][x] in fg:
                color = mix_white(fg[hue[y][x]])
            else:
                color = (255, 255, 255)
            out.putpixel((x, y), color)
    out.save(path, format="BMP")


BANNER = """`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Create Date: 2026/10/18 16:05:00
// Design Name: 
// Module Name: OSD_LOGO_ROM_%dx%d
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 一次读出一行 2bit 像素，低像素在高位
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 2'b00 白底。叠到画面上时透出底图，不覆盖照片
//                      2'b01 红线。24bit RGB 为 COLOR_RED
//                      2'b10 藏青字母。24bit RGB 为 COLOR_NAVY
//                      2'b11 边缘。与相邻 01 或 10 各混合 50%%，减轻斜边锯齿
// 
//////////////////////////////////////////////////////////////////////////////////


"""


def pad_punct(prefix, col, punct):
    if len(prefix) >= col:
        return prefix + punct
    return prefix + (" " * (col - len(prefix))) + punct


def port_line(direction, kind, width, name, last=False):
    if width:
        prefix = "    %-8s%-8s%-12s%s" % (direction, kind, width, name)
    else:
        prefix = "    %-8s%-8s%-12s%s" % (direction, kind, "", name)
    if last:
        if len(prefix) >= 60:
            return prefix
        return prefix + (" " * (60 - len(prefix)))
    return pad_punct(prefix, 60, ",")


def reg_line(width, name):
    if width:
        prefix = "reg     %-24s%s" % (width, name)
    else:
        prefix = "reg                             %s" % name
    return pad_punct(prefix, 60, ";")


def param_line(width, name, value, comment):
    prefix = "localparam  %-20s%s" % (width, name)
    if len(prefix) < 59:
        prefix = prefix + (" " * (59 - len(prefix)))
    return prefix + " = " + value + comment


def write_rom(path, packed, red, navy, size):
    bits = size * 2
    aw = addr_width(size)
    case_lines = []
    for i, value in enumerate(packed):
        label = "%d'd%d" % (aw, i)
        case_lines.append(
            "        %-16s:  line_comb = %d'h%s;"
            % (label, bits, hex_row(value, size))
        )
    case_lines.append(
        "        %-16s:  line_comb = %d'd0;" % ("default", bits)
    )
    body = "\n".join(case_lines)
    text = BANNER % (size, size)
    text += "module OSD_LOGO_ROM_%dx%d (\n" % (size, size)
    text += port_line("input", "wire", "", "clk") + "\n"
    text += port_line("input", "wire", "[%d:0]" % (aw - 1), "addr") + "\n"
    text += port_line("output", "reg", "[%d:0]" % (bits - 1), "line_data", last=True) + "\n"
    text += ");\n"
    text += param_line(
        "[23:0]", "COLOR_RED", "24'h%02X%02X%02X" % red,
        ";//2'b01 红线使用的 24bit RGB\n",
    )
    text += param_line(
        "[23:0]", "COLOR_NAVY", "24'h%02X%02X%02X" % navy,
        ";//2'b10 藏青字母使用的 24bit RGB\n",
    )
    text += param_line(
        "[23:0]", "COLOR_WHITE", "24'hFFFFFF",
        ";//2'b00 白底。2'b11 与该色和前景各混合一半\n",
    )
    text += "\n"
    text += reg_line("[%d:0]" % (bits - 1), "line_comb") + "\n"
    text += "\n"
    text += "always@(*) begin\n"
    text += "    case(addr)\n"
    text += body + "\n"
    text += "    endcase\n"
    text += "end\n"
    text += "\n"
    text += "always@(posedge clk) begin\n"
    text += "    line_data <= line_comb;\n"
    text += "end\n"
    text += "\n"
    text += "endmodule\n"
    path.write_text(text, encoding="utf-8", newline="\n")


def fold_of(packed, bits):
    fold = 0
    words = bits // 32
    for value in packed:
        for i in range(words):
            fold ^= (value >> (32 * i)) & 0xFFFFFFFF
    return fold


def write_tb(path, packed, size):
    bits = size * 2
    aw = addr_width(size)
    fold = fold_of(packed, bits)
    xor_terms = " ^ ".join("line_data[%d:%d]" % (32 * i + 31, 32 * i) for i in range(bits // 32))
    msb = bits - 1
    text = """`timescale 1ns / 1ps
// Clocked read of OSD_LOGO_ROM_%dx%d. One row per address, 1-cycle latency.
// Pixel x=0 is line_data[%d:%d]. Writes osd_logo_readback_%dx%d.bin in the sim directory.

module tb_OSD_LOGO_ROM_%dx%d;

    reg                         clk;
    reg             [%d:0]      addr;
    wire            [%d:0]      line_data;

    localparam      [31:0]      EXPECT_FOLD        = 32'h%08X;

    integer                     fd;
    integer                     row;
    integer                     col;
    integer                     err_n;
    reg             [31:0]      fold;

    OSD_LOGO_ROM_%dx%d uut (
        .clk                    (clk),
        .addr                   (addr),
        .line_data              (line_data)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;

    initial begin
        addr = %d'd0;
        err_n = 0;
        fold = 32'd0;
        fd = $fopen("osd_logo_readback_%dx%d.bin", "wb");
        if (fd == 0) begin
            $display("FAIL open readback %dx%d");
            $finish;
        end
        repeat (2) @(posedge clk);
        for (row = 0; row < %d; row = row + 1) begin
            addr = row[%d:0];
            @(posedge clk);
            #1;
            fold = fold ^ %s;
            for (col = 0; col < %d; col = col + 1) begin
                $fwrite(fd, "%%c", line_data[%d - col * 2 -: 2]);
            end
        end
        $fclose(fd);
        if (fold !== EXPECT_FOLD)
            err_n = err_n + 1;
        if (err_n == 0)
            $display("PASS osd logo read %dx%d");
        else
            $display("FAIL osd logo read %dx%d err_n=%%0d", err_n);
        $finish;
    end

endmodule
""" % (
        size, size,
        msb, msb - 1, size, size,
        size, size,
        aw - 1,
        bits - 1,
        fold,
        size, size,
        aw,
        size, size,
        size, size,
        size,
        aw - 1,
        xor_terms,
        size,
        msb,
        size, size,
        size, size,
    )
    path.write_text(text, encoding="utf-8", newline="\n")


def parse_rom(text, size):
    bits = size * 2
    aw = addr_width(size)
    prefix = "%d'd" % aw
    token = "%d'h" % bits
    rows = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith(prefix) or token not in line:
            continue
        left, right = line.split(":", 1)
        idx = int(left.replace(prefix, "").strip())
        hexpart = right.split(token, 1)[1].split(";", 1)[0]
        hexpart = hexpart.replace("_", "").strip()
        rows[idx] = int(hexpart, 16)
    if len(rows) != size or sorted(rows) != list(range(size)):
        raise SystemExit("parsed row count is %d for %d" % (len(rows), size))
    return [rows[i] for i in range(size)]


def unpack_row(value, size):
    codes = []
    for x in range(size):
        shift = (size - 1 - x) * 2
        codes.append((value >> shift) & 3)
    return codes


def build(src, red, navy, size):
    tag = "%dx%d" % (size, size)
    small = src.resize((size, size), Image.Resampling.LANCZOS)
    bmp = LOGO_DIR / ("安路logo_%s.bmp" % tag)
    v_rom = OSD_DIR / ("OSD_LOGO_ROM_%s.v" % tag)
    v_tb = OSD_DIR / ("tb_OSD_LOGO_ROM_%s.v" % tag)
    rebuild = OSD_DIR / ("OSD_LOGO_读出重建_%s.bmp" % tag)
    small.save(bmp, format="BMP")
    codes = classify(small, red, navy)
    packed = [pack_row(row) for row in codes]
    write_rom(v_rom, packed, red, navy, size)
    write_tb(v_tb, packed, size)
    parsed = parse_rom(v_rom.read_text(encoding="utf-8"), size)
    if parsed != packed:
        raise SystemExit("verilog parse mismatch %s" % tag)
    rebuilt = [unpack_row(value, size) for value in parsed]
    if rebuilt != codes:
        raise SystemExit("readback mismatch %s" % tag)
    write_bmp(rebuild, rebuilt, red, navy)
    counts = {0: 0, 1: 0, 2: 0, 3: 0}
    for row in rebuilt:
        for code in row:
            counts[code] += 1
    print(tag, "red", "%02X%02X%02X" % red, "navy", "%02X%02X%02X" % navy, "counts", counts)


def main():
    src = Image.open(SRC).convert("RGB")
    red, navy = pure_colors(src)
    for size in (96, 128):
        build(src, red, navy, size)


if __name__ == "__main__":
    main()
