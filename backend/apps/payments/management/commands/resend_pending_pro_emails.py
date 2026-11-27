from django.core.management.base import BaseCommand
from django.db.models import Q

from apps.payments.models import ProReceipt
from apps.payments.pro_notifications import notify_owner_pro_purchase, send_pro_receipt_email


class Command(BaseCommand):
    help = "Retry sending any pending PRO subscriber receipts or owner purchase notifications."

    def handle(self, *args, **options):
        pending = ProReceipt.objects.select_related("order").filter(
            Q(user_email_sent_at__isnull=True) | Q(owner_notified_at__isnull=True)
        )
        retried = 0
        for receipt in pending:
            if receipt.user_email_sent_at is None:
                send_pro_receipt_email(receipt, locale=receipt.order.locale)
            if receipt.owner_notified_at is None:
                notify_owner_pro_purchase(receipt)
            retried += 1
        self.stdout.write(f"Processed {retried} pending PRO receipt(s).")
