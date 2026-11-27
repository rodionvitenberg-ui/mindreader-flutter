import uuid
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0004_principal_pro"),
        ("payments", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ProOrder",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("email", models.EmailField(db_index=True, max_length=254)),
                ("plan", models.CharField(choices=[("early_monthly", "Early Supporter Monthly ($4.99/mo)"), ("monthly", "Standard Monthly ($6.99/mo)"), ("annual", "Early Supporter Annual ($39.99/yr)")], max_length=24)),
                ("provider", models.SlugField(default="solana", max_length=40)),
                ("asset", models.CharField(choices=[("USDC", "USDC (Solana SPL)"), ("SOL", "SOL (Solana)"), ("DEV", "Development Sandbox")], default="USDC", max_length=8)),
                ("price_minor_usd", models.PositiveIntegerField()),
                ("expected_amount_atomic", models.BigIntegerField()),
                ("amount_display", models.CharField(max_length=64)),
                ("destination_wallet", models.CharField(max_length=80)),
                ("reference_memo", models.CharField(max_length=64, unique=True)),
                ("solana_tx_signature", models.CharField(blank=True, default="", max_length=128)),
                ("payer_wallet", models.CharField(blank=True, default="", max_length=80)),
                ("onchain_block_time", models.DateTimeField(blank=True, null=True)),
                ("locale", models.CharField(default="en", max_length=10)),
                ("status", models.CharField(choices=[("pending", "Pending"), ("paid", "Paid"), ("failed", "Failed"), ("expired", "Expired"), ("refunded", "Refunded")], db_index=True, default="pending", max_length=20)),
                ("expires_at", models.DateTimeField(db_index=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("owner", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, to="accounts.principal")),
            ],
        ),
        migrations.AddConstraint(
            model_name="proorder",
            constraint=models.UniqueConstraint(
                condition=models.Q(("solana_tx_signature", ""), _negated=True),
                fields=("solana_tx_signature",),
                name="unique_pro_solana_tx_signature",
            ),
        ),
        migrations.CreateModel(
            name="ProReceipt",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("receipt_number", models.CharField(max_length=40, unique=True)),
                ("email", models.EmailField(db_index=True, max_length=254)),
                ("plan", models.CharField(max_length=24)),
                ("early_supporter_slot", models.PositiveSmallIntegerField(blank=True, null=True)),
                ("amount_display", models.CharField(max_length=64)),
                ("price_minor_usd", models.PositiveIntegerField()),
                ("asset", models.CharField(max_length=8)),
                ("tx_signature", models.CharField(blank=True, default="", max_length=128)),
                ("period_start", models.DateTimeField()),
                ("period_end", models.DateTimeField(blank=True, null=True)),
                ("checksum_sha256", models.CharField(max_length=64)),
                ("user_email_sent_at", models.DateTimeField(blank=True, null=True)),
                ("owner_notified_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("order", models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, related_name="receipt", to="payments.proorder")),
                ("principal", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="pro_receipts", to="accounts.principal")),
            ],
        ),
        migrations.CreateModel(
            name="ProLedgerEntry",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("event_type", models.CharField(choices=[("activated", "Activated"), ("renewed", "Renewed"), ("revoked", "Revoked"), ("admin_grant", "Admin grant")], max_length=24)),
                ("email", models.EmailField(db_index=True, max_length=254)),
                ("payload_json", models.JSONField(default=dict)),
                ("created_at", models.DateTimeField(auto_now_add=True, db_index=True)),
                ("principal", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="pro_ledger", to="accounts.principal")),
                ("receipt", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.PROTECT, to="payments.proreceipt")),
            ],
        ),
    ]
