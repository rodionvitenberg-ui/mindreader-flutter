#!/usr/bin/env python3
"""Extract 5 isolated volumetric 3D rune stone sprites from a studio contact sheet.

Usage:
    python3 tool/process_rune_stones.py <input_sheet.png> <output_dir> [--bg white|chroma]

Algorithm:
  1. Estimates the studio backdrop color from the image border pixels.
  2. Flood-fills from all image borders using color distance so interior stone
     highlights are NEVER punched out (even bright specular glints on dark stones).
  3. Applies smooth anti-aliased edge feathering + color decontamination (defringing)
     so stones have zero bright/blue halos on obsidian #09090D backgrounds.
  4. Finds the 5 largest connected components (the 5 distinct stones), sorts them
     top-to-bottom / left-to-right, normalizes each stone to a 384x448 transparent
     RGBA canvas (filling ~86% of canvas height/width, centroid aligned), and saves
     as `stone_0.webp` .. `stone_4.webp`.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


TARGET_W = 384
TARGET_H = 448
FILL_FRACTION = 0.86


def _estimate_border_color(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    border = np.concatenate(
        [
            rgb[0, :, :],
            rgb[h - 1, :, :],
            rgb[:, 0, :],
            rgb[:, w - 1, :],
        ],
        axis=0,
    )
    return np.median(border, axis=0)


def _flood_fill_background(rgb: np.ndarray, bg_color: np.ndarray, tol: float) -> np.ndarray:
    """Return boolean mask True where pixel is background connected to image border."""
    h, w, _ = rgb.shape
    diff = np.linalg.norm(rgb.astype(np.float32) - bg_color.astype(np.float32), axis=2)
    candidate = diff <= tol

    bg_mask = np.zeros((h, w), dtype=bool)
    q: deque[tuple[int, int]] = deque()

    for x in range(w):
        if candidate[0, x]:
            bg_mask[0, x] = True
            q.append((0, x))
        if candidate[h - 1, x] and not bg_mask[h - 1, x]:
            bg_mask[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if candidate[y, 0] and not bg_mask[y, 0]:
            bg_mask[y, 0] = True
            q.append((y, 0))
        if candidate[y, w - 1] and not bg_mask[y, w - 1]:
            bg_mask[y, w - 1] = True
            q.append((y, w - 1))

    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg_mask[ny, nx] and candidate[ny, nx]:
                bg_mask[ny, nx] = True
                q.append((ny, nx))

    return bg_mask


def _connected_components(fg: np.ndarray) -> list[tuple[int, int, int, int, int, np.ndarray]]:
    """Find connected components in boolean mask. Returns (area, y0, x0, y1, x1, coords)."""
    h, w = fg.shape
    visited = np.zeros((h, w), dtype=bool)
    comps: list[tuple[int, int, int, int, int, np.ndarray]] = []

    ys, xs = np.nonzero(fg)
    for start_y, start_x in zip(ys.tolist(), xs.tolist()):
        if visited[start_y, start_x]:
            continue
        q = deque([(start_y, start_x)])
        visited[start_y, start_x] = True
        pixels: list[tuple[int, int]] = []
        y0 = y1 = start_y
        x0 = x1 = start_x
        while q:
            y, x = q.popleft()
            pixels.append((y, x))
            if y < y0:
                y0 = y
            if y > y1:
                y1 = y
            if x < x0:
                x0 = x
            if x > x1:
                x1 = x
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not visited[ny, nx]:
                    visited[ny, nx] = True
                    q.append((ny, nx))
        if len(pixels) >= 1500:
            comps.append((len(pixels), y0, x0, y1 + 1, x1 + 1, np.array(pixels, dtype=np.int32)))

    comps.sort(key=lambda c: c[0], reverse=True)
    return comps


def _defringe_and_alpha(
    crop_rgb: np.ndarray,
    crop_fg: np.ndarray,
    bg_color: np.ndarray,
    soft_band: float,
    hard_tol: float,
) -> Image.Image:
    """Create clean anti-aliased RGBA image with zero backdrop halo."""
    h, w, _ = crop_rgb.shape
    rgb_f = crop_rgb.astype(np.float32)
    dist = np.linalg.norm(rgb_f - bg_color.astype(np.float32), axis=2)

    # Erode fg by 1px to separate guaranteed interior from edge pixels.
    fg_img = Image.fromarray((crop_fg.astype(np.uint8) * 255), mode="L")
    eroded = np.array(fg_img.filter(ImageFilter.MinFilter(5))) > 127

    alpha = np.where(crop_fg, 1.0, 0.0).astype(np.float32)
    # Softly ramp alpha only along the 2px boundary band (never interior).
    edge_band = crop_fg & (~eroded)
    edge_alpha = np.clip((dist - hard_tol * 0.65) / max(1.0, soft_band), 0.0, 1.0)
    alpha = np.where(edge_band, np.minimum(alpha, edge_alpha), alpha)

    # Slight 0.7px Gaussian blur on alpha for silky smooth anti-aliasing.
    alpha_img = Image.fromarray(np.clip(alpha * 255, 0, 255).astype(np.uint8), mode="L")
    alpha_smooth = np.array(alpha_img.filter(ImageFilter.GaussianBlur(radius=0.8)), dtype=np.float32) / 255.0
    # Keep solid interior 100% opaque and far background 0% opaque.
    alpha_final = np.where(eroded, 1.0, np.where(crop_fg, alpha_smooth, alpha_smooth * 0.35))
    alpha_final = np.where(alpha_final < 0.05, 0.0, alpha_final)

    # Color decontamination (unmix bg_color from semi-transparent edge pixels)
    # and pull fringe colors gently toward nearest interior stone color.
    out_rgb = rgb_f.copy()
    semi = (alpha_final > 0.05) & (alpha_final < 0.98)
    if np.any(semi):
        a = np.maximum(alpha_final[semi, None], 0.25)
        unmixed = (rgb_f[semi] - (1.0 - a) * bg_color[None, :]) / a
        out_rgb[semi] = np.clip(unmixed, 0, 255)

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
    rgba[..., 3] = np.clip(alpha_final * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, mode="RGBA")


def process_sheet(input_path: Path, output_dir: Path, bg_mode: str, expected: int = 5) -> list[Path]:
    im = Image.open(input_path).convert("RGB")
    rgb = np.array(im)
    bg_color = _estimate_border_color(rgb)

    if bg_mode == "white":
        hard_tol = 42.0
        soft_band = 36.0
    else:
        # Chroma blue/colored backdrop for pale ivory stones.
        hard_tol = 78.0
        soft_band = 48.0

    bg_mask = _flood_fill_background(rgb, bg_color, hard_tol)
    fg_mask = ~bg_mask

    # Strip tiny stray specks via connected components.
    comps = _connected_components(fg_mask)
    if len(comps) < expected:
        raise RuntimeError(
            f"{input_path.name}: expected at least {expected} stones, found {len(comps)} "
            f"(bg_color={bg_color.round(1).tolist()})"
        )

    top_comps = comps[:expected]
    # Sort neatly by row then column (top row left-to-right, then bottom row).
    h_img = rgb.shape[0]
    top_comps.sort(key=lambda c: (0 if (c[1] + c[3]) / 2 < h_img * 0.52 else 1, (c[2] + c[4]) / 2))

    output_dir.mkdir(parents=True, exist_ok=True)
    saved: list[Path] = []
    for idx, (_area, y0, x0, y1, x1, coords) in enumerate(top_comps):
        pad = 6
        cy0 = max(0, y0 - pad)
        cx0 = max(0, x0 - pad)
        cy1 = min(rgb.shape[0], y1 + pad)
        cx1 = min(rgb.shape[1], x1 + pad)

        comp_fg = np.zeros((cy1 - cy0, cx1 - cx0), dtype=bool)
        comp_fg[coords[:, 0] - cy0, coords[:, 1] - cx0] = True
        crop_rgb = rgb[cy0:cy1, cx0:cx1]

        stone_rgba = _defringe_and_alpha(crop_rgb, comp_fg, bg_color, soft_band, hard_tol)
        # Tight trim on non-zero alpha.
        bbox = stone_rgba.getbbox()
        if bbox:
            stone_rgba = stone_rgba.crop(bbox)

        # Orient strongly landscape pebbles upright so tall Elder Futhark
        # glyphs always have generous vertical stone surface.
        if stone_rgba.width > stone_rgba.height * 1.25:
            stone_rgba = stone_rgba.transpose(Image.Transpose.ROTATE_90)

        # Normalize into TARGET_W x TARGET_H preserving aspect ratio.
        sw, sh = stone_rgba.size
        max_w = int(TARGET_W * FILL_FRACTION)
        max_h = int(TARGET_H * FILL_FRACTION)
        scale = min(max_w / sw, max_h / sh)
        nw = max(1, int(round(sw * scale)))
        nh = max(1, int(round(sh * scale)))
        resized = stone_rgba.resize((nw, nh), Image.Resampling.LANCZOS)

        canvas = Image.new("RGBA", (TARGET_W, TARGET_H), (0, 0, 0, 0))
        ox = (TARGET_W - nw) // 2
        oy = (TARGET_H - nh) // 2
        canvas.paste(resized, (ox, oy), resized)

        out_path = output_dir / f"stone_{idx}.webp"
        canvas.save(out_path, format="WEBP", quality=92, method=6)
        saved.append(out_path)
        print(f"  saved {out_path} ({nw}x{nh} inside {TARGET_W}x{TARGET_H}, {out_path.stat().st_size // 1024} KB)")

    return saved


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract 5 volumetric rune stone WebP sprites.")
    parser.add_argument("input_sheet", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--bg", choices=("white", "chroma"), default="white")
    parser.add_argument("--count", type=int, default=5)
    args = parser.parse_args()
    process_sheet(args.input_sheet, args.output_dir, args.bg, args.count)


if __name__ == "__main__":
    main()
