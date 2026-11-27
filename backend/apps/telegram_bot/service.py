"""Telegram Mini App HMAC verification, bot command handling, and reminder dispatch."""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone as dt_timezone

from django.conf import settings
from django.utils import timezone

from .models import TelegramCheckInReminder, TelegramSubscriber

logger = logging.getLogger("tarottree.telegram_bot")

# Reference New Moon: 2000-01-06 18:14 UTC (Meeus); synodic month in seconds.
_REF_NEW_MOON = datetime(2000, 1, 6, 18, 14, tzinfo=dt_timezone.utc)
_SYNODIC_DAYS = 29.530588853
_LUNAR_WINDOW_HOURS = 18.0


def _norm_lang(raw: str | None) -> str:
    code = (raw or "en").lower().split("-", 1)[0].strip()
    return "ru" if code in {"ru", "uk", "be", "kk"} else "en"


def _miniapp_url(startapp: str = "") -> str:
    base = (settings.TELEGRAM_MINIAPP_URL or "https://app.soshallitbe.cyou/").strip()
    if not startapp:
        return base
    sep = "&" if "?" in base else "?"
    return f"{base}{sep}startapp={urllib.parse.quote(startapp)}"


def verify_webapp_init_data(init_data: str, bot_token: str, *, max_age_seconds: int = 86400) -> dict | None:
    """Verifies Telegram Mini App `initData` HMAC-SHA256 per official Bot API spec."""
    if not init_data or not bot_token:
        return None
    pairs = urllib.parse.parse_qsl(init_data, keep_blank_values=True)
    data = dict(pairs)
    received_hash = data.pop("hash", "")
    if not received_hash:
        return None

    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(data.items()))
    secret_key = hmac.new(b"WebAppData", bot_token.encode("utf-8"), hashlib.sha256).digest()
    expected_hash = hmac.new(secret_key, data_check_string.encode("utf-8"), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected_hash, received_hash):
        return None

    try:
        auth_date = int(data.get("auth_date", "0"))
    except ValueError:
        return None
    now_ts = int(timezone.now().timestamp())
    if auth_date <= 0 or abs(now_ts - auth_date) > max_age_seconds:
        return None

    user_raw = data.get("user")
    if user_raw:
        try:
            data["user_obj"] = json.loads(user_raw)
        except ValueError:
            return None
    return data


def current_lunar_window(now: datetime | None = None) -> tuple[str, str] | None:
    """Returns `(event_key, kind)` when `now` is within ±18h of New or Full Moon."""
    ts = (now or timezone.now()).astimezone(dt_timezone.utc)
    elapsed_days = (ts - _REF_NEW_MOON).total_seconds() / 86400.0
    cycle_num = int(elapsed_days // _SYNODIC_DAYS)
    age_days = elapsed_days % _SYNODIC_DAYS
    window_days = _LUNAR_WINDOW_HOURS / 24.0

    if age_days <= window_days:
        return f"new-{cycle_num}", "new_moon"
    if (_SYNODIC_DAYS - age_days) <= window_days:
        return f"new-{cycle_num + 1}", "new_moon"
    if abs(age_days - (_SYNODIC_DAYS / 2.0)) <= window_days:
        return f"full-{cycle_num}", "full_moon"
    return None


def send_telegram_message(
    chat_id: int,
    text: str,
    *,
    button_text: str | None = None,
    webapp_url: str | None = None,
) -> bool:
    token = (settings.TELEGRAM_BOT_TOKEN or "").strip()
    if not token:
        logger.debug("telegram_bot: TELEGRAM_BOT_TOKEN not configured; skipping send to %s", chat_id)
        return False

    payload: dict = {
        "chat_id": chat_id,
        "text": text,
        "disable_web_page_preview": True,
    }
    if button_text and webapp_url:
        payload["reply_markup"] = {
            "inline_keyboard": [[{"text": button_text, "web_app": {"url": webapp_url}}]]
        }

    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return 200 <= resp.status < 300
    except (urllib.error.URLError, OSError) as exc:
        logger.warning("telegram_bot: sendMessage failed for chat %s: %s", chat_id, exc)
        return False


def _copy(lang: str, key: str, **kwargs) -> str:
    ru = {
        "welcome": (
            "Добро пожаловать в Tarot Tree — ваше тихое пространство для Таро, Рун, Ленорман и Астрала.\n\n"
            "Команды напоминаний:\n"
            "• /daily — вкл/выкл ежедневную «Карту дня»\n"
            "• /lunar — вкл/выкл окна Новолуния и Полнолуния\n"
            "• /checkin 7 Тема расклада — напомнить проверить сбываемость через 3 / 7 / 14 дней\n"
            "• /stop — отключить все напоминания"
        ),
        "open_app": "Открыть Tarot Tree",
        "open_daily": "Вытянуть карту дня",
        "open_lunar": "Открыть лунный расклад",
        "open_checkin": "Проверить расклад",
        "daily_on": "Напоминания о «Карте дня» включены.",
        "daily_off": "Напоминания о «Карте дня» поставлены на паузу.",
        "lunar_on": "Напоминания об окнах Новолуния и Полнолуния включены.",
        "lunar_off": "Лунные напоминания отключены.",
        "stopped": "Все напоминания отключены. Чтобы вернуться, нажмите /start.",
        "checkin_saved": "Напомню проверить расклад «{title}» через {days} дн.",
        "push_daily": "Утренний якорь готов — вытяните вашу Карту дня за 30 секунд.",
        "push_new_moon": "Окно Новолуния открыто — хорошее время для расклада «Посев намерения».",
        "push_full_moon": "Окно Полнолуния открыто — посмотрите, что проявилось, в раскладе «Свет и отпускание».",
        "push_checkin": "Прошло время вашего расклада «{title}». Загляните в дневник и отметьте, как он отыгрался.",
    }
    en = {
        "welcome": (
            "Welcome to Tarot Tree — your quiet space for Tarot, Runes, Lenormand, and Astral insights.\n\n"
            "Reminder commands:\n"
            "• /daily — toggle Daily Card reminders\n"
            "• /lunar — toggle New & Full Moon ritual alerts\n"
            "• /checkin 7 Spread topic — schedule a 3 / 7 / 14-day reality check-in\n"
            "• /stop — pause all reminders"
        ),
        "open_app": "Open Tarot Tree",
        "open_daily": "Draw Daily Card",
        "open_lunar": "Open Lunar Spread",
        "open_checkin": "Review Spread",
        "daily_on": "Daily Card reminders are ON.",
        "daily_off": "Daily Card reminders are paused.",
        "lunar_on": "New & Full Moon ritual alerts are ON.",
        "lunar_off": "Lunar alerts are paused.",
        "stopped": "All reminders are paused. Send /start anytime to resume.",
        "checkin_saved": "I will remind you to check in on \"{title}\" in {days} days.",
        "push_daily": "Your morning anchor is ready — draw today's card in 30 seconds.",
        "push_new_moon": "The New Moon window is open — try the Seed of Intention spread.",
        "push_full_moon": "The Full Moon window is open — reflect with the Light & Release spread.",
        "push_checkin": "Time to revisit your spread \"{title}\" and note how it unfolded.",
    }
    table = ru if lang == "ru" else en
    return table[key].format(**kwargs)


def handle_bot_update(update: dict, *, sender=send_telegram_message) -> dict:
    """Processes one incoming Telegram Bot API update payload."""
    message = update.get("message") or update.get("edited_message")
    if not isinstance(message, dict):
        return {"handled": False}
    chat = message.get("chat") or {}
    chat_id = chat.get("id")
    if not isinstance(chat_id, int):
        return {"handled": False}

    user = message.get("from") or {}
    lang = _norm_lang(user.get("language_code"))
    text = (message.get("text") or "").strip()
    cmd = text.split()[0].split("@")[0].lower() if text else ""

    sub, _ = TelegramSubscriber.objects.get_or_create(
        chat_id=chat_id,
        defaults={"language_code": lang},
    )
    if sub.language_code != lang:
        sub.language_code = lang
        sub.save(update_fields=["language_code", "updated_at"])

    if cmd == "/stop":
        sub.active = False
        sub.save(update_fields=["active", "updated_at"])
        sender(chat_id, _copy(lang, "stopped"))
        return {"handled": True, "action": "stopped"}

    if cmd == "/daily":
        sub.active = True
        sub.daily_card_enabled = not sub.daily_card_enabled
        sub.save(update_fields=["active", "daily_card_enabled", "updated_at"])
        key = "daily_on" if sub.daily_card_enabled else "daily_off"
        sender(chat_id, _copy(lang, key), button_text=_copy(lang, "open_daily"), webapp_url=_miniapp_url("daily"))
        return {"handled": True, "action": key}

    if cmd == "/lunar":
        sub.active = True
        sub.lunar_enabled = not sub.lunar_enabled
        sub.save(update_fields=["active", "lunar_enabled", "updated_at"])
        key = "lunar_on" if sub.lunar_enabled else "lunar_off"
        sender(chat_id, _copy(lang, key), button_text=_copy(lang, "open_lunar"), webapp_url=_miniapp_url("lunar"))
        return {"handled": True, "action": key}

    if cmd == "/checkin":
        sub.active = True
        sub.save(update_fields=["active", "updated_at"])
        parts = text.split(maxsplit=2)
        days = 7
        title = "Tarot Spread" if lang == "en" else "Расклад Таро"
        if len(parts) >= 2 and parts[1].isdigit():
            parsed_days = int(parts[1])
            days = parsed_days if parsed_days in {3, 7, 14} else 7
            if len(parts) == 3 and parts[2].strip():
                title = parts[2].strip()[:140]
        elif len(parts) >= 2:
            title = text[len(parts[0]):].strip()[:140] or title
        TelegramCheckInReminder.objects.create(
            subscriber=sub,
            spread_title=title,
            due_at=timezone.now() + timedelta(days=days),
        )
        sender(
            chat_id,
            _copy(lang, "checkin_saved", title=title, days=days),
            button_text=_copy(lang, "open_checkin"),
            webapp_url=_miniapp_url("checkin"),
        )
        return {"handled": True, "action": "checkin_scheduled", "days": days}

    # Default / /start
    if not sub.active:
        sub.active = True
        sub.save(update_fields=["active", "updated_at"])
    sender(
        chat_id,
        _copy(lang, "welcome"),
        button_text=_copy(lang, "open_app"),
        webapp_url=_miniapp_url("table"),
    )
    return {"handled": True, "action": "welcome"}


def dispatch_due_reminders(*, now: datetime | None = None, sender=send_telegram_message) -> dict:
    """Cron-safe idempotent dispatcher for check-in, daily card, and lunar alerts."""
    ts = (now or timezone.now()).astimezone(dt_timezone.utc)
    today = ts.date()
    counts = {"checkins": 0, "daily": 0, "lunar": 0}

    # 1. Zeigarnik spread check-ins
    due_checkins = (
        TelegramCheckInReminder.objects
        .select_related("subscriber")
        .filter(sent_at__isnull=True, due_at__lte=ts, subscriber__active=True)
    )
    for item in due_checkins:
        lang = _norm_lang(item.subscriber.language_code)
        title = item.spread_title or ("Tarot Spread" if lang == "en" else "Расклад Таро")
        if sender(
            item.subscriber.chat_id,
            _copy(lang, "push_checkin", title=title),
            button_text=_copy(lang, "open_checkin"),
            webapp_url=_miniapp_url("checkin"),
        ):
            item.sent_at = ts
            item.save(update_fields=["sent_at"])
            counts["checkins"] += 1

    # 2. Daily Card reminders at subscriber's configured UTC hour
    due_daily = (
        TelegramSubscriber.objects
        .filter(active=True, daily_card_enabled=True, daily_hour_utc=ts.hour)
        .exclude(last_daily_sent_date=today)
    )
    for sub in due_daily:
        lang = _norm_lang(sub.language_code)
        if sender(
            sub.chat_id,
            _copy(lang, "push_daily"),
            button_text=_copy(lang, "open_daily"),
            webapp_url=_miniapp_url("daily"),
        ):
            sub.last_daily_sent_date = today
            sub.save(update_fields=["last_daily_sent_date", "updated_at"])
            counts["daily"] += 1

    # 3. Lunar windows (New Moon / Full Moon ±18h)
    lunar = current_lunar_window(ts)
    if lunar is not None:
        event_key, kind = lunar
        msg_key = "push_new_moon" if kind == "new_moon" else "push_full_moon"
        due_lunar = (
            TelegramSubscriber.objects
            .filter(active=True, lunar_enabled=True)
            .exclude(last_lunar_sent_key=event_key)
        )
        for sub in due_lunar:
            lang = _norm_lang(sub.language_code)
            if sender(
                sub.chat_id,
                _copy(lang, msg_key),
                button_text=_copy(lang, "open_lunar"),
                webapp_url=_miniapp_url("lunar"),
            ):
                sub.last_lunar_sent_key = event_key
                sub.save(update_fields=["last_lunar_sent_key", "updated_at"])
                counts["lunar"] += 1

    return counts
