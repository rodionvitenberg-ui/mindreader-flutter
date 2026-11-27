"""OpenAI-compatible Cloud VLM tarot recognition (DeepSeek Vision / Gemini / GPT-4o-mini / Qwen-VL)."""

from __future__ import annotations

import base64
import json
import re
import urllib.error
import urllib.request
from dataclasses import dataclass

from django.conf import settings

from apps.core.api import Problem

from .card_cropper import CroppedCard, extract_spread_crops
from .card_matcher import canonical_tarot_prompt_catalog, match_tarot_card

_JSON_ARRAY_RE = re.compile(r"\[[\s\S]*\]")


@dataclass(frozen=True)
class RecognizedSpreadCard:
    index: int
    card_id: str
    deck_index: int
    name: str
    orientation: str   # "upright" | "reversed"
    confidence: float
    center_norm: list[float] | None
    is_landscape: bool


@dataclass(frozen=True)
class SpreadScanOutput:
    mode: str
    strategy: str      # "crops" | "full_image"
    provider: str
    crop_count: int
    cards: list[RecognizedSpreadCard]
    warnings: list[str]


def _build_crops_content(crops: list[CroppedCard]) -> list[dict]:
    catalog = canonical_tarot_prompt_catalog()
    header = (
        f"You are an expert Tarot card visual recognizer. You are given {len(crops)} "
        "perspective-corrected Tarot card crops already ordered in spread reading order "
        "(1 to N, left-to-right, top-to-bottom). Each crop preserves its original orientation "
        "in the photograph (top of the crop = top of the card on the table). "
        "Cards may come from Rider-Waite, Marseille, Visconti-Sforza, Thoth, or modern indie decks.\n\n"
        "For EACH crop (1..N), identify:\n"
        "- index: integer matching the crop number (1..N)\n"
        "- cardId: exact canonical ID from this catalog (or null if the crop is NOT a Tarot card / face-down back)\n"
        "- name: canonical English card name\n"
        '- orientation: "upright" if artwork/title is right-side-up, "reversed" if upside-down (180 degrees)\n'
        "- confidence: float from 0.0 to 1.0\n\n"
        f"Canonical catalog:\n{catalog}\n\n"
        "Reply ONLY with a valid JSON array sorted by index (no markdown, no explanation): "
        '[{"index": 1, "cardId": "tarot:17", "name": "The Star", "orientation": "upright", "confidence": 0.96}]'
    )
    content: list[dict] = [{"type": "text", "text": header}]
    for crop in crops:
        note = f"Card #{crop.index}"
        if crop.is_landscape:
            note += " (placed sideways / 90 deg crossing card)"
        content.append({"type": "text", "text": note})
        b64 = base64.b64encode(crop.jpeg_bytes).decode("ascii")
        content.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{b64}"},
        })
    return content


def _build_full_image_content(
    jpeg_bytes: bytes,
    *,
    mode: str,
    expected_count: int | None,
) -> list[dict]:
    catalog = canonical_tarot_prompt_catalog()
    if mode in {"guided_single", "live_oracle"}:
        scope = (
            "Identify the SINGLE primary face-up Tarot card currently in focus in the center/foreground "
            "of this photograph. Return a JSON array with 1 element (or [] if no face-up card is visible)."
        )
    elif expected_count is not None:
        scope = (
            f"Identify the face-up Tarot cards visible in this photo (around {expected_count} cards expected, "
            "but report ONLY cards you actually see). Order them strictly in reading order: "
            "top row to bottom row, and left to right within each row."
        )
    else:
        scope = (
            "Identify EVERY face-up Tarot card visible in this photo. "
            "Order them strictly in reading order: top row to bottom row, and left to right within each row."
        )

    prompt = (
        "You are an expert Tarot card visual recognizer. "
        f"{scope}\n"
        "For each visible face-up card, return:\n"
        "- index: 1-based reading-order integer\n"
        "- cardId: exact canonical ID from the catalog below\n"
        "- name: canonical English card name\n"
        '- orientation: "upright" or "reversed" (upside-down relative to the viewer)\n'
        "- confidence: float from 0.0 to 1.0\n"
        "- isLandscape: boolean (true if the card is rotated ~90 degrees sideways)\n\n"
        f"Canonical catalog:\n{catalog}\n\n"
        "Reply ONLY with a valid JSON array (no markdown, no prose): "
        '[{"index": 1, "cardId": "tarot:0", "name": "The Fool", "orientation": "upright", "confidence": 0.94, "isLandscape": false}]'
    )
    b64 = base64.b64encode(jpeg_bytes).decode("ascii")
    return [
        {"type": "text", "text": prompt},
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
    ]


def _post_vlm_chat(content: list[dict]) -> str:
    url = (settings.VISION_VLM_URL or "").strip()
    api_key = (settings.VISION_VLM_API_KEY or "").strip()
    model = (settings.VISION_VLM_MODEL or "deepseek-flash").strip()

    if not url or not api_key:
        raise Problem(
            "vision_vlm_unconfigured",
            503,
            "Cloud Vision VLM API key is not configured on the server.",
        )

    payload = json.dumps({
        "model": model,
        "temperature": 0.0,
        "max_tokens": 1400,
        "stream": False,
        "messages": [{"role": "user", "content": content}],
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": f"Bearer {api_key}",
            "User-Agent": "TarotTree-Backend/1.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=settings.VISION_VLM_TIMEOUT) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        status = exc.code
        if status == 429:
            raise Problem("provider_quota_exhausted", 429, "Vision AI rate limit reached. Try again shortly.") from None
        if status in {401, 403}:
            raise Problem("vision_vlm_auth_error", 502, "Vision AI provider rejected the API key.") from None
        raise Problem("provider_error", 502, f"Vision AI provider error (HTTP {status}).") from None
    except (OSError, ValueError) as exc:
        raise Problem("provider_timeout", 504, "Vision AI provider could not be reached in time.") from exc

    try:
        text = body["choices"][0]["message"]["content"]
    except (TypeError, IndexError, KeyError):
        raise Problem("provider_invalid_response", 502, "Unexpected response from Vision AI provider.") from None
    if not isinstance(text, str):
        raise Problem("provider_invalid_response", 502, "Empty response from Vision AI provider.")
    return text


def _parse_vlm_entries(
    raw_text: str,
    crops_by_index: dict[int, CroppedCard],
) -> tuple[list[RecognizedSpreadCard], list[str]]:
    match = _JSON_ARRAY_RE.search(raw_text)
    if not match:
        raise Problem("provider_invalid_response", 502, "Vision AI did not return a JSON array.")
    try:
        parsed = json.loads(match.group(0))
    except ValueError:
        raise Problem("provider_invalid_response", 502, "Vision AI returned malformed JSON.") from None
    if not isinstance(parsed, list):
        raise Problem("provider_invalid_response", 502, "Vision AI response was not a list.")

    cards: list[RecognizedSpreadCard] = []
    warnings: list[str] = []
    for pos, item in enumerate(parsed, start=1):
        if not isinstance(item, dict):
            continue
        raw_index = item.get("index")
        idx = int(raw_index) if isinstance(raw_index, int) and raw_index > 0 else pos
        matched = match_tarot_card(
            card_id=item.get("cardId") if isinstance(item.get("cardId"), str) else None,
            name=item.get("name") if isinstance(item.get("name"), str) else None,
        )
        if matched is None:
            warnings.append(f"card_{idx}_unrecognized")
            continue

        raw_orient = str(item.get("orientation") or "").strip().lower()
        if raw_orient in {"reversed", "inverted", "upside_down", "upside-down"}:
            orientation = "reversed"
        elif raw_orient in {"upright", "normal"}:
            orientation = "upright"
        else:
            orientation = "reversed" if item.get("reversed") is True else "upright"

        raw_conf = item.get("confidence")
        try:
            conf = max(0.0, min(1.0, float(raw_conf))) if raw_conf is not None else 0.85
        except (TypeError, ValueError):
            conf = 0.85

        crop = crops_by_index.get(idx)
        center = list(crop.center_norm) if crop is not None else None
        is_landscape = (
            crop.is_landscape
            if crop is not None
            else bool(item.get("isLandscape") is True)
        )
        cards.append(
            RecognizedSpreadCard(
                index=idx,
                card_id=matched.card_id,
                deck_index=matched.deck_index,
                name=matched.name,
                orientation=orientation,
                confidence=round(conf, 3),
                center_norm=center,
                is_landscape=is_landscape,
            )
        )

    cards.sort(key=lambda c: c.index)
    return cards, warnings


def recognize_spread_with_vlm(
    jpeg_bytes: bytes,
    *,
    mode: str = "quick_scan",
    expected_count: int | None = None,
    crop_extractor=None,
    vlm_caller=None,
) -> SpreadScanOutput:
    """Runs enginetaro quad detection/cropping -> Cloud VLM recognition (with automatic full-image fallback)."""
    single = mode in {"guided_single", "live_oracle"}
    extractor = crop_extractor or extract_spread_crops
    caller = vlm_caller or _post_vlm_chat

    crops = extractor(
        jpeg_bytes,
        single_card=single,
        max_cards=1 if single else settings.VISION_MAX_CARDS_PER_SCAN,
    )
    if crops:
        strategy = "crops"
        content = _build_crops_content(crops)
        crops_by_index = {c.index: c for c in crops}
    else:
        strategy = "full_image"
        content = _build_full_image_content(
            jpeg_bytes,
            mode=mode,
            expected_count=expected_count,
        )
        crops_by_index = {}

    raw_text = caller(content)
    cards, warnings = _parse_vlm_entries(raw_text, crops_by_index)
    if single and len(cards) > 1:
        cards = [cards[0]]

    return SpreadScanOutput(
        mode=mode,
        strategy=strategy,
        provider=(settings.VISION_VLM_MODEL or "deepseek-flash").strip(),
        crop_count=len(crops),
        cards=cards,
        warnings=warnings,
    )
