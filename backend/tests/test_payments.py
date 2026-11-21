import hashlib
import hmac
import json
import os
import time
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from apps.accounts.authentication import issue_token
from apps.accounts.models import Principal
from apps.catalog.models import Deck
from apps.entitlements.models import Grant
from apps.payments.models import Event, Order

from .test_readings import guest
from .test_store import deck_fixture

SECRET = "payments-test-only-123456789abcdef"


@patch.dict(os.environ, {"PAYMENTS_ENABLE_DEV": "true", "PAYMENTS_DEV_WEBHOOK_SECRET": SECRET})
class PaymentTests(TestCase):
    def setUp(self):
        self.account = Principal.objects.create(
            user=User.objects.create_user("reader"), verified_email="reader@example.test",
        )
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_token(self.account)[0]}")
        self.deck = deck_fixture(price=499)
        Deck.objects.filter(pk=self.deck.pk).update(published=True)

    def checkout(self, key="key"):
        return self.client.post("/api/v1/payments/checkout/", {"deckId": self.deck.pk, "provider": "dev"},
                                format="json", HTTP_IDEMPOTENCY_KEY=key)

    def event(self, order, status, event_id=None, *, bad=False, changes=None):
        data = {"orderId": order["id"], "reference": order["providerReference"], "status": status,
                "eventId": event_id or status, "priceMinor": order["priceMinor"], "currency": order["currency"],
                **(changes or {})}
        body = json.dumps(data).encode()
        stamp = str(int(time.time()))
        signature = hmac.new(SECRET.encode(), stamp.encode() + b"." + body, hashlib.sha256).hexdigest()
        return APIClient().post("/api/v1/payments/webhooks/dev/", body, content_type="application/json",
                                HTTP_X_TAROT_WEBHOOK_TIMESTAMP=stamp,
                                HTTP_X_TAROT_WEBHOOK_SIGNATURE="0" * 64 if bad else signature)

    def test_verified_checkout_signed_payment_and_refund(self):
        self.assertEqual(guest().post("/api/v1/payments/checkout/",
                                      {"deckId": self.deck.id, "provider": "dev"}).status_code, 403)
        first = self.checkout()
        self.assertEqual(first.status_code, 201, first.data)
        order = first.json()
        self.assertEqual(self.checkout().json(), order)
        self.assertEqual(Order.objects.count(), 1)
        prefix = f"/api/v1/payments/orders/{order['id']}/"
        self.assertEqual(guest().get(prefix).status_code, 404)
        self.assertEqual(self.event(order, "paid", bad=True).status_code, 401)
        self.assertEqual(self.event(order, "paid", changes={"priceMinor": 1}).status_code, 400)
        self.assertEqual(Grant.objects.count(), 0)
        self.assertEqual(self.event(order, "paid").status_code, 200)
        self.assertEqual(self.event(order, "paid").status_code, 200)
        self.assertEqual(Grant.objects.count(), 1)
        self.assertEqual(Event.objects.count(), 1)
        Grant.objects.create(owner=self.account, deck=self.deck, source=Grant.Source.PROMOTION)
        self.assertEqual(self.event(order, "refunded").status_code, 200)
        self.assertEqual(self.client.get(prefix).json()["status"], "refunded")
        self.assertEqual(list(Grant.objects.filter(revoked_at__isnull=True).values_list("source", flat=True)), ["promotion"])

    def test_refund_before_payment_is_terminal(self):
        order = self.checkout().json()
        self.assertEqual(self.event(order, "refunded").status_code, 200)
        self.assertFalse(self.event(order, "paid").json()["applied"])
        self.assertEqual(Grant.objects.count(), 0)
        self.assertEqual(Order.objects.get().status, "refunded")

    @override_settings(PRODUCTION=True, SECURE_SSL_REDIRECT=False)
    def test_development_provider_cannot_be_enabled_in_production(self):
        self.assertEqual(self.checkout().status_code, 503)
        self.assertEqual(Order.objects.count(), 0)

    def test_guest_or_verified_reader_cannot_post_grants(self):
        self.assertEqual(self.client.post("/api/v1/store/library/", {"deck": self.deck.id}).status_code, 405)
        self.assertEqual(Grant.objects.count(), 0)
