#!/usr/bin/env python3
"""从 icons/app_icon_source.png 生成 Android 应用图标。

一次产出两类东西：
- 传统方形图标 mipmap-*/ic_launcher.png（Android 7 及以下用，不套遮罩）；
- adaptive icon 分层（Android 8+）：透明前景 mipmap-*/ic_launcher_foreground.png
  + 纯色背景位图 mipmap-*/ic_launcher_background.png + 描述文件 mipmap-anydpi-v26/ic_launcher.xml。

为什么要脚本而不是直接缩放：源图是「自带圆角的深色方块」，而 adaptive icon 会被
启动器按圆形/圆角方形再切一次，圆角套圆角就会露出黑边、内容也被切掉。所以先把
圆角外的近黑像素补成图内同一支深色（变成铺满的方形），再把画面缩进 66/108 的
安全区，只留背景铺满整张画布。

用法：python tool/gen_icons.py
"""

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'icons', 'app_icon_source.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

# 源图方块内部的深色底，也是 adaptive 图层的背景色。
BG = (10, 18, 31)
# 传统图标边长（108dp 之外的 48dp 基准）与各密度 adaptive 画布边长（108dp）。
LEGACY_PX = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
ADAPTIVE_PX = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
# 前景内容占画布的比例：adaptive 的安全区是 108dp 中间那 66dp。
SAFE_RATIO = 66 / 108


def full_bleed(img: Image.Image) -> Image.Image:
    """把源图圆角外的近黑区域补成 BG，得到铺满的方形画面。

    按颜色整批替换而不是从角上泛洪填充：实测图里最暗的内容（棋子本体）是
    (5,10,17)，蓝通道远大于这里的门槛 8，所以不会被误伤。
    """
    out = img.convert('RGB').copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            if max(px[x, y]) < 8:
                px[x, y] = BG
    return out


def content_box(img: Image.Image) -> tuple[int, int, int, int]:
    """画面里真正有内容的那块（离 BG 够远的像素外接框），用来算缩放。"""
    w, h = img.size
    px = img.load()
    min_x, min_y, max_x, max_y = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2]) > 60:
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
                if y < min_y:
                    min_y = y
                if y > max_y:
                    max_y = y
    return min_x, min_y, max_x + 1, max_y + 1


def foreground(img: Image.Image, box: tuple[int, int, int, int], canvas: int) -> Image.Image:
    """把图案（裁掉四周多余底色）缩进 canvas 的中间安全区，画成透明底前景层。

    只贴图案、不贴源图那整块深色底：前景层留透明、底色交给背景层，才是 adaptive
    icon 的规范分层，也省得两层各画一遍底色对不齐。裁切时按内容尺寸留 6% 余量，
    让宝箱那圈青色辉光自然淡出到背景色，看不出裁痕。
    """
    x0, y0, x1, y1 = box
    side = max(x1 - x0, y1 - y0)
    margin = round(side * 0.06)
    cx0, cy0 = max(0, x0 - margin), max(0, y0 - margin)
    cx1, cy1 = min(img.size[0], x1 + margin), min(img.size[1], y1 + margin)
    crop = img.crop((cx0, cy0, cx1, cy1))
    scale = canvas * SAFE_RATIO / side
    sized = crop.resize((round(crop.size[0] * scale), round(crop.size[1] * scale)), Image.LANCZOS)
    layer = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    # 对齐的是内容中心，不是裁块中心（余量在四边不一定对称）。
    layer.paste(sized, (round(canvas / 2 - (x0 + x1) / 2 * scale + cx0 * scale),
                        round(canvas / 2 - (y0 + y1) / 2 * scale + cy0 * scale)))
    return layer


def main() -> None:
    src = Image.open(SRC)
    art = full_bleed(src)
    box = content_box(art)
    print(f'source {src.size} content box {box} '
          f'({box[2] - box[0]}x{box[3] - box[1]})')

    for dpi, px in LEGACY_PX.items():
        path = os.path.join(RES, f'mipmap-{dpi}', 'ic_launcher.png')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        art.resize((px, px), Image.LANCZOS).save(path)
        print('wrote', os.path.relpath(path, ROOT))

    for dpi, px in ADAPTIVE_PX.items():
        path = os.path.join(RES, f'mipmap-{dpi}', 'ic_launcher_foreground.png')
        foreground(art, box, px).save(path)
        print('wrote', os.path.relpath(path, ROOT))
        # 背景层给位图而不是 @color：模拟器上的 Pixel 启动器遇到纯色背景层会忽略它，
        # 自己按图标主色生成一圈底色（实测生成成了金环）；位图背景层照用。
        bgpath = os.path.join(RES, f'mipmap-{dpi}', 'ic_launcher_background.png')
        Image.new('RGB', (px, px), BG).save(bgpath)
        print('wrote', os.path.relpath(bgpath, ROOT))

    anydpi = os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml')
    os.makedirs(os.path.dirname(anydpi), exist_ok=True)
    with open(anydpi, 'w', encoding='utf-8', newline='\n') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '</adaptive-icon>\n')
    print('wrote', os.path.relpath(anydpi, ROOT))


if __name__ == '__main__':
    main()
