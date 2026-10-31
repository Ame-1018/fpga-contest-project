# 菜单标题和行名，供 VPU_MENU_OSD 同步 ROM 使用。
pages = [
    ["Back", "Switch", "Mode", "Speed"],
    ["Back", "Switch", "Brightness", "Contrast", "Warmth", "Tint"],
    ["Back", "Switch", "Mode", "Threshold"],
    ["Back", "Overlay", "Origin X", "Origin Y"],
    ["Back", "Caption", "Origin X", "Origin Y", "Width", "Speed", "Color"],
    ["Back", "Switch", "Color", "Origin X", "Origin Y"],
    ["Back", "Switch", "Width", "Height"],
]
titles = ["Transition", "Color", "Style", "Logo", "Caption", "Audio", "Scale"]
mem = [0x20] * 1280
for p, items in enumerate(pages):
    for it, name in enumerate(items):
        base = (p * 10 + it) * 16
        raw = name.ljust(12)[:12]
        for c, ch in enumerate(raw):
            mem[base + c] = ord(ch)
for p, name in enumerate(titles):
    base = 1120 + p * 16
    raw = name.ljust(12)[:12]
    for c, ch in enumerate(raw):
        mem[base + c] = ord(ch)
with open("menu_label.mem", "w", encoding="ascii", newline="\n") as f:
    for b in mem:
        f.write("%02X\n" % b)
print(len(mem))
