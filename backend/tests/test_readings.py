import io
import json
from pathlib import Path
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image
from rest_framework.test import APIClient

from apps.core.cards import CARDS
from apps.oracle.models import Message, Position

SYNTHESIS = {"narrative": "Story", "elementalAlchemy": "Elements", "verdict": "Consider it", "followUp": "Why?"}


def guest():
    client = APIClient()
    token = client.post("/api/v1/auth/guest/").json()["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return client


def jpeg():
    output = io.BytesIO()
    Image.new("RGB", (64, 64)).save(output, "JPEG")
    return SimpleUploadedFile("card.jpg", output.getvalue(), content_type="image/jpeg")


class ReadingTests(TestCase):
    def setUp(self):
        self.client = guest()

    def post(self, url, payload=None, key="one", format="json"):
        return self.client.post(url, payload, format=format, HTTP_IDEMPOTENCY_KEY=key)

    def reading(self, **kwargs):
        fields = {"positions": [{"position": 0, "role": "Question", "note": "note"}],
                  "system": "tarot", **kwargs}
        result = self.post("/api/v1/oracle/sessions/", fields)
        self.assertEqual(result.status_code, 201, result.data)
        return result.json()["sessionId"]

    @patch("apps.oracle.service.generate")
    def test_custom_reading_context_followup_clarifier_and_owner(self, generate):
        prefix = f"/api/v1/oracle/sessions/{self.reading(subject='other', selfContext='PRIVATE-OWNER',
                     otherContext='friend', spreadId='custom', positions=[
                         {'position': i, 'role': f'Question {i}'} for i in range(12)
                     ])}/"
        self.assertEqual(self.post(prefix + "synthesize/").status_code, 409)
        for i in range(12):
            result = self.post(prefix + "cards/", {"position": i, "cardId": f"tarot:{i}", "orientation": "upright"}, key=str(i))
            self.assertEqual(result.status_code, 200, result.data)
        generate.return_value = (json.dumps(SYNTHESIS), "test")
        self.assertEqual(self.post(prefix + "synthesize/").json(), SYNTHESIS)
        self.assertEqual(self.post(prefix + "synthesize/").json(), SYNTHESIS)
        self.assertNotIn("PRIVATE-OWNER", str(generate.call_args))
        self.assertIn("friend", str(generate.call_args))
        generate.return_value = ("Follow-up", "test")
        self.assertEqual(self.post(prefix + "messages/", {"text": "What now?"}).status_code, 200)
        self.assertEqual(self.post(prefix + "messages/", {"text": "What now?"}).status_code, 200)
        self.assertEqual(self.post(prefix + "messages/", {"text": "Different"}).status_code, 409)
        self.assertEqual(Message.objects.count(), 2)
        self.assertEqual(self.post(prefix + "cards/", {"position": 12, "cardId": "tarot:12",
                         "orientation": "reversed", "clarifier": True}, key="clarifier").status_code, 200)
        self.assertEqual(self.post(prefix + "clarifiers/12/", {"text": "Why?"}).status_code, 200)
        self.assertIn("What now?", str(generate.call_args))
        self.assertEqual(generate.call_count, 3)
        self.assertEqual(len(self.client.get(prefix).json()["positions"]), 13)
        self.assertEqual(guest().get(prefix).status_code, 404)
        self.assertEqual(self.client.delete(prefix).status_code, 204)
        self.assertEqual(Message.objects.count(), 0)

    def test_astral_and_live_payload_contract(self):
        result = self.post("/api/v1/oracle/sessions/", {
            "kind": "synastryReading", "astralContext": {"schemaVersion": 1, "summary": "A and B"},
        })
        self.assertEqual(result.status_code, 201, result.data)
        self.assertEqual(result.json()["positions"], [])
        fixture = json.loads((Path(__file__).parent / "fixtures/flutter_contract.json").read_text())
        wire = fixture["oraclePayload"]["cards"][0]["cardId"]
        self.assertEqual(wire, f"lenormand:{fixture['legacyCard']['cardId']}")
        self.assertEqual(CARDS[wire]["name"], "Rider")
        self.assertFalse(CARDS[wire]["reversible"])

    @patch("apps.vision.api.route_vision")
    def test_recognition_correction_batch_and_duplicate_track(self, route):
        reading = self.reading(source="physical", mode="guidedSpread", positions=[
            {"position": 0, "role": "First"}, {"position": 1, "role": "Second"},
        ])
        route.side_effect = lambda inputs, **kw: ({
            item["itemId"]: {"status": "recognized", "candidates": [{
                "cardId": "tarot:1", "orientation": "upright", "score": {"type": "similarity", "value": 0.87},
            }]} for item in inputs
        }, "test")
        data = {"sessionId": reading, "items": json.dumps([{"itemId": "a", "trackId": "first"}, {"itemId": "b"}]),
                "images": [jpeg(), jpeg()]}
        result = self.post("/api/v1/vision/recognize-batch/", data, format="multipart")
        self.assertEqual(result.status_code, 200, result.data)
        hit = result.json()["results"][0]
        self.assertEqual(hit["candidates"][0]["score"]["type"], "similarity")
        self.assertTrue(hit["requiresConfirmation"])
        self.assertEqual(Position.objects.exclude(card_id="").count(), 0)
        self.assertEqual(guest().get(f"/api/v1/vision/results/{hit['requestId']}/").status_code, 404)
        confirm = {"sessionId": reading, "requestId": hit["requestId"], "action": "correct", "position": 0,
                   "cardId": "tarot:2", "orientation": "reversed"}
        self.assertEqual(self.post("/api/v1/vision/confirm/", confirm).json()["position"]["card"]["cardId"], "tarot:2")
        self.assertEqual(self.post("/api/v1/vision/confirm/", confirm).status_code, 200)
        self.assertEqual(self.post("/api/v1/vision/confirm/", confirm, key="new").status_code, 409)
        again = self.post("/api/v1/vision/recognize/", {"sessionId": reading, "images": [jpeg()],
                          "items": '[{"itemId":"c","trackId":"first"}]'}, key="new", format="multipart")
        duplicate = {"sessionId": reading, "requestId": again.json()["results"][0]["requestId"],
                     "action": "confirm", "position": 1}
        self.assertEqual(self.post("/api/v1/vision/confirm/", duplicate, key="duplicate").status_code, 409)
        self.assertEqual(Position.objects.exclude(card_id="").count(), 1)

    def test_invalid_image_unavailable_provider_and_manual_confirmation(self):
        reading = self.reading(source="physical")
        fields = {"sessionId": reading, "items": '[{"itemId":"a"}]'}
        bad = SimpleUploadedFile("card.jpg", b"not an image", content_type="image/jpeg")
        self.assertEqual(self.post("/api/v1/vision/recognize/", {**fields, "images": [bad]},
                                  format="multipart").status_code, 400)
        response = self.post("/api/v1/vision/recognize/", {**fields, "images": [jpeg()]}, format="multipart")
        self.assertEqual(response.json()["results"][0]["status"], "unavailable")
        self.assertEqual(response.json()["error"], "provider_unavailable")
        response = self.post("/api/v1/vision/confirm/", {"sessionId": reading, "action": "manual",
                            "cardId": "tarot:0", "orientation": "upright", "position": 0})
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.json()["position"]["card"]["source"], "physical")


    def test_oversized_upload_and_early_context_switch(self):
        reading = self.reading(source="physical", selfContext="private biography")
        prefix = f"/api/v1/oracle/sessions/{reading}/"
        result = self.client.patch(prefix, {"subject": "other", "question": "A new question"}, format="json")
        self.assertEqual(result.json()["subjectContext"], "")
        self.assertEqual(result.json()["question"], "A new question")
        large = SimpleUploadedFile("oversized.jpg", bytes(4 * 1024 * 1024 + 1), content_type="image/jpeg")
        fields = {"sessionId": reading, "items": '[{"itemId":"a"}]', "images": [large]}
        response = self.post("/api/v1/vision/recognize/", fields, format="multipart")
        self.assertEqual(response.status_code, 413)


    def test_clarifier_flag_cannot_bypass_required_physical_confirmation(self):
        reading = self.reading(source="physical")
        prefix = f"/api/v1/oracle/sessions/{reading}/"
        data = {"position": 0, "cardId": "tarot:1", "orientation": "upright", "clarifier": True}
        self.assertEqual(self.post(prefix + "cards/", data).json()["code"], "position_kind_conflict")
        data["clarifier"] = False
        self.assertEqual(self.post(prefix + "cards/", data).json()["code"], "physical_confirmation_required")
        self.assertFalse(Position.objects.exclude(card_id="").exists())
