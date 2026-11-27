from django.contrib import admin
from django.utils import timezone

from .models import AccessToken, Principal


@admin.register(Principal)
class PrincipalAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "verified_email",
        "is_pro",
        "pro_plan",
        "early_supporter_slot",
        "pro_expires_at",
        "created_at",
    )
    list_filter = ("is_pro", "pro_plan")
    search_fields = ("id", "verified_email", "display_name")
    readonly_fields = ("id", "user", "verified_email", "early_supporter_slot", "pro_since", "created_at")

    def has_add_permission(self, request):
        return False


@admin.register(AccessToken)
class AccessTokenAdmin(admin.ModelAdmin):
    list_display = ("principal", "expires_at", "revoked_at")
    fields = readonly_fields = ("principal", "created_at", "expires_at", "revoked_at")
    actions = ["revoke"]

    def has_add_permission(self, request):
        return False

    @admin.action(description="Revoke selected access tokens", permissions=["change"])
    def revoke(self, request, queryset):
        queryset.filter(revoked_at__isnull=True).update(revoked_at=timezone.now())
