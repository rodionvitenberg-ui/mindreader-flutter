import csv
import json
import sys

from django.core.management.base import BaseCommand

from apps.accounts.models import Principal


class Command(BaseCommand):
    help = "Export all PRO subscribers (active & historical) with Early Supporter slots and latest receipt."

    def add_arguments(self, parser):
        parser.add_argument("--format", choices=["json", "csv"], default="json")
        parser.add_argument("--output", default="")

    def handle(self, *args, **options):
        rows = []
        qs = (
            Principal.objects.filter(is_pro=True)
            .prefetch_related("pro_receipts")
            .order_by("early_supporter_slot", "pro_since")
        )
        for p in qs:
            latest = p.pro_receipts.order_by("-created_at").first()
            rows.append({
                "principalId": str(p.pk),
                "email": p.verified_email or "",
                "name": p.display_name or "",
                "isActivePro": p.has_active_pro,
                "plan": p.pro_plan,
                "earlySupporterSlot": p.early_supporter_slot,
                "proSince": p.pro_since.isoformat() if p.pro_since else "",
                "proExpiresAt": p.pro_expires_at.isoformat() if p.pro_expires_at else "",
                "latestReceipt": latest.receipt_number if latest else "",
                "latestTxSignature": latest.tx_signature if latest else "",
            })

        out = open(options["output"], "w", encoding="utf-8", newline="") if options["output"] else sys.stdout
        try:
            if options["format"] == "csv":
                fields = list(rows[0].keys()) if rows else [
                    "principalId", "email", "name", "isActivePro", "plan",
                    "earlySupporterSlot", "proSince", "proExpiresAt", "latestReceipt", "latestTxSignature",
                ]
                writer = csv.DictWriter(out, fieldnames=fields)
                writer.writeheader()
                writer.writerows(rows)
            else:
                json.dump(rows, out, ensure_ascii=False, indent=2)
                out.write("\n")
        finally:
            if options["output"]:
                out.close()
