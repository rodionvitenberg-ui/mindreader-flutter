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


class ProOrder(models.Model):
    class Plan(models.TextChoices):
        EARLY_MONTHLY = "early_monthly", "Early Supporter Monthly ($4.99/mo)"
        MONTHLY = "monthly", "Standard Monthly ($6.99/mo)"
        ANNUAL = "annual", "Early Supporter Annual ($39.99/yr)"

    class Asset(models.TextChoices):
        USDC = "USDC", "USDC (Solana SPL)"
        SOL = "SOL", "SOL (Solana)"
        DEV = "DEV", "Development Sandbox"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PAID = "paid", "Paid"
        FAILED = "failed", "Failed"
        EXPIRED = "expired", "Expired"
        REFUNDED = "refunded", "Refunded"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(db_index=True)
    owner = models.ForeignKey("accounts.Principal", null=True, blank=True, on_delete=models.PROTECT)
    plan = models.CharField(max_length=24, choices=Plan.choices)
    provider = models.SlugField(max_length=40, default="solana")
    asset = models.CharField(max_length=8, choices=Asset.choices, default=Asset.USDC)
    price_minor_usd = models.PositiveIntegerField()
    expected_amount_atomic = models.BigIntegerField()
    amount_display = models.CharField(max_length=64)
    destination_wallet = models.CharField(max_length=80)
    reference_memo = models.CharField(max_length=64, unique=True)
    solana_tx_signature = models.CharField(max_length=128, blank=True, default="")
    payer_wallet = models.CharField(max_length=80, blank=True, default="")
    onchain_block_time = models.DateTimeField(null=True, blank=True)
    locale = models.CharField(max_length=10, default="en")
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING, db_index=True)
    expires_at = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["solana_tx_signature"],
                condition=~models.Q(solana_tx_signature=""),
                name="unique_pro_solana_tx_signature",
            ),
        ]

    def __str__(self):
        return f"{self.email} ({self.plan}, {self.status})"


class ProReceipt(models.Model):
    """Immutable payment receipt stored permanently with SHA-256 integrity hash."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    receipt_number = models.CharField(max_length=40, unique=True)
    order = models.OneToOneField(ProOrder, on_delete=models.PROTECT, related_name="receipt")
    principal = models.ForeignKey("accounts.Principal", on_delete=models.PROTECT, related_name="pro_receipts")
    email = models.EmailField(db_index=True)
    plan = models.CharField(max_length=24)
    early_supporter_slot = models.PositiveSmallIntegerField(null=True, blank=True)
    amount_display = models.CharField(max_length=64)
    price_minor_usd = models.PositiveIntegerField()
    asset = models.CharField(max_length=8)
    tx_signature = models.CharField(max_length=128, blank=True, default="")
    period_start = models.DateTimeField()
    period_end = models.DateTimeField(null=True, blank=True)
    checksum_sha256 = models.CharField(max_length=64)
    user_email_sent_at = models.DateTimeField(null=True, blank=True)
    owner_notified_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.receipt_number} ({self.email})"


class ProLedgerEntry(models.Model):
    """Append-only audit trail for every PRO entitlement change."""

    class EventType(models.TextChoices):
        ACTIVATED = "activated", "Activated"
        RENEWED = "renewed", "Renewed"
        REVOKED = "revoked", "Revoked"
        ADMIN_GRANT = "admin_grant", "Admin grant"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    event_type = models.CharField(max_length=24, choices=EventType.choices)
    principal = models.ForeignKey("accounts.Principal", on_delete=models.PROTECT, related_name="pro_ledger")
    email = models.EmailField(db_index=True)
    receipt = models.ForeignKey(ProReceipt, null=True, blank=True, on_delete=models.PROTECT)
    payload_json = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    def __str__(self):
        return f"{self.event_type}: {self.email} @ {self.created_at.isoformat()}"
