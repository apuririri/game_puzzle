#!/usr/bin/env python3
"""
プリズマ☆リンク 用の app icon を生成するスクリプト。

- ソース画像: assets/image/character/hina/joy.webp
- 出力先:
  * res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.webp
  * res/mipmap-{...}/ic_launcher_round.webp
  * res/drawable/ic_launcher_foreground.webp   (adaptive icon 用: 432x432)
  * res/drawable/ic_launcher_background.xml    (グラデ背景)
  * res/mipmap-anydpi-v26/ic_launcher.xml      (adaptive icon)
  * res/mipmap-anydpi-v26/ic_launcher_round.xml
- 参考プレビュー: build/icon_preview.png

ゲーム調のポップな見た目にするため:
- 紫→ピンクのグラデ背景
- キラキラ (小さな★型)
- キャラの顔中心をクロップして中央配置
- 外周に細い光輪
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math

REPO = Path(__file__).resolve().parents[2]
RES = REPO / "app" / "src" / "main" / "res"
SRC = REPO / "app" / "src" / "main" / "assets" / "image" / "character" / "hina" / "joy.webp"

# --- 1) 1024x1024 の legacy icon を作る（正方形版・radial gradient背景 + キャラ + 光輪 + キラキラ） ---

BG_A = (26, 15, 46)   # 0xFF1A0F2E
BG_B = (60, 25, 90)   # ミッド
BG_C = (124, 77, 255) # 0xFF7C4DFF
ACC = (255, 111, 168) # 0xFFFF6FA8
GOLD = (255, 194, 46) # 0xFFFFC22E


def radial_gradient(size: int, inner: tuple, outer: tuple) -> Image.Image:
    img = Image.new("RGB", (size, size), outer)
    px = img.load()
    cx = cy = size / 2
    max_r = math.hypot(cx, cy)
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - cx, y - cy) / max_r
            r = min(1.0, r)
            px[x, y] = (
                int(inner[0] + (outer[0] - inner[0]) * r),
                int(inner[1] + (outer[1] - inner[1]) * r),
                int(inner[2] + (outer[2] - inner[2]) * r),
            )
    return img


def add_sparkles(img: Image.Image, n: int = 40) -> Image.Image:
    import random
    random.seed(7)
    draw = ImageDraw.Draw(img, "RGBA")
    w, h = img.size
    for _ in range(n):
        cx = random.randint(int(w * 0.05), int(w * 0.95))
        cy = random.randint(int(h * 0.05), int(h * 0.95))
        r = random.randint(4, 14)
        alpha = random.randint(140, 230)
        color = (255, 255, 255, alpha)
        # +
        draw.line([(cx - r, cy), (cx + r, cy)], fill=color, width=2)
        draw.line([(cx, cy - r), (cx, cy + r)], fill=color, width=2)
        # 中心の点
        draw.ellipse([(cx - 3, cy - 3), (cx + 3, cy + 3)], fill=(255, 255, 255, 255))
    # ブラーで光らせる
    glow = img.filter(ImageFilter.GaussianBlur(radius=3))
    return Image.blend(img, glow, 0.35)


def add_ring(img: Image.Image, color=(255, 194, 46, 200)) -> Image.Image:
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    m = int(w * 0.06)
    d.ellipse([m, m, w - m, h - m], outline=color, width=int(w * 0.012))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def crop_character_head(size: int) -> Image.Image:
    src = Image.open(SRC).convert("RGBA")
    W, H = src.size  # 512, 748
    # 顔中心を上寄りにクロップ (だいたい上から 8%〜70% の中央 60%)
    cx = W // 2
    top = int(H * 0.02)
    bottom = int(H * 0.66)
    face_h = bottom - top
    left = cx - face_h // 2
    right = cx + face_h // 2
    if left < 0:
        left = 0
        right = face_h
    if right > W:
        right = W
        left = W - face_h
    crop = src.crop((left, top, right, bottom))
    return crop.resize((size, size), Image.LANCZOS)


def make_square_icon(size: int = 1024) -> Image.Image:
    bg = radial_gradient(size, ACC, BG_A).convert("RGBA")
    # 対角の紫〜ピンクブレンド
    diag = Image.new("RGBA", (size, size))
    for y in range(size):
        t = y / size
        r = int(BG_C[0] * (1 - t) + ACC[0] * t)
        g = int(BG_C[1] * (1 - t) + ACC[1] * t)
        b = int(BG_C[2] * (1 - t) + ACC[2] * t)
        ImageDraw.Draw(diag).line([(0, y), (size, y)], fill=(r, g, b, 90))
    bg = Image.alpha_composite(bg, diag)

    bg = add_sparkles(bg.convert("RGBA"), n=50)

    # 光輪
    bg = add_ring(bg, color=(255, 215, 128, 200))

    # キャラを丸くくり抜いて中央に貼る
    char_size = int(size * 0.70)
    char = crop_character_head(char_size)
    # 円マスク
    mask = Image.new("L", (char_size, char_size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, char_size, char_size], fill=255)
    # 縁の白ラインを描く用の下地
    circle_bg = Image.new("RGBA", (char_size + 24, char_size + 24), (0, 0, 0, 0))
    ImageDraw.Draw(circle_bg).ellipse(
        [0, 0, char_size + 24, char_size + 24], fill=(255, 255, 255, 230)
    )
    ImageDraw.Draw(circle_bg).ellipse(
        [12, 12, char_size + 12, char_size + 12], fill=(26, 15, 46, 255)
    )
    ox = (size - (char_size + 24)) // 2
    oy = (size - (char_size + 24)) // 2 - int(size * 0.02)
    bg.paste(circle_bg, (ox, oy), circle_bg)
    bg.paste(char, (ox + 12, oy + 12), mask)

    return bg


# --- 2) adaptive icon foreground (432x432 の中心66% 内にキャラを収める) ---

def make_foreground(size: int = 432) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.62)  # safe zone
    char = crop_character_head(inner)
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, inner, inner], fill=255)

    # 白リング
    ring_size = inner + int(size * 0.045)
    ring = Image.new("RGBA", (ring_size, ring_size), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse([0, 0, ring_size, ring_size], fill=(255, 255, 255, 230))
    # 内側の濃紫
    pad = int(size * 0.022)
    ImageDraw.Draw(ring).ellipse(
        [pad, pad, ring_size - pad, ring_size - pad], fill=(26, 15, 46, 255)
    )
    ox = (size - ring_size) // 2
    oy = (size - ring_size) // 2
    img.paste(ring, (ox, oy), ring)
    img.paste(char, (ox + pad, oy + pad), mask)
    return img


def make_round_icon(square: Image.Image) -> Image.Image:
    w, h = square.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w, h], fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(square, (0, 0), mask)
    return out


def save_webp(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="WEBP", quality=92)
    print(f"[icon] wrote {path.relative_to(REPO)}")


def main():
    sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    square = make_square_icon(1024)
    round_ = make_round_icon(square)

    build_dir = REPO / "build"
    build_dir.mkdir(exist_ok=True)
    square.save(build_dir / "icon_preview.png")
    round_.save(build_dir / "icon_preview_round.png")

    for density, px in sizes.items():
        save_webp(square.resize((px, px), Image.LANCZOS),
                  RES / f"mipmap-{density}" / "ic_launcher.webp")
        save_webp(round_.resize((px, px), Image.LANCZOS),
                  RES / f"mipmap-{density}" / "ic_launcher_round.webp")

    # adaptive icon foreground（432x432 想定 = xxxhdpi）
    fg = make_foreground(432)
    save_webp(fg, RES / "drawable" / "ic_launcher_foreground.webp")

    print("[icon] done")


if __name__ == "__main__":
    main()
