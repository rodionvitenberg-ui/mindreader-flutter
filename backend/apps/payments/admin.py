from django.contrib import admin

from .models import Event, Order, ProLedgerEntry, ProOrder, ProReceipt


class LedgerAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Order)
class OrderAdmin(LedgerAdmin):
    list_display = ("id", "deck", "provider", "status", "price_minor", "currency", "updated_at")
    list_filter = ("provider", "status")
    search_fields = ("id", "provider_reference")
    exclude = ("checkout_url",)


@admin.register(Event)
class EventAdmin(LedgerAdmin):
    list_display = ("event_id", "order", "provider", "status", "applied", "received_at")
    search_fields = ("event_id", "order__id")
    list_filter = ("provider", "status", "applied")


@admin.register(ProOrder)
class ProOrderAdmin(LedgerAdmin):
    list_display = ("id", "email", "plan", "asset", "amount_display", "status", "created_at")
    list_filter = ("plan", "asset", "status", "provider")
    search_fields = ("id", "email", "solana_tx_signature", "reference_memo")


@admin.register(ProReceipt)
class ProReceiptAdmin(LedgerAdmin):
    list_display = (
        "receipt_number",
        "email",
        "plan",
        "early_supporter_slot",
        "amount_display",
        "user_email_sent_at",
        "owner_notified_at",
        "created_at",
    )
    list_filter = ("plan", "asset")
    search_fields = ("receipt_number", "email", "tx_signature")


@admin.register(ProLedgerEntry)
class ProLedgerEntryAdmin(LedgerAdmin):
    list_display = ("event_type", "email", "receipt", "created_at")
    list_filter = ("event_type",)
    search_fields = ("email", "receipt__receipt_number")
