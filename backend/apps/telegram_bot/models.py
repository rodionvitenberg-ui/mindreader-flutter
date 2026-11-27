import uuid

from django.db import models


class TelegramSubscriber(models.Model):
    chat_id = models.BigIntegerField(unique=True, db_index=True)
    language_code = models.CharField(max_length=12, default="en")
    daily_card_enabled = models.BooleanField(default=True)
    daily_hour_utc = models.PositiveSmallIntegerField(default=7)
    lunar_enabled = models.BooleanField(default=True)
    active = models.BooleanField(default=True, db_index=True)
    last_daily_sent_date = models.DateField(null=True, blank=True)
    last_lunar_sent_key = models.CharField(max_length=32, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"tg:{self.chat_id} ({'active' if self.active else 'stopped'})"


class TelegramCheckInReminder(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subscriber = models.ForeignKey(
        TelegramSubscriber,
        on_delete=models.CASCADE,
        related_name="check_ins",
    )
    spread_title = models.CharField(max_length=160, blank=True, default="")
    due_at = models.DateTimeField(db_index=True)
    sent_at = models.DateTimeField(null=True, blank=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["due_at"]
