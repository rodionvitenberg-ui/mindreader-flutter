from django.contrib import admin

from .models import TelegramCheckInReminder, TelegramSubscriber


@admin.register(TelegramSubscriber)
class TelegramSubscriberAdmin(admin.ModelAdmin):
    list_display = (
        "chat_id",
        "language_code",
        "active",
        "daily_card_enabled",
        "daily_hour_utc",
        "lunar_enabled",
        "last_daily_sent_date",
    )
    list_filter = ("active", "daily_card_enabled", "lunar_enabled", "language_code")
    search_fields = ("chat_id",)


@admin.register(TelegramCheckInReminder)
class TelegramCheckInReminderAdmin(admin.ModelAdmin):
    list_display = ("subscriber", "spread_title", "due_at", "sent_at")
    list_filter = ("sent_at",)
    search_fields = ("spread_title", "subscriber__chat_id")
