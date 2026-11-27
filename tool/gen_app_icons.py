#!/usr/bin/env python3
"""Generate circular Tarot Tree app icons for Android, iOS, Web/PWA, and Promo site.

Source: assets/loader/logo.png (white Tarot Tree silhouette).
Palette: Project primary brand lavender-indigo gradient (#B497FF -> #8F6DF0 -> #654CD4)
anchored on TaroColors.lavender (#A78BFA) & TaroColors.indigo (#6366F1),
with a crisp luminous white Tarot Tree emblem.

Run with:
    /home/rodion/Project/tarottree/backend/.venv/bin/python tool/gen_app_icons.py
"""
from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
LOGO_PATH = ROOT / "assets" / "loader" / "logo.png"

# Project primary brand lavender-violet palette (anchored on TaroColors.lavender #A78BFA)
COL_BRAND_LIGHT = (180, 151, 255)   # #B497FF — luminous lavender upper highlight
COL_BRAND_CORE = (143, 109, 240)    # #8F6DF0 — signature brand lavender-violet
COL_BRAND_DEEP = (101, 76, 212)     # #654CD4 — rich indigo-violet outer depth
COL_SHADOW = (38, 22, 92)           # deep violet contact shadow behind white tree
COL_TREE = (255, 255, 255)          # crisp pure white emblem
COL_RING = (255, 255, 255)          # delicate luminous inner hairline


def _lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def _lerp_rgb(
    c1: tuple[int, int, int],
    c2: tuple[int, int, int],
    t: float,
) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (_lerp(c1[0], c2[0], t), _lerp(c1[1], c2[1], t), _lerp(c1[2], c2[2], t))


def _prepare_crisp_tree(target_max_dim: int) -> Image.Image:
    """Upscale logo.png cleanly and crisp its alpha silhouette without jaggedness."""
    src = Image.open(LOGO_PATH).convert("RGBA")
    bbox = src.getbbox()
    if bbox:
        src = src.crop(bbox)
    w, h = src.size
    scale = target_max_dim / max(w, h)
    nw, nh = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
    alpha = src.getchannel("A").resize((nw, nh), Image.Resampling.LANCZOS)
    alpha = alpha.filter(ImageFilter.GaussianBlur(radius=0.55))
    lut = [
        0 if i < 92 else (255 if i > 172 else int(round((i - 92) * 255 / 80)))
        for i in range(256)
    ]
    crisp_alpha = alpha.point(lut)
    tree = Image.new("RGBA", (nw, nh), (*COL_TREE, 0))
    tree.putalpha(crisp_alpha)
    return tree


def _build_brand_gradient(size: int) -> Image.Image:
    """Build a smooth radial gradient in Tarot Tree's signature lavender-indigo color."""
    grid = 256
    img = Image.new("RGBA", (grid, grid))
    px = img.load()
    cx, cy = grid * 0.46, grid * 0.34
    max_r = grid * 0.68
    for y in range(grid):
        for x in range(grid):
            dx = (x - cx) / max_r
            dy = (y - cy) / max_r
            d = math.hypot(dx, dy)
            if d < 0.52:
                c = _lerp_rgb(COL_BRAND_LIGHT, COL_BRAND_CORE, d / 0.52)
            elif d < 1.05:
                c = _lerp_rgb(COL_BRAND_CORE, COL_BRAND_DEEP, (d - 0.52) / 0.53)
            else:
                c = COL_BRAND_DEEP
            px[x, y] = (*c, 255)
    return img.resize((size, size), Image.Resampling.BICUBIC)


def _render_medallion(
    size: int,
    *,
    circle_ratio: float,
    tree_ratio: float,
    full_bleed_bg: bool = False,
    draw_circle_fill: bool = True,
    ring_alpha: int = 76,
    ring_width_ratio: float = 0.012,
    draw_ring: bool = True,
) -> Image.Image:
    """Render the white Tarot Tree emblem on the project's primary lavender circle."""
    work = max(1024, size * 2)
    if full_bleed_bg:
        canvas = _build_brand_gradient(work)
    else:
        canvas = Image.new("RGBA", (work, work), (0, 0, 0, 0))

    cx = work / 2.0
    cy = work / 2.0
    r = (work * circle_ratio) / 2.0
    box = (cx - r, cy - r, cx + r, cy + r)

    if draw_circle_fill and not full_bleed_bg:
        # Subtle outer drop shadow for floating circular icons
        shadow = Image.new("RGBA", (work, work), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.ellipse(box, fill=(20, 12, 52, 85))
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=work * 0.018))
        canvas = Image.alpha_composite(canvas, shadow)

        # Clip brand lavender gradient cleanly to the circle
        grad = _build_brand_gradient(work)
        mask = Image.new("L", (work, work), 0)
        ImageDraw.Draw(mask).ellipse(box, fill=255)
        circle_layer = Image.new("RGBA", (work, work), (0, 0, 0, 0))
        circle_layer.paste(grad, (0, 0), mask)
        canvas = Image.alpha_composite(canvas, circle_layer)

    if draw_ring and ring_alpha > 0:
        ring_layer = Image.new("RGBA", (work, work), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ring_layer)
        ring_w = max(2, int(round(work * ring_width_ratio)))
        inset = ring_w * 1.9
        ring_box = (
            box[0] + inset,
            box[1] + inset,
            box[2] - inset,
            box[3] - inset,
        )
        rd.ellipse(ring_box, outline=(*COL_RING, ring_alpha), width=ring_w)
        canvas = Image.alpha_composite(canvas, ring_layer)

    # Inscribed pure white Tarot Tree with subtle deep-violet elevation shadow
    tree_max = int(round(work * circle_ratio * tree_ratio))
    tree = _prepare_crisp_tree(tree_max)
    tw, th = tree.size
    # Optical centering: roots extend down-right, nudge slightly up-left
    tx = int(round(cx - tw / 2.0 - work * 0.005))
    ty = int(round(cy - th / 2.0 - work * 0.012))

    # Soft contact shadow beneath the white tree for crisp legibility at small sizes
    drop = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    drop_src = Image.new("RGBA", (tw, th), (*COL_SHADOW, 0))
    drop_src.putalpha(tree.getchannel("A").point(lambda a: int(a * 0.34)))
    drop.paste(drop_src, (tx, ty + int(round(work * 0.010))))
    drop = drop.filter(ImageFilter.GaussianBlur(radius=work * 0.018))
    canvas = Image.alpha_composite(canvas, drop)

    tree_layer = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    tree_layer.paste(tree, (tx, ty))
    canvas = Image.alpha_composite(canvas, tree_layer)

    out = canvas.resize((size, size), Image.Resampling.LANCZOS)
    if full_bleed_bg:
        return out.convert("RGB")
    return out


def generate_android() -> None:
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    legacy_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    adaptive_fg_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    for folder, px in legacy_sizes.items():
        d = res / folder
        d.mkdir(parents=True, exist_ok=True)
        icon = _render_medallion(
            px,
            circle_ratio=0.92,
            tree_ratio=0.70,
            full_bleed_bg=False,
            draw_circle_fill=True,
            ring_alpha=72,
            ring_width_ratio=0.013,
        )
        icon.save(d / "ic_launcher.png", optimize=True)
        icon.save(d / "ic_launcher_round.png", optimize=True)

    for folder, px in adaptive_fg_sizes.items():
        d = res / folder
        d.mkdir(parents=True, exist_ok=True)
        # Adaptive foreground sits over the lavender ic_launcher_background.xml
        # and stays strictly inside the 66/108dp safe zone (~0.61).
        fg = _render_medallion(
            px,
            circle_ratio=0.62,
            tree_ratio=0.72,
            full_bleed_bg=False,
            draw_circle_fill=False,
            ring_alpha=68,
            ring_width_ratio=0.010,
        )
        fg.save(d / "ic_launcher_foreground.png", optimize=True)


def generate_ios() -> None:
    appicon = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_specs = [
        ("Icon-App-20x20@1x.png", 20),
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ]
    for name, px in ios_specs:
        icon = _render_medallion(
            px,
            circle_ratio=0.88,
            tree_ratio=0.72,
            full_bleed_bg=True,
            draw_circle_fill=False,
            ring_alpha=68,
            ring_width_ratio=0.012,
        )
        icon.save(appicon / name, optimize=True)


def generate_web() -> None:
    web = ROOT / "web"
    icons = web / "icons"
    icons.mkdir(parents=True, exist_ok=True)

    _render_medallion(
        32,
        circle_ratio=0.96,
        tree_ratio=0.72,
        full_bleed_bg=False,
        draw_circle_fill=True,
        ring_alpha=64,
        ring_width_ratio=0.024,
    ).save(web / "favicon.png", optimize=True)

    for px in (192, 512):
        _render_medallion(
            px,
            circle_ratio=0.94,
            tree_ratio=0.70,
            full_bleed_bg=False,
            draw_circle_fill=True,
            ring_alpha=72,
            ring_width_ratio=0.013,
        ).save(icons / f"Icon-{px}.png", optimize=True)

        # Maskable PWA icon: full-bleed lavender gradient + emblem in safe zone
        _render_medallion(
            px,
            circle_ratio=0.78,
            tree_ratio=0.72,
            full_bleed_bg=True,
            draw_circle_fill=False,
            ring_alpha=68,
            ring_width_ratio=0.011,
        ).save(icons / f"Icon-maskable-{px}.png", optimize=True)


def generate_promo() -> None:
    promo_pub = ROOT / "promo-tarottree" / "public"
    if not promo_pub.exists():
        return

    fav64 = _render_medallion(
        64,
        circle_ratio=0.94,
        tree_ratio=0.72,
        full_bleed_bg=False,
        draw_circle_fill=True,
        ring_alpha=68,
        ring_width_ratio=0.018,
    )
    fav64.save(promo_pub / "favicon.png", optimize=True)
    legacy_fav = promo_pub / "static" / "assets" / "images" / "favicon.png"
    if legacy_fav.parent.exists():
        fav64.save(legacy_fav, optimize=True)

    _render_medallion(
        180,
        circle_ratio=0.88,
        tree_ratio=0.72,
        full_bleed_bg=True,
        draw_circle_fill=False,
        ring_alpha=68,
        ring_width_ratio=0.012,
    ).save(promo_pub / "apple-touch-icon.png", optimize=True)


def main() -> None:
    generate_android()
    generate_ios()
    generate_web()
    generate_promo()
    print("Generated lavender-filled circular Tarot Tree icons for Android, iOS, Web, and Promo.")


if __name__ == "__main__":
    main()
