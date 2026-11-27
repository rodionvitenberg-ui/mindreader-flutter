#!/usr/bin/env python3
"""Vectorize icons/elements/{fire,water,air,earth}.png into clean,
transparent, optically size-matched SVGs (assets/icons/elements/*.svg)
and a synchronous Flutter CustomPainter widget
(lib/design_system/components/element_icon.dart).
"""

from __future__ import annotations

import math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "icons" / "elements"
SVG_OUT = ROOT / "assets" / "icons" / "elements"
DART_OUT = ROOT / "lib" / "design_system" / "components" / "element_icon.dart"


def marching_squares_contours(mask: np.ndarray) -> list[list[tuple[float, float]]]:
    """Extract closed polygon contours from a boolean mask using marching squares."""
    h, w = mask.shape
    padded = np.zeros((h + 2, w + 2), dtype=np.uint8)
    padded[1 : h + 1, 1 : w + 1] = mask.astype(np.uint8)

    # Directed edge table for marching squares (top=0, right=1, bottom=2, left=3)
    # Using midpoint coordinates doubled (integers) for exact vertex hashing.
    edge_table: dict[int, list[tuple[int, int]]] = {
        1: [(3, 2)],
        2: [(2, 1)],
        3: [(3, 1)],
        4: [(1, 0)],
        5: [(3, 0), (1, 2)],
        6: [(2, 0)],
        7: [(3, 0)],
        8: [(0, 3)],
        9: [(0, 2)],
        10: [(0, 1), (2, 3)],
        11: [(0, 1)],
        12: [(1, 3)],
        13: [(1, 2)],
        14: [(2, 3)],
    }

    def edge_pt(x: int, y: int, e: int) -> tuple[int, int]:
        if e == 0:
            return (2 * x + 1, 2 * y)
        if e == 1:
            return (2 * x + 2, 2 * y + 1)
        if e == 2:
            return (2 * x + 1, 2 * y + 2)
        return (2 * x, 2 * y + 1)

    tl = padded[:-1, :-1]
    tr = padded[:-1, 1:]
    br = padded[1:, 1:]
    bl = padded[1:, :-1]
    cases = (tl << 3) | (tr << 2) | (br << 1) | bl

    ys, xs = np.where((cases != 0) & (cases != 15))
    adj: dict[tuple[int, int], list[tuple[int, int]]] = {}
    for y, x in zip(ys.tolist(), xs.tolist()):
        c = int(cases[y, x])
        for e0, e1 in edge_table[c]:
            p0 = edge_pt(x, y, e0)
            p1 = edge_pt(x, y, e1)
            adj.setdefault(p0, []).append(p1)

    contours: list[list[tuple[float, float]]] = []
    while adj:
        start = next(iter(adj))
        pts: list[tuple[int, int]] = [start]
        cur = start
        while True:
            nxts = adj.get(cur)
            if not nxts:
                break
            nxt = nxts.pop()
            if not nxts:
                del adj[cur]
            if nxt == start:
                break
            pts.append(nxt)
            cur = nxt
        if len(pts) >= 4:
            # Convert doubled coords back to original mask coordinates
            contours.append([(px / 2.0 - 1.0, py / 2.0 - 1.0) for px, py in pts])
    return contours


def polygon_area(pts: list[tuple[float, float]]) -> float:
    n = len(pts)
    s = 0.0
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return 0.5 * s


def chaikin_closed(
    pts: list[tuple[float, float]], iterations: int = 2
) -> list[tuple[float, float]]:
    cur = pts
    for _ in range(iterations):
        nxt: list[tuple[float, float]] = []
        n = len(cur)
        for i in range(n):
            x0, y0 = cur[i]
            x1, y1 = cur[(i + 1) % n]
            nxt.append((0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1))
            nxt.append((0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1))
        cur = nxt
    return cur


def rdp_open(
    pts: list[tuple[float, float]], eps: float
) -> list[tuple[float, float]]:
    if len(pts) <= 2:
        return pts
    x1, y1 = pts[0]
    x2, y2 = pts[-1]
    dx = x2 - x1
    dy = y2 - y1
    denom = math.hypot(dx, dy)
    max_d = -1.0
    idx = 0
    for i in range(1, len(pts) - 1):
        px, py = pts[i]
        if denom == 0:
            d = math.hypot(px - x1, py - y1)
        else:
            d = abs(dy * px - dx * py + x2 * y1 - y2 * x1) / denom
        if d > max_d:
            max_d = d
            idx = i
    if max_d > eps:
        left = rdp_open(pts[: idx + 1], eps)
        right = rdp_open(pts[idx:], eps)
        return left[:-1] + right
    return [pts[0], pts[-1]]


def rdp_closed(
    pts: list[tuple[float, float]], eps: float
) -> list[tuple[float, float]]:
    # Split at the two farthest points from the first vertex to preserve sharp tips
    n = len(pts)
    if n <= 4:
        return pts
    p0 = pts[0]
    far = max(range(n), key=lambda i: (pts[i][0] - p0[0]) ** 2 + (pts[i][1] - p0[1]) ** 2)
    p1 = pts[far]
    far2 = max(range(n), key=lambda i: (pts[i][0] - p1[0]) ** 2 + (pts[i][1] - p1[1]) ** 2)
    a, b = sorted((far, far2))
    seg1 = pts[a : b + 1]
    seg2 = pts[b:] + pts[: a + 1]
    s1 = rdp_open(seg1, eps)
    s2 = rdp_open(seg2, eps)
    res = s1[:-1] + s2[:-1]
    return res if len(res) >= 3 else pts[:3]


def corner_angle(
    p_prev: tuple[float, float],
    p_cur: tuple[float, float],
    p_next: tuple[float, float],
) -> float:
    v1x, v1y = p_prev[0] - p_cur[0], p_prev[1] - p_cur[1]
    v2x, v2y = p_next[0] - p_cur[0], p_next[1] - p_cur[1]
    n1 = math.hypot(v1x, v1y)
    n2 = math.hypot(v2x, v2y)
    if n1 == 0 or n2 == 0:
        return math.pi
    cos_a = max(-1.0, min(1.0, (v1x * v2x + v1y * v2y) / (n1 * n2)))
    return math.acos(cos_a)


def contour_to_commands(
    pts: list[tuple[float, float]], smooth: bool
) -> list[tuple]:
    """Convert a closed contour to drawing commands:
    ('M', x, y), ('L', x, y), ('C', c1x, c1y, c2x, c2y, x, y), ('Z',)
    """
    n = len(pts)
    if n < 3:
        return []
    if not smooth:
        cmds: list[tuple] = [("M", pts[0][0], pts[0][1])]
        for x, y in pts[1:]:
            cmds.append(("L", x, y))
        cmds.append(("Z",))
        return cmds

    # Catmull-Rom to cubic Bezier, preserving sharp corners (< 105 deg)
    sharp = [
        corner_angle(pts[(i - 1) % n], pts[i], pts[(i + 1) % n]) < math.radians(105)
        for i in range(n)
    ]
    cmds = [("M", pts[0][0], pts[0][1])]
    for i in range(n):
        p0 = pts[(i - 1) % n]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n]
        if sharp[i] and sharp[(i + 1) % n]:
            cmds.append(("L", p2[0], p2[1]))
            continue
        t1x = 0.0 if sharp[i] else (p2[0] - p0[0]) / 6.0
        t1y = 0.0 if sharp[i] else (p2[1] - p0[1]) / 6.0
        t2x = 0.0 if sharp[(i + 1) % n] else (p3[0] - p1[0]) / 6.0
        t2y = 0.0 if sharp[(i + 1) % n] else (p3[1] - p1[1]) / 6.0
        c1x, c1y = p1[0] + t1x, p1[1] + t1y
        c2x, c2y = p2[0] - t2x, p2[1] - t2y
        cmds.append(("C", c1x, c1y, c2x, c2y, p2[0], p2[1]))
    cmds.append(("Z",))
    return cmds


def fmt(v: float) -> str:
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s == "-0" else s


def cmds_to_svg_d(cmds: list[tuple]) -> str:
    parts: list[str] = []
    for c in cmds:
        op = c[0]
        if op == "M":
            parts.append(f"M{fmt(c[1])} {fmt(c[2])}")
        elif op == "L":
            parts.append(f"L{fmt(c[1])} {fmt(c[2])}")
        elif op == "C":
            parts.append(
                f"C{fmt(c[1])} {fmt(c[2])} {fmt(c[3])} {fmt(c[4])} {fmt(c[5])} {fmt(c[6])}"
            )
        elif op == "Z":
            parts.append("Z")
    return "".join(parts)


def trace_layer(
    mask: np.ndarray,
    bbox: tuple[int, int, int, int],
    target_box: tuple[float, float, float, float],
    *,
    smooth: bool,
    rdp_eps: float,
    min_area: float,
    chaikin_iters: int = 2,
) -> list[tuple]:
    x0, y0, x1, y1 = bbox
    tx, ty, tw, th = target_box
    bw = max(1, x1 - x0)
    bh = max(1, y1 - y0)
    sx = tw / bw
    sy = th / bh

    contours = marching_squares_contours(mask)
    all_cmds: list[tuple] = []
    for raw in contours:
        if abs(polygon_area(raw)) < min_area:
            continue
        pts = [((x - x0) * sx + tx, (y - y0) * sy + ty) for x, y in raw]
        if smooth and chaikin_iters > 0:
            pts = chaikin_closed(pts, chaikin_iters)
        pts = rdp_closed(pts, rdp_eps)
        if len(pts) < 3:
            continue
        all_cmds.extend(contour_to_commands(pts, smooth=smooth))
    return all_cmds


def load_resized(path: Path, max_dim: int = 420) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    scale = max_dim / max(im.size)
    if scale < 1.0:
        im = im.resize(
            (max(1, int(round(im.width * scale))), max(1, int(round(im.height * scale)))),
            Image.Resampling.LANCZOS,
        )
    return np.array(im)


def alpha_bbox(arr: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(arr[:, :, 3] > 128)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def optical_box(
    bbox: tuple[int, int, int, int],
    *,
    target_h: float | None = None,
    target_w: float | None = None,
) -> tuple[float, float, float, float]:
    x0, y0, x1, y1 = bbox
    aspect = (x1 - x0) / max(1, (y1 - y0))
    if target_h is not None:
        h = target_h
        w = h * aspect
    else:
        assert target_w is not None
        w = target_w
        h = w / aspect
    return ((64.0 - w) / 2.0, (64.0 - h) / 2.0, w, h)


def build_fire() -> list[tuple[str, list[tuple]]]:
    arr = load_resized(SRC_DIR / "fire.png", 440)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    bbox = alpha_bbox(arr)
    # Taller narrow flame -> 58px height inside 64x64
    tbox = optical_box(bbox, target_h=58.0)
    layers_spec = [
        ("#D33C3D", a > 128),
        ("#FE884C", (a > 128) & (g > 105)),
        ("#FECE57", (a > 128) & (g > 175)),
    ]
    out = []
    for color, mask in layers_spec:
        cmds = trace_layer(mask, bbox, tbox, smooth=True, rdp_eps=0.42, min_area=40)
        if cmds:
            out.append((color, cmds))
    return out


def build_water() -> list[tuple[str, list[tuple]]]:
    arr = load_resized(SRC_DIR / "water.png", 440)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    bbox = alpha_bbox(arr)
    # Taller teardrop -> 58px height inside 64x64
    tbox = optical_box(bbox, target_h=58.0)
    layers_spec = [
        ("#0885BE", a > 128),
        ("#5694C3", (a > 128) & (r > 58) & (g < 168)),
        ("#11B3D9", (a > 128) & (g > 162)),
        ("#4CBADB", (a > 128) & (r > 58) & (g > 174)),
    ]
    out = []
    for color, mask in layers_spec:
        cmds = trace_layer(mask, bbox, tbox, smooth=True, rdp_eps=0.40, min_area=35)
        if cmds:
            out.append((color, cmds))
    return out


def build_air() -> list[tuple[str, list[tuple]]]:
    arr = load_resized(SRC_DIR / "air.png", 440)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    bbox = alpha_bbox(arr)
    # Circular open swirl -> 55px height so optical weight matches fire & water
    tbox = optical_box(bbox, target_h=55.0)
    layers_spec = [
        ("#56AEFE", a > 128),
        ("#7AC7FD", (a > 128) & (g > 186)),
        ("#98D8FE", (a > 128) & (g > 206)),
    ]
    out = []
    for color, mask in layers_spec:
        cmds = trace_layer(mask, bbox, tbox, smooth=True, rdp_eps=0.38, min_area=30)
        if cmds:
            out.append((color, cmds))
    return out


def build_earth() -> list[tuple[str, list[tuple]]]:
    arr = load_resized(SRC_DIR / "earth.png", 440)
    r, g, b, a = (
        arr[:, :, 0].astype(int),
        arr[:, :, 1].astype(int),
        arr[:, :, 2].astype(int),
        arr[:, :, 3],
    )
    bbox = alpha_bbox(arr)
    # Dense solid faceted crystal -> 58px width (~46.5px height) for equal optical weight
    tbox = optical_box(bbox, target_w=58.0)
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    opaque = a > 128

    # Clean geometric facet masks derived from the actual stone regions
    top_plane = opaque & (r > 175) & (g > 135) & ((r - b) > 12)
    top_bevel = opaque & (r > 214) & (g > 168)
    fissure = (
        opaque
        & (xx > w * 0.48)
        & (yy < h * 0.58)
        & (r < 120)
        & (g < 115)
        & (b < 118)
    )
    deep_violet = opaque & (~top_plane) & (~fissure) & (r < 126) & (b > 95) & ((b - r) >= 6)
    warm_mauve = opaque & (~top_plane) & (~fissure) & (~deep_violet) & (r >= 118) & ((r - b) >= 4)

    layers_spec = [
        ("#7E5D89", opaque, False, 0.55, 60),
        ("#644A74", deep_violet, False, 0.70, 120),
        ("#8E6C7E", warm_mauve, False, 0.70, 120),
        ("#CFA6A3", top_plane, False, 0.55, 80),
        ("#E2B6AE", top_bevel, False, 0.60, 45),
        ("#4E4B4F", fissure, False, 0.35, 10),
    ]
    out = []
    for color, mask, smooth, eps, min_a in layers_spec:
        cmds = trace_layer(
            mask,
            bbox,
            tbox,
            smooth=smooth,
            rdp_eps=eps,
            min_area=min_a,
            chaikin_iters=0,
        )
        if cmds:
            out.append((color, cmds))
    return out


def write_svg(name: str, layers: list[tuple[str, list[tuple]]]) -> None:
    SVG_OUT.mkdir(parents=True, exist_ok=True)
    lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" fill="none">',
    ]
    for color, cmds in layers:
        d = cmds_to_svg_d(cmds)
        lines.append(f'  <path fill="{color}" fill-rule="evenodd" d="{d}"/>')
    lines.append("</svg>")
    (SVG_OUT / f"{name}.svg").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_dart(all_layers: dict[str, list[tuple[str, list[tuple]]]]) -> None:
    lines = [
        "// GENERATED BY tool/gen_element_svgs.py — do not edit by hand.",
        "// Source artwork: icons/elements/{fire,water,air,earth}.png",
        "// Matching standalone SVGs: assets/icons/elements/{fire,water,air,earth}.svg",
        "",
        "import 'package:flutter/material.dart' hide Element;",
        "",
        "import '../../core/models/tarot_card_model.dart';",
        "",
        "/// Vector element emblem rendered from the normalized 64×64 SVG paths of",
        "/// `assets/icons/elements/{fire,water,air,earth}.svg` with transparent",
        "/// background and matched optical sizing across all four elements.",
        "class ElementIcon extends StatelessWidget {",
        "  const ElementIcon(",
        "    this.element, {",
        "    super.key,",
        "    this.size = 16,",
        "    this.semanticLabel,",
        "  });",
        "",
        "  final Element element;",
        "  final double size;",
        "  final String? semanticLabel;",
        "",
        "  @override",
        "  Widget build(BuildContext context) {",
        "    final icon = SizedBox.square(",
        "      dimension: size,",
        "      child: RepaintBoundary(",
        "        child: CustomPaint(",
        "          painter: _ElementIconPainter(element),",
        "        ),",
        "      ),",
        "    );",
        "    if (semanticLabel == null) return ExcludeSemantics(child: icon);",
        "    return Semantics(label: semanticLabel, image: true, child: icon);",
        "  }",
        "}",
        "",
        "class _ElementLayer {",
        "  const _ElementLayer(this.color, this.path);",
        "  final Color color;",
        "  final Path path;",
        "}",
        "",
        "class _ElementIconPainter extends CustomPainter {",
        "  const _ElementIconPainter(this.element);",
        "  final Element element;",
        "",
        "  @override",
        "  void paint(Canvas canvas, Size size) {",
        "    final scale = size.shortestSide / 64.0;",
        "    canvas.save();",
        "    canvas.translate(",
        "      (size.width - 64.0 * scale) / 2.0,",
        "      (size.height - 64.0 * scale) / 2.0,",
        "    );",
        "    canvas.scale(scale, scale);",
        "    final paint = Paint()",
        "      ..style = PaintingStyle.fill",
        "      ..isAntiAlias = true;",
        "    for (final layer in _layersFor(element)) {",
        "      paint.color = layer.color;",
        "      canvas.drawPath(layer.path, paint);",
        "    }",
        "    canvas.restore();",
        "  }",
        "",
        "  @override",
        "  bool shouldRepaint(_ElementIconPainter oldDelegate) =>",
        "      oldDelegate.element != element;",
        "}",
        "",
        "final Map<Element, List<_ElementLayer>> _cache = {};",
        "",
        "List<_ElementLayer> _layersFor(Element element) =>",
        "    _cache.putIfAbsent(element, () => switch (element) {",
        "      Element.fire => _buildFire(),",
        "      Element.water => _buildWater(),",
        "      Element.air => _buildAir(),",
        "      Element.earth => _buildEarth(),",
        "    });",
        "",
    ]

    for name in ("fire", "water", "air", "earth"):
        fn = f"_build{name.capitalize()}"
        lines.append(f"List<_ElementLayer> {fn}() => [")
        for color, cmds in all_layers[name]:
            argb = "0xFF" + color.lstrip("#").upper()
            lines.append(f"  _ElementLayer(")
            lines.append(f"    const Color({argb}),")
            lines.append("    Path()..fillType = PathFillType.evenOdd")
            for c in cmds:
                op = c[0]
                if op == "M":
                    lines.append(f"      ..moveTo({fmt(c[1])}, {fmt(c[2])})")
                elif op == "L":
                    lines.append(f"      ..lineTo({fmt(c[1])}, {fmt(c[2])})")
                elif op == "C":
                    lines.append(
                        f"      ..cubicTo({fmt(c[1])}, {fmt(c[2])}, {fmt(c[3])}, {fmt(c[4])}, {fmt(c[5])}, {fmt(c[6])})"
                    )
                elif op == "Z":
                    lines.append("      ..close()")
            lines.append("    ,")
            lines.append("  ),")
        lines.append("];")
        lines.append("")

    DART_OUT.write_text("\n".join(lines), encoding="utf-8")


def sample_cmds_to_polys(cmds: list[tuple], scale: float) -> list[list[tuple[float, float]]]:
    polys: list[list[tuple[float, float]]] = []
    cur: list[tuple[float, float]] = []
    cx = cy = 0.0
    for c in cmds:
        op = c[0]
        if op == "M":
            if cur:
                polys.append(cur)
            cx, cy = c[1], c[2]
            cur = [(cx * scale, cy * scale)]
        elif op == "L":
            cx, cy = c[1], c[2]
            cur.append((cx * scale, cy * scale))
        elif op == "C":
            x0, y0 = cx, cy
            x1, y1, x2, y2, x3, y3 = c[1:]
            for k in range(1, 13):
                t = k / 12.0
                mt = 1 - t
                px = mt**3 * x0 + 3 * mt**2 * t * x1 + 3 * mt * t**2 * x2 + t**3 * x3
                py = mt**3 * y0 + 3 * mt**2 * t * y1 + 3 * mt * t**2 * y2 + t**3 * y3
                cur.append((px * scale, py * scale))
            cx, cy = x3, y3
        elif op == "Z":
            if len(cur) >= 3:
                polys.append(cur)
            cur = []
    if len(cur) >= 3:
        polys.append(cur)
    return polys


def render_preview(all_layers: dict[str, list[tuple[str, list[tuple]]]], out_path: Path) -> None:
    """Render a side-by-side contact sheet on Obsidian #09090D for visual QA."""
    cell = 160
    pad = 24
    w = pad + 4 * (cell + pad)
    h = pad + cell + 48 + 48 + pad
    img = Image.new("RGBA", (w, h), (9, 9, 13, 255))

    def draw_icon(layers, ox: int, oy: int, size: int) -> None:
        # 2x supersampling for clean antialiasing
        ss = 2
        buf = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
        scale = (size * ss) / 64.0
        for color, cmds in layers:
            rgb = tuple(int(color[i : i + 2], 16) for i in (1, 3, 5))
            polys = sample_cmds_to_polys(cmds, scale)
            # Even-odd fill via XOR mask
            layer_mask = Image.new("1", (size * ss, size * ss), 0)
            for poly in polys:
                sub = Image.new("1", (size * ss, size * ss), 0)
                ImageDraw.Draw(sub).polygon(poly, fill=1)
                a = np.array(layer_mask, dtype=np.uint8)
                b = np.array(sub, dtype=np.uint8)
                layer_mask = Image.fromarray(((a ^ b) * 255).astype(np.uint8)).convert("1")
            fill = Image.new("RGBA", (size * ss, size * ss), (*rgb, 255))
            buf.paste(fill, (0, 0), layer_mask)
        down = buf.resize((size, size), Image.Resampling.LANCZOS)
        img.alpha_composite(down, (ox, oy))

    names = ("fire", "water", "air", "earth")
    for idx, name in enumerate(names):
        x = pad + idx * (cell + pad)
        # Subtle cell frame to verify exact optical alignment
        ImageDraw.Draw(img).rectangle(
            [x, pad, x + cell, pad + cell], outline=(55, 50, 75, 255), width=1
        )
        draw_icon(all_layers[name], x + 16, pad + 16, cell - 32)
        # Small UI sizes (28px and 16px) underneath
        draw_icon(all_layers[name], x + 28, pad + cell + 16, 28)
        draw_icon(all_layers[name], x + 84, pad + cell + 22, 16)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)


def main() -> None:
    all_layers = {
        "fire": build_fire(),
        "water": build_water(),
        "air": build_air(),
        "earth": build_earth(),
    }
    for name, layers in all_layers.items():
        write_svg(name, layers)
        total_cmds = sum(len(cmds) for _, cmds in layers)
        svg_bytes = (SVG_OUT / f"{name}.svg").stat().st_size
        print(f"{name}.svg: {len(layers)} layers, {total_cmds} cmds, {svg_bytes} bytes")
    write_dart(all_layers)
    print(f"Wrote {DART_OUT} ({DART_OUT.stat().st_size} bytes)")
    preview = Path(
        "/home/rodion/.gemini/antigravity-cli/brain/9a1ffbaa-2e7a-47fa-8cb6-fd5c8bf5394d/scratch/elements_preview.png"
    )
    render_preview(all_layers, preview)
    print(f"Preview saved to {preview}")


if __name__ == "__main__":
    main()
