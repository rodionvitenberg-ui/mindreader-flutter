from django.contrib import admin, messages

from .models import Provider, RoutingPolicy, Usage
from .routing import probe


@admin.register(Provider)
class ProviderAdmin(admin.ModelAdmin):
    list_display = ("name", "capability", "model", "enabled", "priority", "is_paid", "health")
    list_filter = ("capability", "enabled", "is_paid", "health")
    readonly_fields = ("health", "health_checked_at")
    actions = ["check_health", "disable"]

    @admin.action(description="Check health of selected providers", permissions=["change"])
    def check_health(self, request, queryset):
        if queryset.count() > 5:
            self.message_user(request, "Select at most five providers.", messages.WARNING)
            return
        for provider in queryset:
            status = probe(provider)
            self.log_change(request, provider, f"Health check: {status}")

    @admin.action(description="Disable selected providers", permissions=["change"])
    def disable(self, request, queryset):
        for provider in queryset:
            Provider.objects.filter(pk=provider.pk).update(enabled=False)
            self.log_change(request, provider, "Provider disabled.")


@admin.register(RoutingPolicy)
class RoutingPolicyAdmin(admin.ModelAdmin):
    list_display = ("capability", "allow_paid_fallback")


@admin.register(Usage)
class UsageAdmin(admin.ModelAdmin):
    list_display = ("provider", "day", "count", "reserved_cost")
    readonly_fields = ("provider", "day", "count", "reserved_cost")

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
