import io
import json
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from PIL import Image
from rest_framework.test import APIClient

from apps.vision.card_cropper import CroppedCard
from apps.vision.card_matcher import match_tarot_card


def _make_jpeg_bytes(w: int = 320, h: int = 240, color=(40, 35, 60)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (w, h), color).save(buf, format="JPEG", quality=85)
    return buf.getvalue()


class VisionScanSpreadTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        guest = self.client.post("/api/v1/auth/guest/").json()
        self.auth_header = {"HTTP_AUTHORIZATION": f"Bearer {guest['token']}"}

    def test_card_matcher_handles_ids_synonyms_and_rejects_unknown(self):
        self.assertEqual(match_tarot_card(card_id="tarot:17").name, "The Star")
        self.assertEqual(match_tarot_card(name="Magician").card_id, "tarot:1")
        self.assertEqual(match_tarot_card(name="XVII - The Star").card_id, "tarot:17")
        self.assertEqual(match_tarot_card(name="Knave of Coins").name, "Page of Pentacles")
        self.assertEqual(match_tarot_card(name="3 of Chalices").name, "Three of Cups")
        # Never silently default unknown text to The Fool!
        self.assertIsNone(match_tarot_card(name="Coffee Mug on Table"))

    def test_scan_spread_with_enginetaro_crops_preserves_reading_order_and_format(self):
        crop_1 = CroppedCard(
            index=1,
            jpeg_bytes=_make_jpeg_bytes(160, 260, (200, 180, 140)),
            center_norm=(0.20, 0.50),
            is_landscape=False,
            score=0.96,
        )
        crop_2 = CroppedCard(
            index=2,
            jpeg_bytes=_make_jpeg_bytes(260, 160, (140, 180, 220)),
            center_norm=(0.80, 0.52),
            is_landscape=True,
            score=0.91,
        )
        captured_payload = {}

        def fake_vlm(content):
            captured_payload["content"] = content
            # Deliberately return out-of-order + synonym name + 1 unrecognized item
            return json.dumps([
                {"index": 2, "name": "3 of Coins", "orientation": "reversed", "confidence": 0.91},
                {"index": 1, "cardId": "tarot:17", "name": "The Star", "orientation": "upright", "confidence": 0.97},
            ])

        upload = SimpleUploadedFile("spread.jpg", _make_jpeg_bytes(640, 480), content_type="image/jpeg")
        with override_settings(VISION_VLM_API_KEY="test-deepseek-key", VISION_VLM_MODEL="deepseek-flash"):
            with patch("apps.vision.vlm_service.extract_spread_crops", return_value=[crop_1, crop_2]):
                with patch("apps.vision.vlm_service._post_vlm_chat", side_effect=fake_vlm):
                    res = self.client.post(
                        "/api/v1/vision/scan-spread/",
                        {"image": upload, "mode": "quick_scan"},
                        format="multipart",
                        **self.auth_header,
                    )
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body["strategy"], "crops")
        self.assertEqual(body["provider"], "deepseek-flash")
        self.assertEqual(body["cropCount"], 2)
        self.assertEqual(len(body["cards"]), 2)

        # Returned sorted strictly by reading order (index 1 then 2), preserving centerNorm & isLandscape.
        self.assertEqual(body["cards"][0]["index"], 1)
        self.assertEqual(body["cards"][0]["cardId"], "tarot:17")
        self.assertEqual(body["cards"][0]["deckIndex"], 17)
        self.assertFalse(body["cards"][0]["reversed"])
        self.assertEqual(body["cards"][0]["centerNorm"], [0.2, 0.5])

        self.assertEqual(body["cards"][1]["index"], 2)
        self.assertEqual(body["cards"][1]["name"], "Three of Pentacles")
        self.assertTrue(body["cards"][1]["reversed"])
        self.assertTrue(body["cards"][1]["isLandscape"])

        # Verify multimodal content sent labeled crops in exact order with data:image/jpeg;base64,...
        content = captured_payload["content"]
        image_blocks = [b for b in content if b["type"] == "image_url"]
        self.assertEqual(len(image_blocks), 2)
        self.assertTrue(image_blocks[0]["image_url"]["url"].startswith("data:image/jpeg;base64,"))
        text_blocks = [b["text"] for b in content if b["type"] == "text"]
        self.assertTrue(any("Card #1" in t for t in text_blocks))
        self.assertTrue(any("Card #2 (placed sideways" in t for t in text_blocks))

    def test_scan_spread_falls_back_to_full_image_when_no_crops_and_caps_guided_single(self):
        fake_resp = json.dumps([
            {"index": 1, "cardId": "tarot:1", "name": "The Magician", "orientation": "upright", "confidence": 0.93},
            {"index": 2, "cardId": "tarot:2", "name": "The High Priestess", "orientation": "upright", "confidence": 0.80},
        ])
        upload = SimpleUploadedFile("single.jpg", _make_jpeg_bytes(640, 480), content_type="image/jpeg")
        with override_settings(VISION_VLM_API_KEY="test-deepseek-key", VISION_VLM_MODEL="deepseek-flash"):
            with patch("apps.vision.vlm_service.extract_spread_crops", return_value=[]):
                with patch("apps.vision.vlm_service._post_vlm_chat", return_value=fake_resp):
                    res = self.client.post(
                        "/api/v1/vision/scan-spread/",
                        {"image": upload, "mode": "guided_single"},
                        format="multipart",
                        **self.auth_header,
                    )
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body["strategy"], "full_image")
        self.assertEqual(body["cropCount"], 0)
        self.assertEqual(len(body["cards"]), 1)
        self.assertEqual(body["cards"][0]["cardId"], "tarot:1")

    def test_scan_spread_returns_503_when_vlm_key_missing(self):
        upload = SimpleUploadedFile("spread.jpg", _make_jpeg_bytes(320, 240), content_type="image/jpeg")
        with override_settings(VISION_VLM_API_KEY=""):
            with patch("apps.vision.vlm_service.extract_spread_crops", return_value=[]):
                res = self.client.post(
                    "/api/v1/vision/scan-spread/",
                    {"image": upload, "mode": "quick_scan"},
                    format="multipart",
                    **self.auth_header,
                )
        self.assertEqual(res.status_code, 503)
        self.assertEqual(res.json()["code"], "vision_vlm_unconfigured")
