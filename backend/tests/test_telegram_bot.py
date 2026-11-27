import hashlib
import hmac
import json
import urllib.parse
from datetime import datetime, timedelta, timezone as dt_timezone
from unittest.mock import patch

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from apps.telegram_bot.models import TelegramCheckInReminder, TelegramSubscriber
from apps.telegram_bot.service import current_lunar_window, dispatch_due_reminders


def _sign_init_data(user: dict, bot_token: str, auth_date: int | None = None) -> str:
    ts = auth_date if auth_date is not None else int(timezone.now().timestamp())
    fields = {
        "auth_date": str(ts),
        "query_id": "AAHdF6IQAAAAAN0XohDhrOrc",
        "user": json.dumps(user, separators=(",", ":")),
    }
    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(fields.items()))
    secret_key = hmac.new(b"WebAppData", bot_token.encode("utf-8"), hashlib.sha256).digest()
    sig = hmac.new(secret_key, data_check_string.encode("utf-8"), hashlib.sha256).hexdigest()
    fields["hash"] = sig
    return urllib.parse.urlencode(fields)


class TelegramBotTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    @override_settings(TELEGRAM_WEBHOOK_SECRET="top-secret-hook")
    def test_webhook_rejects_missing_or_wrong_secret(self):
        resp = self.client.post("/api/v1/telegram/webhook/", {"message": {}}, format="json")
        self.assertEqual(resp.status_code, 403)
        resp2 = self.client.post(
            "/api/v1/telegram/webhook/",
            {"message": {}},
            format="json",
            HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN="wrong",
        )
        self.assertEqual(resp2.status_code, 403)

    @override_settings(
        TELEGRAM_WEBHOOK_SECRET="top-secret-hook",
        TELEGRAM_MINIAPP_URL="https://app.soshallitbe.cyou/",
    )
    def test_webhook_commands_lifecycle(self):
        sent = []

        def fake_send(chat_id, text, *, button_text=None, webapp_url=None):
            sent.append((chat_id, text, button_text, webapp_url))
            return True

        with patch("apps.telegram_bot.service.send_telegram_message", side_effect=fake_send), \
             patch("apps.telegram_bot.api.handle_bot_update", wraps=None):
            # Actually patch default arg by patching service.send_telegram_message via handle_bot_update call
            pass

        with patch("apps.telegram_bot.api.handle_bot_update") as mock_handle:
            from apps.telegram_bot.service import handle_bot_update
            mock_handle.side_effect = lambda u: handle_bot_update(u, sender=fake_send)

            headers = {"HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN": "top-secret-hook"}
            # /start
            r1 = self.client.post(
                "/api/v1/telegram/webhook/",
                {"message": {"chat": {"id": 4242}, "from": {"language_code": "ru"}, "text": "/start"}},
                format="json",
                **headers,
            )
            self.assertEqual(r1.status_code, 200)
            self.assertEqual(r1.json()["action"], "welcome")
            self.assertIn("startapp=table", sent[-1][3])

            # /checkin 7 Карьера
            r2 = self.client.post(
                "/api/v1/telegram/webhook/",
                {"message": {"chat": {"id": 4242}, "from": {"language_code": "ru"}, "text": "/checkin 7 Карьера"}},
                format="json",
                **headers,
            )
            self.assertEqual(r2.status_code, 200)
            self.assertEqual(r2.json()["days"], 7)
            self.assertEqual(TelegramCheckInReminder.objects.filter(subscriber__chat_id=4242).count(), 1)

            # /daily toggle off
            r3 = self.client.post(
                "/api/v1/telegram/webhook/",
                {"message": {"chat": {"id": 4242}, "from": {"language_code": "ru"}, "text": "/daily"}},
                format="json",
                **headers,
            )
            self.assertEqual(r3.json()["action"], "daily_off")

            # /stop
            r4 = self.client.post(
                "/api/v1/telegram/webhook/",
                {"message": {"chat": {"id": 4242}, "from": {"language_code": "ru"}, "text": "/stop"}},
                format="json",
                **headers,
            )
            self.assertEqual(r4.json()["action"], "stopped")
            self.assertFalse(TelegramSubscriber.objects.get(chat_id=4242).active)

    @override_settings(TELEGRAM_BOT_TOKEN="123456:TEST_BOT_TOKEN")
    def test_schedule_checkin_verifies_hmac_init_data(self):
        good_init = _sign_init_data({"id": 777001, "language_code": "en"}, "123456:TEST_BOT_TOKEN")
        r_ok = self.client.post(
            "/api/v1/telegram/checkin/",
            {"initData": good_init, "days": 3, "spreadTitle": "Love Bridge"},
            format="json",
        )
        self.assertEqual(r_ok.status_code, 201)
        self.assertEqual(TelegramCheckInReminder.objects.filter(subscriber__chat_id=777001).count(), 1)

        # Tampered initData rejected with 401
        r_bad = self.client.post(
            "/api/v1/telegram/checkin/",
            {"initData": good_init + "tampered", "days": 3},
            format="json",
        )
        self.assertEqual(r_bad.status_code, 401)

    def test_dispatch_due_reminders_is_idempotent(self):
        # Reference New Moon exact time -> lunar window active
        new_moon_time = datetime(2000, 1, 6, 18, 14, tzinfo=dt_timezone.utc)
        self.assertIsNotNone(current_lunar_window(new_moon_time))

        sub = TelegramSubscriber.objects.create(
            chat_id=9001,
            language_code="en",
            daily_card_enabled=True,
            daily_hour_utc=18,
            lunar_enabled=True,
            active=True,
        )
        TelegramCheckInReminder.objects.create(
            subscriber=sub,
            spread_title="Career Crossroads",
            due_at=new_moon_time - timedelta(minutes=5),
        )

        sent = []
        counts1 = dispatch_due_reminders(
            now=new_moon_time,
            sender=lambda cid, txt, **kw: (sent.append((cid, txt, kw)), True)[1],
        )
        self.assertEqual(counts1, {"checkins": 1, "daily": 1, "lunar": 1})
        self.assertEqual(len(sent), 3)

        # Running a second time in the same hour/day/lunar window sends ZERO duplicates.
        counts2 = dispatch_due_reminders(
            now=new_moon_time + timedelta(minutes=10),
            sender=lambda cid, txt, **kw: (sent.append((cid, txt, kw)), True)[1],
        )
        self.assertEqual(counts2, {"checkins": 0, "daily": 0, "lunar": 0})
        self.assertEqual(len(sent), 3)
