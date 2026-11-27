"""Email receipts to PRO subscribers and separate purchase alerts to the owner."""

from __future__ import annotations

import json
import logging
import urllib.request

from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone

from .models import ProReceipt

logger = logging.getLogger(__name__)


def _plan_title(plan: str, is_ru: bool) -> str:
    if is_ru:
        return {
            "early_monthly": "Early Supporter PRO · Месячная ($4.99/мес навсегда вместо $6.99)",
            "monthly": "Tarot Tree PRO · Месячная ($6.99/мес)",
            "annual": "Early Supporter PRO · Годовая ($39.99/год вместо $59.99)",
            "lifetime": "Tarot Tree PRO · Бессрочный доступ",
        }.get(plan, plan)
    return {
        "early_monthly": "Early Supporter PRO · Monthly ($4.99/mo forever instead of $6.99)",
        "monthly": "Tarot Tree PRO · Monthly ($6.99/mo)",
        "annual": "Early Supporter PRO · Annual ($39.99/yr instead of $59.99)",
        "lifetime": "Tarot Tree PRO · Lifetime",
    }.get(plan, plan)


def send_pro_receipt_email(receipt: ProReceipt, locale: str = "en") -> bool:
    """Sends an itemized receipt email to the subscriber. Never raises."""
    if receipt.user_email_sent_at is not None:
        return True
    is_ru = (locale or "").lower().startswith("ru")
    plan_label = _plan_title(receipt.plan, is_ru)
    slot_line = ""
    if receipt.early_supporter_slot:
        slot_line = (
            f"Место Early Supporter: #{receipt.early_supporter_slot} из {settings.PRO_EARLY_SUPPORTER_LIMIT}\n"
            if is_ru
            else f"Early Supporter slot: #{receipt.early_supporter_slot} of {settings.PRO_EARLY_SUPPORTER_LIMIT}\n"
        )
    tx_line = ""
    if receipt.tx_signature:
        solscan = f"https://solscan.io/tx/{receipt.tx_signature}"
        tx_line = (
            f"Транзакция Solana: {receipt.tx_signature}\nSolscan: {solscan}\n"
            if is_ru
            else f"Solana transaction: {receipt.tx_signature}\nSolscan: {solscan}\n"
        )
    valid_until = (
        receipt.period_end.strftime("%Y-%m-%d %H:%M UTC")
        if receipt.period_end
        else ("Бессрочно" if is_ru else "Lifetime")
    )

    if is_ru:
        subject = f"Чек Tarot Tree PRO · {receipt.receipt_number}"
        body = (
            "Спасибо за поддержку Tarot Tree!\n\n"
            f"Номер чека: {receipt.receipt_number}\n"
            f"Email аккаунта: {receipt.email}\n"
            f"Тариф: {plan_label}\n"
            f"{slot_line}"
            f"Оплачено: {receipt.amount_display}\n"
            f"{tx_line}"
            f"Действует до: {valid_until}\n"
            f"Контрольная сумма (SHA-256): {receipt.checksum_sha256[:16]}…\n\n"
            "Как разблокировать PRO в приложении:\n"
            "1. Откройте Tarot Tree → Профиль.\n"
            "2. Войдите по этому же Email (если ещё не вошли).\n"
            "3. Нажмите «Проверить статус PRO» — все ограничения снимутся мгновенно.\n\n"
            "Сохраните это письмо как подтверждение оплаты."
        )
    else:
        subject = f"Tarot Tree PRO Receipt · {receipt.receipt_number}"
        body = (
            "Thank you for supporting Tarot Tree!\n\n"
            f"Receipt number: {receipt.receipt_number}\n"
            f"Account email: {receipt.email}\n"
            f"Plan: {plan_label}\n"
            f"{slot_line}"
            f"Amount paid: {receipt.amount_display}\n"
            f"{tx_line}"
            f"Active until: {valid_until}\n"
            f"Integrity hash (SHA-256): {receipt.checksum_sha256[:16]}…\n\n"
            "How to unlock PRO in the app:\n"
            "1. Open Tarot Tree → Profile.\n"
            "2. Sign in with this same email (if not signed in yet).\n"
            "3. Tap 'Check PRO status' — every lock lifts immediately.\n\n"
            "Please keep this email as your payment receipt."
        )

    try:
        send_mail(subject, body, settings.DEFAULT_FROM_EMAIL, [receipt.email], fail_silently=False)
        receipt.user_email_sent_at = timezone.now()
        receipt.save(update_fields=["user_email_sent_at"])
        return True
    except Exception as exc:  # pragma: no cover - defensive SMTP guard
        logger.warning("Failed to send PRO receipt email (%s: %s)", type(exc).__name__, str(exc)[:160])
        return False


def notify_owner_pro_purchase(receipt: ProReceipt) -> bool:
    """Sends a separate alert to the founder via Email and/or Telegram. Never raises."""
    if receipt.owner_notified_at is not None:
        return True

    slot_tag = (
        f" [Early #{receipt.early_supporter_slot}/{settings.PRO_EARLY_SUPPORTER_LIMIT}]"
        if receipt.early_supporter_slot
        else ""
    )
    solscan = f"https://solscan.io/tx/{receipt.tx_signature}" if receipt.tx_signature else "n/a"
    summary = (
        f"New Tarot Tree PRO purchase{slot_tag}\n"
        f"Receipt: {receipt.receipt_number}\n"
        f"Email: {receipt.email}\n"
        f"Plan: {receipt.plan}\n"
        f"Amount: {receipt.amount_display}\n"
        f"Tx: {solscan}\n"
        f"Active until: {receipt.period_end.isoformat() if receipt.period_end else 'lifetime'}"
    )

    delivered = False
    owner_email = (settings.PRO_OWNER_NOTIFY_EMAIL or "").strip()
    if owner_email:
        try:
            send_mail(
                f"[Tarot Tree PRO]{slot_tag} {receipt.email} · {receipt.amount_display}",
                summary,
                settings.DEFAULT_FROM_EMAIL,
                [owner_email],
                fail_silently=False,
            )
            delivered = True
        except Exception as exc:  # pragma: no cover - defensive SMTP guard
            logger.warning("Failed to send owner PRO alert email (%s)", type(exc).__name__)

    tg_token = (settings.PRO_OWNER_TELEGRAM_BOT_TOKEN or "").strip()
    tg_chat = (settings.PRO_OWNER_TELEGRAM_CHAT_ID or "").strip()
    if tg_token and tg_chat:
        try:
            payload = json.dumps({"chat_id": tg_chat, "text": summary}).encode("utf-8")
            req = urllib.request.Request(
                f"https://api.telegram.org/bot{tg_token}/sendMessage",
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=5):
                delivered = True
        except Exception as exc:  # pragma: no cover - defensive network guard
            logger.warning("Failed to send owner Telegram PRO alert (%s)", type(exc).__name__)

    if delivered:
        receipt.owner_notified_at = timezone.now()
        receipt.save(update_fields=["owner_notified_at"])
    return delivered
