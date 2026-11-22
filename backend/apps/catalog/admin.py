from django import forms
from django.contrib import admin

from .models import Deck, DeckAsset, DeckPromo, DeckVersion
from .packages import save_validated_version


class DeckPromoInline(admin.StackedInline):
    model = DeckPromo
    fields = ("image", "sha256", "updated_at")
    readonly_fields = ("sha256", "updated_at")
    extra = 0
    max_num = 1


@admin.register(Deck)
class DeckAdmin(admin.ModelAdmin):
    inlines = (DeckPromoInline,)
    list_display = ("title", "system", "price_minor", "currency", "published", "has_promo")
    list_filter = ("published", "system")
    search_fields = ("slug", "title", "artist")
    prepopulated_fields = {"slug": ("title",)}
    readonly_fields = ("id",)

    @admin.display(boolean=True, description="Promo image")
    def has_promo(self, obj):
        promo = getattr(obj, "promo", None)
        return bool(promo and promo.image)

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(DeckPromo)
class DeckPromoAdmin(admin.ModelAdmin):
    list_display = ("pack_id", "title", "system", "deck", "has_image", "updated_at")
    list_filter = ("system",)
    search_fields = ("pack_id", "title", "deck__slug", "deck__title")
    readonly_fields = ("id", "sha256", "updated_at")

    @admin.display(boolean=True, description="Has image")
    def has_image(self, obj):
        return bool(obj.image)


class VersionForm(forms.ModelForm):
    class Meta:
        model = DeckVersion
        fields = "__all__"
        widgets = {"package": forms.FileInput}


class AssetInline(admin.TabularInline):
    model = DeckAsset
    fields = ("kind", "card_id", "path", "sha256")
    readonly_fields = fields
    max_num = 0
    can_delete = False

    def has_add_permission(self, request, obj):
        return False


@admin.register(DeckVersion)
class DeckVersionAdmin(admin.ModelAdmin):
    form = VersionForm
    inlines = (AssetInline,)
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
