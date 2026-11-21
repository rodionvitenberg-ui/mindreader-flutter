from django.db import models


class Counter(models.Model):
    key = models.CharField(max_length=160)
    window = models.DateTimeField()
    count = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["key", "window"], name="unique_counter_window")]


class Operation(models.Model):
    owner = models.ForeignKey("accounts.Principal", on_delete=models.CASCADE)
    scope = models.CharField(max_length=160)
    key = models.CharField(max_length=128)
    fingerprint = models.CharField(max_length=64)
    response = models.JSONField(null=True)
    status_code = models.PositiveSmallIntegerField(null=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["owner", "scope", "key"], name="unique_operation_key")]
