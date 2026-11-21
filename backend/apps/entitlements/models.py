from django.conf import settings
from django.db import models
from django.db.models import Q


class Grant(models.Model):
    class Source(models.TextChoices):
        FREE = "free", "Free"
        PURCHASE = "purchase", "Purchase"
        ADMIN = "admin", "Administrative"
        PROMOTION = "promotion", "Promotion"

    owner = models.ForeignKey("accounts.Principal", on_delete=models.CASCADE)
    deck = models.ForeignKey("catalog.Deck", on_delete=models.PROTECT)
    source = models.CharField(max_length=10, choices=Source)
    order = models.OneToOneField("payments.Order", null=True, blank=True, editable=False, on_delete=models.PROTECT)
    granted_at = models.DateTimeField(auto_now_add=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    granted_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, editable=False, on_delete=models.SET_NULL)
    reason = models.CharField(max_length=240, blank=True)

    class Meta:
        indexes = [models.Index(fields=["owner", "deck", "revoked_at"])]
        constraints = [models.UniqueConstraint(
            fields=("owner", "deck"), condition=Q(source="free", revoked_at__isnull=True), name="unique_active_free_grant"
        )]


def active_grants(owner):
    return Grant.objects.filter(owner=owner, revoked_at__isnull=True)
