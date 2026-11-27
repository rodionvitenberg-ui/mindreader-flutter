import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class Principal(models.Model):
    class ProPlan(models.TextChoices):
        NONE = "", "Free"
        EARLY_MONTHLY = "early_monthly", "Early Supporter Monthly ($4.99/mo)"
        MONTHLY = "monthly", "Standard Monthly ($6.99/mo)"
        ANNUAL = "annual", "Early Supporter Annual ($39.99/yr)"
        LIFETIME = "lifetime", "Lifetime"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.CASCADE)
    verified_email = models.EmailField(null=True, blank=True, unique=True, editable=False)
    display_name = models.CharField(max_length=120, blank=True, default="")
    email_confirmed = models.BooleanField(default=False)
    is_pro = models.BooleanField(default=False, db_index=True)
    pro_plan = models.CharField(max_length=24, choices=ProPlan.choices, blank=True, default="")
    pro_since = models.DateTimeField(null=True, blank=True)
    pro_expires_at = models.DateTimeField(null=True, blank=True, db_index=True)
    early_supporter_slot = models.PositiveSmallIntegerField(null=True, blank=True, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_verified(self):
        return bool(self.user_id and self.verified_email and self.user.is_active)

    @property
    def has_active_pro(self):
        if not self.is_pro:
            return False
        if self.pro_expires_at is None:
            return True
        return self.pro_expires_at > timezone.now()


class AccessToken(models.Model):
    principal = models.ForeignKey(Principal, on_delete=models.CASCADE, related_name="tokens")
    digest = models.CharField(max_length=64, unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(db_index=True)
    revoked_at = models.DateTimeField(null=True, blank=True)


class EmailChallenge(models.Model):
    email = models.EmailField()
    digest = models.CharField(max_length=64, unique=True, editable=False)
    expires_at = models.DateTimeField(db_index=True)
    used_at = models.DateTimeField(null=True, blank=True)


class HandoffToken(models.Model):
    """Short-lived single-use code to transfer a verified session to the web shop."""

    principal = models.ForeignKey(Principal, on_delete=models.CASCADE, related_name="handoffs")
    digest = models.CharField(max_length=64, unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(db_index=True)
    used_at = models.DateTimeField(null=True, blank=True)
