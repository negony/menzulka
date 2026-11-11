import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
SIZE = 1024
TOP = (17, 25, 37)
BOTTOM = (34, 56, 82)
CYAN = (58, 217, 255, 255)
ORANGE = (255, 122, 26, 255)
WHITE = (255, 255, 255, 255)
DARK = (22, 34, 48, 255)


def gradient_square():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    grad = Image.new('RGBA', (SIZE, SIZE))
    gd = ImageDraw.Draw(grad)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        c = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)) + (255,)
        gd.line([(0, y), (SIZE, y)], fill=c)
    mask = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=232, fill=255)
    img = Image.composite(grad, img, mask)
    d = ImageDraw.Draw(img)
    for x in range(0, SIZE + 1, 128):
        for y in range(0, SIZE + 1, 128):
            if 60 < x < SIZE - 60 and 60 < y < SIZE - 60:
                d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(255, 255, 255, 18))
    return img


def draw_pin(d, cx, hy, hr, inner_r, cross_len, cross_w, dot_r, tail_w, tail_tip_y):
    d.polygon(
        [(cx - tail_w, hy + hr * 0.6), (cx + tail_w, hy + hr * 0.6), (cx, tail_tip_y)],
        fill=WHITE,
    )
    d.ellipse([cx - hr, hy - hr, cx + hr, hy + hr], fill=WHITE)
    d.ellipse([cx - inner_r, hy - inner_r, cx + inner_r, hy + inner_r], fill=DARK)
    d.line([(cx - cross_len, hy), (cx + cross_len, hy)], fill=CYAN, width=cross_w)
    d.line([(cx, hy - cross_len), (cx, hy + cross_len)], fill=CYAN, width=cross_w)
    d.ellipse([cx - dot_r, hy - dot_r, cx + dot_r, hy + dot_r], fill=ORANGE)


# ---------- полная иконка (legacy Android + Windows) ----------
icon = gradient_square()
d = ImageDraw.Draw(icon)
draw_pin(d, 512, 448, 198, 134, 112, 26, 44, 140, 890)

legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for name, s in legacy.items():
    out = os.path.join(RES, f'mipmap-{name}')
    os.makedirs(out, exist_ok=True)
    small = icon.resize((s, s), Image.LANCZOS)
    small.save(os.path.join(out, 'ic_launcher.png'))
    small.save(os.path.join(out, 'ic_launcher_round.png'))

# ---------- adaptive foreground (прозрачный, в safe zone) ----------
fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
fd = ImageDraw.Draw(fg)
draw_pin(fd, 512, 470, 170, 116, 96, 22, 38, 120, 800)
adaptive = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
for name, dp in adaptive.items():
    out = os.path.join(RES, f'mipmap-{name}')
    os.makedirs(out, exist_ok=True)
    fg.resize((dp, dp), Image.LANCZOS).save(os.path.join(out, 'ic_launcher_foreground.png'))

# ---------- Windows .ico ----------
ico_path = os.path.join(ROOT, 'windows', 'runner', 'resources', 'app_icon.ico')
os.makedirs(os.path.dirname(ico_path), exist_ok=True)
icon.save(
    ico_path,
    format='ICO',
    sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)],
)
print('assets ok')
