import uuid

from django.db import models


class Order(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        AWAITING_PAYMENT = "awaiting_payment", "Awaiting payment"
        PAID = "paid", "Paid"
        FAILED = "failed", "Failed"
        CANCELLED = "cancelled", "Cancelled"
        REFUNDED = "refunded", "Refunded"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey("accounts.Principal", on_delete=models.PROTECT)
    deck = models.ForeignKey("catalog.Deck", on_delete=models.PROTECT)
    provider = models.SlugField(max_length=40)
    provider_reference = models.CharField(max_length=160, blank=True)
    checkout_url = models.URLField(max_length=2000, blank=True)
    price_minor = models.PositiveIntegerField()
    currency = models.CharField(max_length=3)
    status = models.CharField(max_length=20, choices=Status, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.UniqueConstraint(
            fields=["provider", "provider_reference"], condition=~models.Q(provider_reference=""),
            name="unique_provider_order_reference",
        )]

    def __str__(self):
        return str(self.pk)


class Event(models.Model):
    provider = models.SlugField(max_length=40)
    event_id = models.CharField(max_length=160)
    order = models.ForeignKey(Order, on_delete=models.PROTECT, related_name="events")
    status = models.CharField(max_length=20, choices=Order.Status)
    fingerprint = models.CharField(max_length=64)
    applied = models.BooleanField(default=False)
    received_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["provider", "event_id"], name="unique_payment_event")]
