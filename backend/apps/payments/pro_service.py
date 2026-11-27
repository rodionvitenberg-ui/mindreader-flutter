"""Bulletproof PRO subscription lifecycle, durable ledger backup, and Solana order activation."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
import secrets
from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.db import connection, transaction
from django.db.models import Max
from django.utils import timezone

from apps.accounts.models import Principal
from apps.core.api import Problem

from .models import ProLedgerEntry, ProOrder, ProReceipt
from .pro_notifications import notify_owner_pro_purchase, send_pro_receipt_email
from .solana import LAMPORTS_PER_SOL, MICRO_USDC_PER_USD, fetch_sol_usd_price

_PG_PRO_ACTIVATION_LOCK_ID = 748291045


def _acquire_pro_activation_lock() -> None:
    """Serializes slot allocation and receipt numbering safely on PostgreSQL without FOR UPDATE + aggregates."""
    if connection.vendor == "postgresql":
        with connection.cursor() as cursor:
            cursor.execute("SELECT pg_advisory_xact_lock(%s)", [_PG_PRO_ACTIVATION_LOCK_ID])


def pro_offer_snapshot() -> dict:
    limit = settings.PRO_EARLY_SUPPORTER_LIMIT
    taken = Principal.objects.filter(early_supporter_slot__isnull=False).count()
    remaining = max(0, limit - taken)
    return {
        "earlySupporterTotal": limit,
        "earlySupporterTaken": taken,
        "earlySupporterRemaining": remaining,
        "earlyMonthlyMinor": settings.PRO_EARLY_MONTHLY_MINOR,
        "standardMonthlyMinor": settings.PRO_STANDARD_MONTHLY_MINOR,
        "annualMinor": settings.PRO_ANNUAL_MINOR,
        "standardAnnualMinor": settings.PRO_STANDARD_ANNUAL_MINOR,
        "currency": "USD",
        "solanaWallet": settings.PRO_SOLANA_WALLET,
        "usdcMint": settings.SOLANA_USDC_MINT,
    }


def _append_jsonl_backup(record: dict) -> None:
    """Appends an fsync + flock-backed JSONL record to disk after DB commit."""
    backup_path = Path(settings.PRO_LEDGER_BACKUP_PATH)
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n"
    with open(backup_path, "a", encoding="utf-8") as fh:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            fh.write(line)
            fh.flush()
            os.fsync(fh.fileno())
        finally:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)


def _build_jsonl_record(entry: ProLedgerEntry, receipt: ProReceipt | None) -> dict:
    return {
        "ledgerId": str(entry.pk),
        "eventType": entry.event_type,
        "timestamp": entry.created_at.isoformat(),
        "principalId": str(entry.principal_id),
        "email": entry.email,
        "receiptNumber": receipt.receipt_number if receipt else None,
        "plan": receipt.plan if receipt else entry.payload_json.get("plan"),
        "earlySupporterSlot": (
            receipt.early_supporter_slot if receipt else entry.payload_json.get("earlySupporterSlot")
        ),
        "amountDisplay": receipt.amount_display if receipt else None,
        "txSignature": receipt.tx_signature if receipt else None,
        "periodEnd": receipt.period_end.isoformat() if (receipt and receipt.period_end) else None,
        "checksumSha256": receipt.checksum_sha256 if receipt else None,
    }


def _next_receipt_number(now) -> str:
    prefix = f"TT-PRO-{now.strftime('%Y%m%d')}-"
    latest = (
        ProReceipt.objects.filter(receipt_number__startswith=prefix)
        .aggregate(m=Max("receipt_number"))["m"]
    )
    if latest and latest.startswith(prefix):
        try:
            seq = int(latest[len(prefix):]) + 1
        except ValueError:
            seq = ProReceipt.objects.filter(receipt_number__startswith=prefix).count() + 1
    else:
        seq = 1
    return f"{prefix}{seq:04d}"


def _receipt_checksum(
    receipt_number: str,
    email: str,
    plan: str,
    price_minor_usd: int,
    tx_signature: str,
    period_start_iso: str,
) -> str:
    raw = "|".join([
        receipt_number,
        email.lower(),
        plan,
        str(price_minor_usd),
        tx_signature,
        period_start_iso,
    ])
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def create_pro_order(
    *,
    email: str,
    plan: str,
    asset: str,
    locale: str = "en",
    sol_usd_rate: float | None = None,
) -> ProOrder:
    clean_email = email.strip().lower()
    offer = pro_offer_snapshot()

    if plan == ProOrder.Plan.EARLY_MONTHLY:
        if offer["earlySupporterRemaining"] > 0:
            resolved_plan = ProOrder.Plan.EARLY_MONTHLY
            price_minor = settings.PRO_EARLY_MONTHLY_MINOR
        else:
            resolved_plan = ProOrder.Plan.MONTHLY
            price_minor = settings.PRO_STANDARD_MONTHLY_MINOR
    elif plan == ProOrder.Plan.MONTHLY:
        resolved_plan = ProOrder.Plan.MONTHLY
        price_minor = settings.PRO_STANDARD_MONTHLY_MINOR
    elif plan == ProOrder.Plan.ANNUAL:
        resolved_plan = ProOrder.Plan.ANNUAL
        price_minor = (
            settings.PRO_ANNUAL_MINOR
            if offer["earlySupporterRemaining"] > 0
            else settings.PRO_STANDARD_ANNUAL_MINOR
        )
    else:
        raise Problem("invalid_plan", 400, "Unsupported PRO plan.")

    usd_value = price_minor / 100.0
    if asset == ProOrder.Asset.USDC:
        expected_atomic = int(round(usd_value * MICRO_USDC_PER_USD))
        amount_display = f"{usd_value:.2f} USDC (${usd_value:.2f} USD)"
        provider = "solana"
    elif asset == ProOrder.Asset.SOL:
        rate = sol_usd_rate if (sol_usd_rate and sol_usd_rate > 0) else fetch_sol_usd_price()
        sol_amount = round(usd_value / rate, 5)
        expected_atomic = int(round(sol_amount * LAMPORTS_PER_SOL))
        amount_display = f"{sol_amount:.5f} SOL (~${usd_value:.2f} USD)"
        provider = "solana"
    elif asset == ProOrder.Asset.DEV:
        if settings.PRODUCTION or os.getenv("PAYMENTS_ENABLE_DEV") != "true":
            raise Problem("payment_provider_unavailable", 503, "Sandbox payments are disabled.")
        expected_atomic = price_minor
        amount_display = f"${usd_value:.2f} USD (DEV)"
        provider = "dev"
    else:
        raise Problem("unsupported_asset", 400, "Unsupported payment asset.")

    existing_principal = Principal.objects.filter(verified_email=clean_email).first()
    memo = f"TTPRO-{secrets.token_hex(6).upper()}"
    return ProOrder.objects.create(
        email=clean_email,
        owner=existing_principal,
        plan=resolved_plan,
        provider=provider,
        asset=asset,
        price_minor_usd=price_minor,
        expected_amount_atomic=expected_atomic,
        amount_display=amount_display,
        destination_wallet=settings.PRO_SOLANA_WALLET,
        reference_memo=memo,
        locale=(locale or "en")[:10],
        status=ProOrder.Status.PENDING,
        expires_at=timezone.now() + timedelta(minutes=45),
    )


def activate_pro_order(
    order: ProOrder,
    *,
    tx_signature: str,
    payer_wallet: str = "",
    block_time=None,
) -> ProReceipt:
    """Atomically activates PRO for order.email, issues a durable receipt, and notifies user + owner."""
    now = timezone.now()
    sig = tx_signature.strip()

    with transaction.atomic():
        _acquire_pro_activation_lock()
        locked_order = ProOrder.objects.select_for_update().get(pk=order.pk)
        if locked_order.status == ProOrder.Status.PAID and hasattr(locked_order, "receipt"):
            return locked_order.receipt

        if sig and ProOrder.objects.filter(solana_tx_signature=sig).exclude(pk=locked_order.pk).exists():
            raise Problem("tx_already_used", 409, "This Solana transaction was already applied to another order.")

        principal, _ = Principal.objects.get_or_create(verified_email=locked_order.email)
        principal = Principal.objects.select_for_update().get(pk=principal.pk)

        was_active = principal.has_active_pro
        period_start = now
        base_end = principal.pro_expires_at if (was_active and principal.pro_expires_at) else now
        duration = timedelta(days=366 if locked_order.plan == ProOrder.Plan.ANNUAL else 31)
        period_end = base_end + duration

        # Assign sequential Early Supporter slot (1..100) safely under transaction advisory lock.
        if (
            principal.early_supporter_slot is None
            and locked_order.plan in {ProOrder.Plan.EARLY_MONTHLY, ProOrder.Plan.ANNUAL}
        ):
            max_slot = (
                Principal.objects.filter(early_supporter_slot__isnull=False)
                .aggregate(m=Max("early_supporter_slot"))["m"]
                or 0
            )
            if max_slot < settings.PRO_EARLY_SUPPORTER_LIMIT:
                principal.early_supporter_slot = max_slot + 1

        principal.is_pro = True
        principal.pro_plan = locked_order.plan
        if principal.pro_since is None:
            principal.pro_since = now
        principal.pro_expires_at = period_end
        principal.save(update_fields=[
            "is_pro",
            "pro_plan",
            "pro_since",
            "pro_expires_at",
            "early_supporter_slot",
        ])

        locked_order.owner = principal
        locked_order.status = ProOrder.Status.PAID
        locked_order.solana_tx_signature = sig
        locked_order.payer_wallet = payer_wallet[:80]
        locked_order.onchain_block_time = block_time
        locked_order.save(update_fields=[
            "owner",
            "status",
            "solana_tx_signature",
            "payer_wallet",
            "onchain_block_time",
            "updated_at",
        ])

        receipt_number = _next_receipt_number(now)
        checksum = _receipt_checksum(
            receipt_number,
            locked_order.email,
            locked_order.plan,
            locked_order.price_minor_usd,
            sig,
            period_start.isoformat(),
        )
        receipt = ProReceipt.objects.create(
            receipt_number=receipt_number,
            order=locked_order,
            principal=principal,
            email=locked_order.email,
            plan=locked_order.plan,
            early_supporter_slot=principal.early_supporter_slot,
            amount_display=locked_order.amount_display,
            price_minor_usd=locked_order.price_minor_usd,
            asset=locked_order.asset,
            tx_signature=sig,
            period_start=period_start,
            period_end=period_end,
            checksum_sha256=checksum,
        )

        ledger = ProLedgerEntry.objects.create(
            event_type=ProLedgerEntry.EventType.RENEWED if was_active else ProLedgerEntry.EventType.ACTIVATED,
            principal=principal,
            email=locked_order.email,
            receipt=receipt,
            payload_json={
                "orderId": str(locked_order.pk),
                "plan": locked_order.plan,
                "asset": locked_order.asset,
                "priceMinorUsd": locked_order.price_minor_usd,
                "earlySupporterSlot": principal.early_supporter_slot,
                "txSignature": sig,
                "payerWallet": payer_wallet,
                "periodEnd": period_end.isoformat(),
            },
        )
        backup_record = _build_jsonl_record(ledger, receipt)
        transaction.on_commit(lambda rec=backup_record: _append_jsonl_backup(rec))

    # Best-effort transactional notifications outside the DB lock.
    send_pro_receipt_email(receipt, locale=locked_order.locale)
    notify_owner_pro_purchase(receipt)
    return receipt
