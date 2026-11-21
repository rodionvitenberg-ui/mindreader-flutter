from django.contrib import admin

from .models import Event, Order


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
