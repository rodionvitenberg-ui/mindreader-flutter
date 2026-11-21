import uuid

from django.db import models


class Recognition(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reading = models.ForeignKey("oracle.Reading", on_delete=models.CASCADE)
    item_id = models.CharField(max_length=100)
    track_id = models.CharField(max_length=100, blank=True)
    provider = models.CharField(max_length=50, blank=True)
    status = models.CharField(max_length=20, default="recognizing")
    candidates = models.JSONField(default=list)
    decision = models.CharField(max_length=10, blank=True)
    confirmed_position = models.ForeignKey("oracle.Position", on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ("created_at", "id")
