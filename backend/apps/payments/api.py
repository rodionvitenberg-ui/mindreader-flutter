import hashlib

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.catalog.models import Deck
from apps.core.api import Problem, checked, finish, operation, rate_limit, replay
from apps.entitlements.models import Grant, active_grants
from apps.oracle.api import IDEMPOTENCY

from .models import Event, Order
from .providers import get_provider


class CheckoutInput(serializers.Serializer):
    deckId = serializers.UUIDField()
    provider = serializers.SlugField(max_length=40)


class OrderOutput(serializers.Serializer):
    id = serializers.UUIDField()
    deckId = serializers.UUIDField()
    provider = serializers.CharField()
    status = serializers.ChoiceField(Order.Status.values)
    checkoutUrl = serializers.URLField(allow_null=True)
    providerReference = serializers.CharField(allow_null=True)
    priceMinor = serializers.IntegerField()
    currency = serializers.CharField()
    updatedAt = serializers.DateTimeField()


class EventOutput(serializers.Serializer):
    accepted = serializers.BooleanField()
    applied = serializers.BooleanField()


class EventInput(serializers.Serializer):
    eventId = serializers.CharField()
    orderId = serializers.UUIDField()
    reference = serializers.CharField()
    status = serializers.CharField()
    priceMinor = serializers.IntegerField()
    currency = serializers.CharField()


def order_data(order):
    return {
        "id": str(order.pk), "deckId": str(order.deck_id), "provider": order.provider, "status": order.status,
        "priceMinor": order.price_minor, "currency": order.currency, "checkoutUrl": order.checkout_url or None,
        "providerReference": order.provider_reference or None, "updatedAt": order.updated_at.isoformat(),
    }


@extend_schema(request=CheckoutInput, responses={201: OrderOutput}, parameters=[IDEMPOTENCY])
@api_view(["POST"])
def checkout(request):
    owner = request.auth.principal
    if not owner.is_verified:
        raise Problem("verified_account_required", 403, "Verify an account before checkout.")
    data = checked(CheckoutInput, request.data)
    with transaction.atomic():
        op, fresh = operation(request, "payments:checkout", data)
        if not fresh:
            return replay(op)
        adapter = get_provider(data["provider"])
        rate_limit(f"checkout:{owner.pk}", 10)
        deck = get_object_or_404(Deck.objects.select_for_update(), pk=data["deckId"], published=True)
        if not deck.price_minor:
            raise Problem("free_deck", 409, "Use free acquisition for this deck.")
        if active_grants(owner).filter(deck=deck).exists():
            raise Problem("deck_already_owned", 409, "This account already owns the deck.")
        row = Order.objects.create(
            owner=owner, deck=deck, provider=data["provider"], price_minor=deck.price_minor, currency=deck.currency,
        )
    try:
        payment = adapter.create_checkout(row)
    except Problem as exc:
        with transaction.atomic():
            row = Order.objects.select_for_update().get(pk=row.pk)
            if row.status == Order.Status.PENDING:
                row.status = Order.Status.FAILED
                row.save(update_fields=["status", "updated_at"])
            return finish(op, {"code": exc.get_codes(), "detail": str(exc.detail), "requestId": str(op.pk),
                               "orderId": str(row.pk)}, exc.status_code)
    with transaction.atomic():
        row = Order.objects.select_for_update().get(pk=row.pk)
        if row.status == Order.Status.PENDING:
            row.provider_reference, row.checkout_url = payment.reference, payment.url
            row.status = Order.Status.AWAITING_PAYMENT
            row.save(update_fields=["provider_reference", "checkout_url", "status", "updated_at"])
        return finish(op, order_data(row), 201)


@extend_schema(responses=OrderOutput)
@api_view(["GET"])
def order(request, order_id):
    return Response(order_data(get_object_or_404(Order, pk=order_id, owner=request.auth.principal)))


def apply_event(order, status):
    if order.status == Order.Status.REFUNDED or order.status == status:
        return False
    if status == Order.Status.REFUNDED:
        Grant.objects.filter(order=order, source=Grant.Source.PURCHASE, revoked_at__isnull=True).update(
            revoked_at=timezone.now()
        )
    elif status == Order.Status.PAID:
        Grant.objects.get_or_create(
            order=order, defaults={"owner": order.owner, "deck": order.deck, "source": Grant.Source.PURCHASE},
        )
    elif order.status not in {Order.Status.PENDING, Order.Status.AWAITING_PAYMENT}:
        return False
    order.status = status
    order.save(update_fields=["status", "provider_reference", "updated_at"])
    return True


@extend_schema(request=EventInput, responses=EventOutput, parameters=[
    OpenApiParameter("X-Tarot-Webhook-Signature", str, OpenApiParameter.HEADER),
    OpenApiParameter("X-Tarot-Webhook-Timestamp", str, OpenApiParameter.HEADER),
])
@api_view(["POST"])
@permission_classes([AllowAny])
def webhook(request, provider):
    adapter = get_provider(provider)
    body = request.body
    if len(body) > 16 * 1024:
        raise Problem("request_too_large", 413, "Webhook is too large.")
    event = adapter.verify_webhook(body, request.headers)
    snapshot = get_object_or_404(Order, pk=event.order_id, provider=provider)
    if not adapter.verify_payment(snapshot, event):
        raise Problem("payment_verification_failed", 400, "Payment details did not verify.")
    with transaction.atomic():
        row = get_object_or_404(Order.objects.select_for_update(), pk=event.order_id, provider=provider)
        if row.provider_reference and row.provider_reference != event.reference:
            raise Problem("payment_verification_failed", 400, "Payment details did not verify.")
        fingerprint = hashlib.sha256(body).hexdigest()
        seen, fresh = Event.objects.get_or_create(
            provider=provider, event_id=event.event_id,
            defaults={"order": row, "status": event.status, "fingerprint": fingerprint},
        )
        if not fresh and (seen.order_id != row.pk or seen.fingerprint != fingerprint):
            raise Problem("payment_event_conflict", 409, "This event ID belongs to different data.")
        if fresh:
            row.provider_reference = event.reference
            seen.applied = apply_event(row, event.status)
            seen.save(update_fields=["applied"])
        return Response({"accepted": True, "applied": seen.applied})
