import os
# -*- coding: utf-8 -*-
"""Эскиз главного экрана с кнопкой «Создать чертёж»."""
import textwrap
from PIL import Image, ImageDraw, ImageFont

W, H = 720, 1520
BG = (246, 247, 249)
APPBAR = (31, 78, 121)          # тёмно-синий
PRIMARY = (31, 78, 121)
PRIMARY_DARK = (23, 58, 92)
OUTLINE = (190, 196, 205)
GREY = (120, 126, 134)
DARK = (33, 37, 41)
LINE = (226, 229, 234)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

def font(size, bold=False, italic=False):
    base = r"C:\Windows\Fonts\segoeui.ttf"
    b = r"C:\Windows\Fonts\segoeuib.ttf"
    try:
        return ImageFont.truetype(b if bold else base, size)
    except Exception:
        return ImageFont.truetype(base, size)

# ── верхняя панель ──
d.rectangle([0, 0, W, 120], fill=APPBAR)
d.text((28, 40), "Мензулка", font=font(40, True), fill=(255, 255, 255))
# кнопки в шапке (иконки-заглушки)
d.ellipse([W-110, 34, W-62, 82], outline=(255, 255, 255), width=4)
d.ellipse([W-56, 34, W-28, 82], fill=(255, 255, 255))
d.ellipse([W-52, 50, W-32, 70], fill=APPBAR)

# ── тело: пустое состояние ──
heading = "Начните новый чертёж или откройте существующий"
# Перенос по ширине экрана (с запасом) — универсально для любого разрешения.
wrapped = textwrap.fill(heading, width=34)
f_head = font(30)
lines = wrapped.split("\n")
line_h = 40
ty = 170
for ln in lines:
    w_ln = d.textlength(ln, font=f_head)
    d.text(((W - w_ln) / 2, ty), ln, font=f_head, fill=DARK)
    ty += line_h
icon_y = ty + 16
cx = W // 2
d.rounded_rectangle([cx-60, icon_y, cx+60, icon_y+100], radius=12, outline=GREY, width=5)
d.rounded_rectangle([cx-60, icon_y+26, cx-12, icon_y+52], radius=6, outline=GREY, width=5)
d.line([cx-30, icon_y+78, cx, icon_y+52], fill=GREY, width=5)
d.line([cx, icon_y+52, cx+30, icon_y+78], fill=GREY, width=5)

# кнопки
btn_w = 460
bx = (W - btn_w) // 2

def button(y, label, fill, txt_color, bold=True, icon=None, h=84):
    d.rounded_rectangle([bx, y, bx+btn_w, y+h], radius=18, fill=fill,
                        outline=None if fill != BG else OUTLINE, width=3)
    tx = bx + 40
    if icon == "plus":
        d.line([tx+14, y+h//2, tx+38, y+h//2], fill=txt_color, width=6)
        d.line([tx+26, y+h//2-12, tx+26, y+h//2+12], fill=txt_color, width=6)
        tx += 52
    d.text((tx, y + h//2 - 18), label, font=font(32, bold), fill=txt_color)

y = 420
button(y, "Создать чертёж", PRIMARY, (255, 255, 255), icon="plus")
y += 84 + 18
button(y, "Открыть DXF", PRIMARY_DARK, (255, 255, 255))
y += 84 + 18
button(y, "Импортировать проект", BG, OUTLINE)
y += 84 + 40

# подпись над новинкой
d.text((bx, y), "Создать чертёж — новый пустой DXF, готовый к работе",
       font=font(26), fill=GREY)
y += 60

# ── последние чертежи ──
d.line([30, y, W-30, y], fill=LINE, width=3)
d.text((30, y+24), "Последние чертежи", font=font(30, True), fill=DARK)
y += 90
recent = [
    ("111_export_v10", "м"),
    ("Корпус А ПП +29.150", "мм"),
    ("scale_large", "м"),
]
for name, units in recent:
    d.rounded_rectangle([30, y, W-30, y+84], radius=14, fill=(255, 255, 255),
                        outline=LINE, width=2)
    d.rounded_rectangle([48, y+16, 96, y+64], radius=6, outline=PRIMARY, width=4)
    d.text((120, y+16), name, font=font(30, True), fill=DARK)
    d.text((120, y+50), units, font=font(24), fill=GREY)
    d.text((W-60, y+30), "›", font=font(40, True), fill=GREY)
    y += 84 + 14

img.save(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "эскиз_главный_экран.png"))
print("saved")
