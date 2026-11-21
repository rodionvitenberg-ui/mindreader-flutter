from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import AccessToken, EmailChallenge, Principal
from apps.ai_gateway.models import Lease
from apps.core.models import Counter, Operation
from apps.vision.models import Recognition


class Command(BaseCommand):
    help = "Report or delete expired guest data, short-lived records and intermediate recognition results."

    def add_arguments(self, parser):
        parser.add_argument("--apply", action="store_true", help="Delete the selected records.")

    @transaction.atomic
    def handle(self, *args, **options):
        now = timezone.now()
        day = timedelta(days=1)
        active = AccessToken.objects.filter(expires_at__gt=now, revoked_at__isnull=True)
        eligible = {
            "guests": Principal.objects.filter(user__isnull=True, created_at__lt=now - 30 * day).exclude(
                id__in=active.values("principal_id"),
            ).exclude(verified_email__isnull=False),
            "tokens": AccessToken.objects.filter(expires_at__lt=now - day),
            "email challenges": EmailChallenge.objects.filter(expires_at__lt=now - day),
            "rate limits": Counter.objects.filter(window__lt=now - 2 * day),
            "provider leases": Lease.objects.filter(expires_at__lt=now - day),
            "recognitions": Recognition.objects.filter(created_at__lt=now - 7 * day),
            "recognition response records": Operation.objects.filter(
                created_at__lt=now - 7 * day, scope__startswith="vision:",
            ),
        }
        for name, rows in eligible.items():
            if options["apply"]:
                count = rows.count()
                rows.delete()
                self.stdout.write(f"{name}: removed {count}")
            else:
                self.stdout.write(f"{name}: eligible {rows.count()}")
