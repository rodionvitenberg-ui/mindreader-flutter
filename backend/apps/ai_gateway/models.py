import uuid
from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator
from django.db import models


class Capability(models.TextChoices):
    ORACLE = "oracle", "Oracle"
    VISION = "vision", "Vision"


class Protocol(models.TextChoices):
    OPENAI_CHAT = "openai_chat", "OpenAI-compatible chat"
    HTTP_VISION = "http_vision", "Tarot Tree Vision HTTP v1"


class Provider(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.SlugField(unique=True)
    capability = models.CharField(max_length=12, choices=Capability)
    protocol = models.CharField(max_length=20, choices=Protocol)
    endpoint = models.URLField(max_length=500)
    health_path = models.CharField(
        max_length=200, blank=True, validators=[RegexValidator(r"^/[A-Za-z0-9_./-]*$")]
    )
    model = models.CharField(max_length=180)
    credential_ref = models.CharField(
        max_length=100, blank=True, validators=[RegexValidator(r"^AI_CREDENTIAL_[A-Z0-9_]+$")]
    )
    enabled = models.BooleanField(default=False)
    priority = models.PositiveSmallIntegerField(default=100)
    connect_timeout = models.FloatField(default=3.0, validators=[MinValueValidator(0.1), MaxValueValidator(15)])
    inference_timeout = models.FloatField(default=15.0, validators=[MinValueValidator(0.5), MaxValueValidator(45)])
    retries = models.PositiveSmallIntegerField(default=0, validators=[MaxValueValidator(2)])
    concurrency_limit = models.PositiveSmallIntegerField(default=2, validators=[MinValueValidator(1)])
    daily_request_limit = models.PositiveIntegerField(default=200, validators=[MinValueValidator(1)])
    is_paid = models.BooleanField(default=True)
    max_cost_per_request = models.DecimalField(
        max_digits=12, decimal_places=6, default=Decimal("0"), validators=[MinValueValidator(Decimal("0"))],
        help_text="Conservative upper bound on cost per attempt in USD.",
    )
    daily_spending_limit = models.DecimalField(
        max_digits=12, decimal_places=6, null=True, blank=True, validators=[MinValueValidator(Decimal("0"))],
    )
    health = models.CharField(max_length=24, default="unchecked", editable=False)
    health_checked_at = models.DateTimeField(null=True, editable=False)

    class Meta:
        ordering = ("priority", "name")

    def __str__(self):
        return self.name

    def clean(self):
        from .transport import endpoint_allowed

        expected = {Capability.ORACLE: Protocol.OPENAI_CHAT, Capability.VISION: Protocol.HTTP_VISION}
        if self.protocol != expected.get(self.capability):
            raise ValidationError({"protocol": "The adapter does not support this capability."})
        if not endpoint_allowed(self.endpoint, self.capability):
            raise ValidationError({"endpoint": "Use an approved endpoint without user info, query or fragments."})
        if self.enabled and self.is_paid and (not self.max_cost_per_request or not self.daily_spending_limit):
            raise ValidationError({"daily_spending_limit": "Enabled paid routes need positive cost and budget limits."})
        if self.daily_spending_limit is not None and self.daily_spending_limit < self.max_cost_per_request:
            raise ValidationError({"daily_spending_limit": "Budget is lower than the per-request cost ceiling."})


class RoutingPolicy(models.Model):
    capability = models.CharField(max_length=12, choices=Capability, primary_key=True)
    allow_paid_fallback = models.BooleanField(default=False)

    class Meta:
        verbose_name_plural = "Routing policies"

    def __str__(self):
        return self.capability


class Usage(models.Model):
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE)
    day = models.DateField()
    count = models.PositiveIntegerField(default=0)
    reserved_cost = models.DecimalField(max_digits=16, decimal_places=6, default=Decimal("0"))

    class Meta:
        constraints = [models.UniqueConstraint(fields=("provider", "day"), name="provider_usage_day")]


class Lease(models.Model):
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE)
    expires_at = models.DateTimeField(db_index=True)
