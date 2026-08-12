#!/usr/bin/env python3
"""生成 App 图标（assets/icon/）：靛蓝底 + 白色「背」字。

产出：
- app_icon.png      1024x1024 完整图标（legacy）
- foreground.png    透明底 + 居中白色「背」字（adaptive foreground）
- background.png    纯色底（adaptive background）
"""
import os
from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
COLOR = (63, 81, 181, 255)  # 靛蓝 #3F51B5
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')

FONT_CANDIDATES = [
    r'C:\Windows\Fonts\msyhbd.ttc',  # 微软雅黑 Bold
    r'C:\Windows\Fonts\simhei.ttf',
    r'C:\Windows\Fonts\msyh.ttc',
]


def font(size):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    raise FileNotFoundError('未找到可用的中文字体')


def draw_char(img, text, color, font_size, y_offset=0):
    d = ImageDraw.Draw(img)
    f = font(font_size)
    bbox = d.textbbox((0, 0), text, font=f)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = (SIZE - w) // 2 - bbox[0]
    y = (SIZE - h) // 2 - bbox[1] + y_offset
    d.text((x, y), text, font=f, fill=color)


def rounded(img, radius):
    mask = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, SIZE - 1, SIZE - 1), radius=radius, fill=255)
    out = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)

    # 完整图标：靛蓝圆角底 + 白色「背」字
    icon = Image.new('RGBA', (SIZE, SIZE), COLOR)
    icon = rounded(icon, 180)
    draw_char(icon, '背', (255, 255, 255, 255), 520, y_offset=10)
    icon.save(os.path.join(OUT, 'app_icon.png'))

    # adaptive foreground：透明底 + 白色「背」字（占安全区 ~66%）
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw_char(fg, '背', (255, 255, 255, 255), 460)
    fg.save(os.path.join(OUT, 'foreground.png'))

    # adaptive background：纯色
    bg = Image.new('RGBA', (SIZE, SIZE), COLOR)
    bg.save(os.path.join(OUT, 'background.png'))

    print('图标已生成到', os.path.abspath(OUT))


if __name__ == '__main__':
    main()
