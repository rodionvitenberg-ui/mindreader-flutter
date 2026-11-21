from django import forms
from django.contrib import admin

from .models import Deck, DeckVersion
from .packages import save_validated_version


@admin.register(Deck)
class DeckAdmin(admin.ModelAdmin):
    list_display = ("title", "system", "price_minor", "currency", "published")
    list_filter = ("published", "system")
    search_fields = ("slug", "title", "artist")
    prepopulated_fields = {"slug": ("title",)}
    readonly_fields = ("id",)

    def has_delete_permission(self, request, obj=None):
        return False


class VersionForm(forms.ModelForm):
    class Meta:
        model = DeckVersion
        fields = "__all__"
        widgets = {"package": forms.FileInput}


@admin.register(DeckVersion)
class DeckVersionAdmin(admin.ModelAdmin):
    form = VersionForm
    list_display = ("deck", "version", "min_app_version", "incomplete", "published", "card_count")
    list_filter = ("published", "incomplete")
    readonly_fields = ("id", "sha256", "size_bytes", "card_count")

    def get_readonly_fields(self, request, obj=None):
        if obj and obj.published:
            return (*self.readonly_fields, "deck", "version", "min_app_version", "incomplete", "published")
        return self.readonly_fields

    def get_exclude(self, request, obj=None):
        return ("package",) if obj and obj.published else None

    def has_change_permission(self, request, obj=None):
        return (obj is None or not obj.published) and super().has_change_permission(request, obj)

    def has_delete_permission(self, request, obj=None):
        return False

    def save_model(self, request, obj, form, change):
        save_validated_version(obj)
