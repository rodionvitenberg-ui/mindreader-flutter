from django.contrib import admin

from .models import Recognition


@admin.register(Recognition)
class RecognitionAdmin(admin.ModelAdmin):
    list_display = ("id", "status", "provider", "decision", "created_at")
    list_filter = ("status", "provider", "decision")
    fields = ("id", "status", "provider", "decision", "created_at")
    readonly_fields = fields
    search_fields = ("id",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
