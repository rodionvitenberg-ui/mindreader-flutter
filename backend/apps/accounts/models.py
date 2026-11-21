import uuid

from django.conf import settings
from django.db import models


class Principal(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.CASCADE)
    verified_email = models.EmailField(null=True, blank=True, unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_verified(self):
        return bool(self.user_id and self.verified_email and self.user.is_active)


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
