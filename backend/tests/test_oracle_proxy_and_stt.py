import io
import json
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from apps.accounts.models import Principal


class _FakeUrlopenResponse:
    def __init__(self, payload: dict):
        self._raw = json.dumps(payload).encode("utf-8")

    def read(self):
        return self._raw

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class OracleProxyAndSttTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        guest = self.client.post("/api/v1/auth/guest/").json()
        self.principal_id = guest["id"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {guest['token']}")

    def test_unauthenticated_rejected(self):
        anon = APIClient()
        self.assertEqual(anon.post("/api/v1/oracle/complete/", {"prompt": "hi"}, format="json").status_code, 401)
        self.assertEqual(anon.get("/api/v1/oracle/quota/").status_code, 401)

    @override_settings(
        ORACLE_LLM_URL="https://example.invalid/v1/chat/completions",
        ORACLE_LLM_API_KEY="server-secret-key",
        ORACLE_LLM_MODEL="gemini-2.5-flash",
        ORACLE_FREE_DAILY_LIMIT=2,
        ORACLE_PRO_DAILY_LIMIT=100,
    )
    def test_complete_proxies_llm_and_enforces_free_vs_pro_quota(self):
        fake_resp = {"choices": [{"message": {"content": "Grounded reflective synthesis."}}]}
        with patch("apps.oracle.proxy_service.urllib.request.urlopen", return_value=_FakeUrlopenResponse(fake_resp)) as mock_open:
            r1 = self.client.post("/api/v1/oracle/complete/", {"prompt": "Read The Star", "kind": "synthesis"}, format="json")
            self.assertEqual(r1.status_code, 200)
            body1 = r1.json()
            self.assertEqual(body1["text"], "Grounded reflective synthesis.")
            self.assertEqual(body1["quota"]["used"], 1)
            self.assertEqual(body1["quota"]["remaining"], 1)
            self.assertEqual(body1["quota"]["limit"], 2)
            # Confirm secret key went out on server side.
            req = mock_open.call_args[0][0]
            self.assertEqual(req.get_header("Authorization"), "Bearer server-secret-key")

            r2 = self.client.post("/api/v1/oracle/complete/", {"prompt": "Follow up"}, format="json")
            self.assertEqual(r2.status_code, 200)
            self.assertEqual(r2.json()["quota"]["remaining"], 0)

            # Third request hits server-enforced quota_exceeded (429).
            r3 = self.client.post("/api/v1/oracle/complete/", {"prompt": "One more"}, format="json")
            self.assertEqual(r3.status_code, 429)
            body3 = r3.json()
            self.assertEqual(body3["code"], "quota_exceeded")
            self.assertEqual(body3["remaining"], 0)
            self.assertEqual(body3["limit"], 2)
            self.assertIn("resetAt", body3)

            # Upgrading to PRO immediately lifts the server quota.
            Principal.objects.filter(pk=self.principal_id).update(is_pro=True, pro_plan=Principal.ProPlan.EARLY_MONTHLY)
            r4 = self.client.post("/api/v1/oracle/complete/", {"prompt": "PRO follow up"}, format="json")
            self.assertEqual(r4.status_code, 200)
            self.assertEqual(r4.json()["quota"]["limit"], 100)

    @override_settings(ORACLE_LLM_API_KEY="")
    def test_complete_returns_503_when_unconfigured(self):
        resp = self.client.post("/api/v1/oracle/complete/", {"prompt": "Hello"}, format="json")
        self.assertEqual(resp.status_code, 503)
        self.assertEqual(resp.json()["code"], "oracle_unconfigured")

    @override_settings(
        STT_API_URL="https://whisper.example.invalid/v1/audio/transcriptions",
        STT_API_KEY="whisper-secret",
        STT_API_MODEL="whisper-large-v3",
        STT_FREE_DAILY_LIMIT=2,
    )
    def test_transcribe_whisper_proxy_and_quota(self):
        fake_resp = {"text": ' "Что мне поможет сегодня?" '}
        audio = SimpleUploadedFile("voice.ogg", b"OggS\x00\x02fake-audio-bytes", content_type="audio/ogg")
        with patch("apps.oracle.proxy_service.urllib.request.urlopen", return_value=_FakeUrlopenResponse(fake_resp)):
            r1 = self.client.post("/api/v1/oracle/transcribe/", {"file": audio, "mimeType": "audio/ogg"}, format="multipart")
            self.assertEqual(r1.status_code, 200)
            body = r1.json()
            self.assertEqual(body["text"], "Что мне поможет сегодня?")
            self.assertEqual(body["provider"], "whisper:whisper-large-v3")
            self.assertEqual(body["quota"]["used"], 1)

        # Quota overview reflects server counts.
        overview = self.client.get("/api/v1/oracle/quota/").json()
        self.assertFalse(overview["isPro"])
        self.assertEqual(overview["stt"]["used"], 1)
        self.assertEqual(overview["stt"]["limit"], 2)

    @override_settings(
        STT_API_URL="",
        STT_API_KEY="",
        ORACLE_LLM_URL="https://api.deepseek.com/v1/chat/completions",
        ORACLE_LLM_API_KEY="ds-unified-key",
    )
    def test_transcribe_auto_routes_to_deepseek_asr_from_single_key(self):
        fake_resp = {"request_id": "req-1", "text": "Какой шаг сделать сегодня?", "duration_ms": 1200}
        audio = SimpleUploadedFile("voice.ogg", b"OggS\x00\x02opus-bytes", content_type="audio/ogg")
        with patch("apps.oracle.proxy_service.urllib.request.urlopen", return_value=_FakeUrlopenResponse(fake_resp)) as mock_open:
            resp = self.client.post("/api/v1/oracle/transcribe/", {"file": audio, "mimeType": "audio/ogg"}, format="multipart")
            self.assertEqual(resp.status_code, 200)
            body = resp.json()
            self.assertEqual(body["text"], "Какой шаг сделать сегодня?")
            self.assertEqual(body["provider"], "deepseek:asr")
            req = mock_open.call_args[0][0]
            self.assertEqual(req.full_url, "https://api.deepseek.com/v1/tools/asr")
            self.assertEqual(req.get_header("Authorization"), "Bearer ds-unified-key")

    @override_settings(STT_MAX_UPLOAD_BYTES=16)
    def test_transcribe_rejects_oversized_audio(self):
        big = SimpleUploadedFile("big.m4a", b"x" * 32, content_type="audio/mp4")
        resp = self.client.post("/api/v1/oracle/transcribe/", {"file": big}, format="multipart")
        self.assertEqual(resp.status_code, 413)
        self.assertEqual(resp.json()["code"], "request_too_large")
