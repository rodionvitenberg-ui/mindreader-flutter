import hashlib
import hmac
import json
import os
import re
import time
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass

from django.conf import settings

from apps.core.api import Problem

from .models import Order


@dataclass(frozen=True)
class Checkout:
    reference: str
    url: str = ""


@dataclass(frozen=True)
class VerifiedEvent:
    event_id: str
    order_id: uuid.UUID
    reference: str
    status: str
    price_minor: int
    currency: str


class PaymentProvider(ABC):
    @abstractmethod
    def create_checkout(self, order):
        """Use the order UUID as the provider idempotency key."""

    @abstractmethod
    def verify_webhook(self, body, headers):
        """Authenticate raw bytes before accepting the event."""

    @abstractmethod
    def verify_payment(self, order, event):
        """Verify that the event belongs to an authentic provider payment for this order."""

    def refund(self, order):
        raise Problem("refund_unavailable", 503, "Provider refund initiation is unavailable.")


class DevelopmentPayments(PaymentProvider):
    def __init__(self, secret):
        self.secret = secret.encode()

    def create_checkout(self, order):
        return Checkout(f"dev-{order.pk}")

    def verify_webhook(self, body, headers):
        stamp = headers.get("X-Tarot-Webhook-Timestamp", "")
        signature = headers.get("X-Tarot-Webhook-Signature", "")
        if not re.fullmatch(r"[0-9]{1,12}", stamp) or abs(time.time() - int(stamp)) > 300:
            raise Problem("invalid_webhook_signature", 401, "Webhook signature is invalid or expired.")
        expected = hmac.new(self.secret, stamp.encode() + b"." + body, hashlib.sha256).hexdigest()
        if not re.fullmatch(r"[0-9a-f]{64}", signature) or not hmac.compare_digest(signature, expected):
            raise Problem("invalid_webhook_signature", 401, "Webhook signature is invalid or expired.")
        try:
            data = json.loads(body)
            event = VerifiedEvent(
                data["eventId"], uuid.UUID(data["orderId"]), data["reference"],
                data["status"], data["priceMinor"], data["currency"],
            )
            valid = (
                isinstance(event.event_id, str) and re.fullmatch(r"[A-Za-z0-9_:-]{1,160}", event.event_id)
                and event.reference == f"dev-{event.order_id}"
                and event.status in {Order.Status.PAID, Order.Status.REFUNDED, Order.Status.FAILED, Order.Status.CANCELLED}
                and type(event.price_minor) is int and event.price_minor > 0
                and isinstance(event.currency, str) and re.fullmatch(r"[A-Z]{3}", event.currency)
            )
        except (ValueError, KeyError, TypeError, RecursionError):
            valid = False
        if not valid:
            raise Problem("invalid_payment_event", 400, "Webhook fields are invalid.")
        return event

    def verify_payment(self, order, event):
        return (
            event.reference == f"dev-{order.pk}" and event.price_minor == order.price_minor
            and event.currency == order.currency
        )


def get_provider(slug):
    if (
        slug == "dev" and not settings.PRODUCTION and os.getenv("PAYMENTS_ENABLE_DEV") == "true"
        and len(secret := os.getenv("PAYMENTS_DEV_WEBHOOK_SECRET", "")) >= 32
    ):
        return DevelopmentPayments(secret)
    raise Problem("payment_provider_unavailable", 503, "This payment provider is unavailable.")
