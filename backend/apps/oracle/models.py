import uuid

from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import Q

from apps.ai_gateway.models import Capability


class Personality(models.Model):
    slug = models.SlugField(unique=True)
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    system_prompt = models.TextField()
    style = models.CharField(max_length=240, blank=True)
    language = models.CharField(max_length=40, blank=True)
    enabled = models.BooleanField(default=True)
    provider = models.ForeignKey("ai_gateway.Provider", null=True, blank=True, on_delete=models.PROTECT)
    model_override = models.CharField(max_length=180, blank=True)

    class Meta:
        verbose_name_plural = "Oracle personalities"

    def clean(self):
        if self.provider_id and self.provider.capability != Capability.ORACLE:
            raise ValidationError({"provider": "Select an Oracle provider."})
        if self.model_override and not self.provider_id:
            raise ValidationError({"model_override": "Select an explicit Oracle provider for the override."})

    def __str__(self):
        return self.name


class Reading(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey("accounts.Principal", on_delete=models.CASCADE)
    client_session_id = models.CharField(max_length=128, blank=True)
    kind = models.CharField(max_length=22, default="divinationSpread")
    system = models.CharField(max_length=10, blank=True)
    mode = models.CharField(max_length=16)
    source = models.CharField(max_length=8)
    spread_id = models.CharField(max_length=64, blank=True)
    question = models.TextField(blank=True)
    notes = models.JSONField(default=list)
    subject = models.CharField(max_length=8)
    subject_context = models.TextField(blank=True)
    astral_context = models.JSONField(null=True)
    personality = models.ForeignKey(Personality, on_delete=models.PROTECT)
    synthesis = models.JSONField(null=True)
    active_operation = models.ForeignKey("core.Operation", null=True, on_delete=models.SET_NULL)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True, db_index=True)

    class Meta:
        constraints = [models.UniqueConstraint(
            fields=["owner", "client_session_id"], condition=~Q(client_session_id=""), name="owner_client_session"
        )]


class Position(models.Model):
    reading = models.ForeignKey(Reading, on_delete=models.CASCADE, related_name="positions")
    index = models.PositiveSmallIntegerField()
    role = models.CharField(max_length=500)
    note = models.TextField(blank=True)
    clarifier = models.BooleanField(default=False)
    card_id = models.CharField(max_length=20, blank=True)
    orientation = models.CharField(max_length=10, blank=True)
    source = models.CharField(max_length=8, blank=True)
    track_id = models.CharField(max_length=100, blank=True)
    clarifier_question = models.TextField(blank=True)
    clarification = models.TextField(blank=True)

    class Meta:
        ordering = ("index",)
        constraints = [
            models.UniqueConstraint(fields=["reading", "index"], name="reading_position"),
            models.UniqueConstraint(fields=["reading", "track_id"], condition=~Q(track_id=""), name="reading_track"),
        ]


class Message(models.Model):
    reading = models.ForeignKey(Reading, on_delete=models.CASCADE, related_name="messages")
    role = models.CharField(max_length=8)
    text = models.TextField()
    slot_index = models.PositiveSmallIntegerField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("id",)
