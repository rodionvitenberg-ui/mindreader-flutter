import os
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

from django.contrib.auth.models import User
from django.db import close_old_connections, connection
from django.test import TransactionTestCase
from rest_framework.test import APIClient

from apps.accounts.authentication import issue_token
from apps.accounts.models import Principal
from apps.ai_gateway.models import Capability, Protocol, Provider, Usage
from apps.ai_gateway.routing import generate
from apps.catalog.models import Deck
from apps.core.api import Problem
from apps.entitlements.models import Grant
from apps.payments.models import Order

from .test_payments import SECRET, PaymentTests
from .test_store import deck_fixture


def race(*operations):
    barrier = Barrier(len(operations))

    def concurrently(callback):
        close_old_connections()
        try:
            barrier.wait(timeout=5)
            return callback()
        finally:
            connection.close()

    with ThreadPoolExecutor(len(operations)) as pool:
        return list(pool.map(concurrently, operations))


class ConcurrencyTests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("Row-lock verification requires PostgreSQL.")
        # TransactionTestCase flushes data migrations between tests.
        from apps.oracle.models import Personality

        Personality.objects.get_or_create(slug="default", defaults={"name": "Oracle", "system_prompt": "Oracle"})
        self.owner = Principal.objects.create(
            user=User.objects.create_user("verified"), verified_email="reader@example.test",
        )
        self.token = issue_token(self.owner)[0]

    def client_with_token(self):
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {self.token}")
        return client

    @patch.dict(os.environ, {"AI_ALLOWED_HOSTS": "inference.example.test"})
    @patch("apps.ai_gateway.adapters.request_json", return_value={"choices": [{"message": {"content": "ok"}}]})
    def test_parallel_requests_do_not_overspend_daily_quota(self, send):
        Provider.objects.create(name="one", capability=Capability.ORACLE, protocol=Protocol.OPENAI_CHAT,
                                endpoint="https://inference.example.test/infer", model="model",
                                daily_request_limit=1, concurrency_limit=2, enabled=True, is_paid=False)

        def execute():
            try:
                return generate([])[0]
            except Problem as exc:
                return exc.get_codes()

        self.assertCountEqual(race(execute, execute), ["ok", "provider_quota_exhausted"])
        self.assertEqual(Usage.objects.get().count, 1)
        self.assertEqual(send.call_count, 1)

    def test_simultaneous_confirmation_is_applied_once(self):
        client = self.client_with_token()
        reading = client.post("/api/v1/oracle/sessions/", {
            "system": "tarot", "source": "physical", "positions": [{"position": 0, "role": "base"}],
        }, format="json", HTTP_IDEMPOTENCY_KEY="reading").json()["sessionId"]
        from apps.vision.models import Recognition

        entry = Recognition.objects.create(reading_id=reading, item_id="a", track_id="track", status="recognized",
                                           candidates=[{"cardId": "tarot:1", "orientation": "upright"}])
        data = {"sessionId": reading, "requestId": entry.pk, "position": 0, "action": "confirm"}

        def confirm(key):
            return self.client_with_token().post("/api/v1/vision/confirm/", data, format="json",
                                                HTTP_IDEMPOTENCY_KEY=key).status_code

        self.assertCountEqual(race(lambda: confirm("left"), lambda: confirm("right")), [200, 409])
        self.assertEqual(entry.reading.positions.get().card_id, "tarot:1")

    @patch.dict(os.environ, {"PAYMENTS_ENABLE_DEV": "true", "PAYMENTS_DEV_WEBHOOK_SECRET": SECRET})
    def test_parallel_checkout_and_paid_refunded_events(self):
        deck = deck_fixture(price=500)
        Deck.objects.filter(pk=deck.pk).update(published=True)

        def checkout():
            return self.client_with_token().post("/api/v1/payments/checkout/", {
                "deckId": deck.pk, "provider": "dev",
            }, format="json", HTTP_IDEMPOTENCY_KEY="checkout")

        first, second = race(checkout, checkout)
        self.assertIn(first.status_code, {201, 202})
        self.assertEqual(first.json()["id"], second.json()["id"])
        self.assertEqual(Order.objects.count(), 1)
        row = Order.objects.get()
        data = {"id": str(row.pk), "providerReference": row.provider_reference,
                "priceMinor": row.price_minor, "currency": row.currency}
        responses = race(lambda: PaymentTests.event(self, data, "paid"),
                         lambda: PaymentTests.event(self, data, "refunded"))
        self.assertEqual([response.status_code for response in responses], [200, 200])
        row.refresh_from_db()
        self.assertEqual(row.status, "refunded")
        self.assertFalse(Grant.objects.filter(order=row, revoked_at__isnull=True).exists())
