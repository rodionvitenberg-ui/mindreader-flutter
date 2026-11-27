"""Bridge from Django vision uploads to enginetaro's OpenCV card detector & perspective cropper.

Gracefully degrades to an empty crop list (triggering full-image VLM fallback)
if OpenCV/NumPy are not installed in the backend venv or if no crisp card quads
are detected on a cluttered/low-contrast table.
"""

from __future__ import annotations

import logging
import sys
from dataclasses import dataclass
from pathlib import Path

from django.conf import settings

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class CroppedCard:
    index: int                     # 1-based reading-order index
    jpeg_bytes: bytes              # VLM-ready padded JPEG crop (original top edge preserved)
    center_norm: tuple[float, float]
    is_landscape: bool
    score: float


def _load_tarovision():
    """Imports cv2, numpy, and enginetaro.tarovision lazily so Django boots without OpenCV."""
    try:
        import cv2
        import numpy as np
    except ImportError:
        return None

    engine_root = Path(settings.BASE_DIR).parent / "enginetaro"
    if engine_root.is_dir() and str(engine_root) not in sys.path:
        sys.path.insert(0, str(engine_root))

    try:
        from tarovision.detector import (
            DetectParams,
            detect,
            sort_candidates_reading_order,
        )
        from tarovision.extractor import extract_card_for_vlm
    except ImportError:
        logger.debug("enginetaro.tarovision not importable; using full-image VLM fallback.")
        return None

    return cv2, np, DetectParams, detect, sort_candidates_reading_order, extract_card_for_vlm


def extract_spread_crops(
    image_bytes: bytes,
    *,
    single_card: bool = False,
    max_cards: int | None = None,
) -> list[CroppedCard]:
    """Detects card quadrilaterals, sorts them in reading order, and extracts padded VLM JPEGs."""
    loaded = _load_tarovision()
    if loaded is None:
        return []

    cv2, np, DetectParams, detect, sort_reading_order, extract_card_for_vlm = loaded
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if bgr is None:
        return []

    params = DetectParams(
        method="combined",
        use_clahe=True,
        morph_close=True,
        min_area_ratio=0.008,
        max_area_ratio=0.92,
        min_score=0.35,
        dedup_iou=0.55,
    )
    candidates = detect(bgr, params)
    if not candidates:
        return []

    limit = max_cards or settings.VISION_MAX_CARDS_PER_SCAN
    if single_card:
        # Pick the primary card in focus (largest high-confidence quad closest to center).
        def _focus_priority(c):
            cx, cy = c.center_norm
            dist = ((cx - 0.5) ** 2 + (cy - 0.5) ** 2) ** 0.5
            return c.area_ratio * (0.65 + 0.35 * c.score) * max(0.35, 1.0 - dist)

        chosen = [max(candidates, key=_focus_priority)]
    else:
        chosen = sort_reading_order(candidates)[:limit]

    crops: list[CroppedCard] = []
    for idx, cand in enumerate(chosen, start=1):
        try:
            jpg, meta = extract_card_for_vlm(
                bgr,
                cand.corners,
                out_width=416,
                pad_ratio=0.04,
                jpeg_quality=85,
            )
            crops.append(
                CroppedCard(
                    index=idx,
                    jpeg_bytes=jpg,
                    center_norm=cand.center_norm,
                    is_landscape=bool(meta.get("is_landscape", cand.is_landscape)),
                    score=round(float(cand.score), 4),
                )
            )
        except Exception as exc:
            logger.warning("Failed to warp card crop #%s (%s)", idx, type(exc).__name__)
    return crops
