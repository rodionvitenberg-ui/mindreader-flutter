from django.contrib import admin
from django.utils import timezone

from .models import Grant


@admin.register(Grant)
class GrantAdmin(admin.ModelAdmin):
    list_display = ("owner", "deck", "source", "granted_at", "revoked_at")
    list_filter = ("source",)
    list_select_related = ("owner", "deck", "order")
    actions = ["revoke"]
    fields = ("owner", "deck", "source", "reason", "order", "granted_by", "granted_at", "revoked_at")

    def get_readonly_fields(self, request, obj=None):
        return self.fields if obj else ("order", "granted_by", "granted_at", "revoked_at")

    def formfield_for_choice_field(self, db_field, request, **kwargs):
        if db_field.name == "source":
            kwargs["choices"] = [(Grant.Source.ADMIN, "Administrative"), (Grant.Source.PROMOTION, "Promotion")]
        return super().formfield_for_choice_field(db_field, request, **kwargs)

    def save_model(self, request, obj, form, change):
        obj.granted_by = request.user
        super().save_model(request, obj, form, change)

    def has_delete_permission(self, request, obj=None):
        return False

    @admin.action(description="Revoke selected manual, promo and free grants", permissions=["change"])
    def revoke(self, request, queryset):
        for grant in queryset.exclude(source=Grant.Source.PURCHASE).filter(revoked_at__isnull=True):
            Grant.objects.filter(pk=grant.pk, revoked_at__isnull=True).update(revoked_at=timezone.now())
            self.log_change(request, grant, "Entitlement revoked.")
