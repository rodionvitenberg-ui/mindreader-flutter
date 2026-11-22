from django import forms
from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied, ValidationError
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import path, reverse

from .models import VERSION, Deck, DeckAsset, DeckPromo, DeckVersion
from .packages import PackageError, build_package_from_raw_zip, save_validated_version


class DeckPromoInline(admin.StackedInline):
    model = DeckPromo
    fields = ("image", "sha256", "updated_at")
    readonly_fields = ("sha256", "updated_at")
    extra = 0
    max_num = 1


class RawPackageUploadForm(forms.Form):
    version = forms.RegexField(
        regex=VERSION,
        initial="1.0.0",
        label="Version",
        help_text="Semantic version, e.g. 1.0.0",
    )
    min_app_version = forms.RegexField(
        regex=VERSION,
        initial="0.0.0",
        label="Minimum app version",
        help_text="Minimum Flutter app version required to install this package.",
    )
    raw_zip = forms.FileField(
        label="Raw images ZIP",
        help_text=(
            "Standard ZIP with images (no deck_manifest.json needed). "
            "Tarot: 00..77.(jpg|png|webp) + optional back.* / cover.* / previews/*. "
            "Lenormand: 01..36.(jpg|png|webp). "
            "Runes: stone_0..4.webp (3D blanks) or 00..23.(png|webp)."
        ),
    )
    published = forms.BooleanField(
        required=False,
        initial=True,
        label="Publish version immediately",
    )


@admin.register(Deck)
class DeckAdmin(admin.ModelAdmin):
    inlines = (DeckPromoInline,)
    list_display = (
        "title",
        "system",
        "item_type",
        "price_display",
        "featured",
        "sort_order",
        "published",
        "has_promo",
    )
    list_filter = ("published", "featured", "system", "item_type")
    search_fields = ("slug", "title", "tagline", "artist")
    prepopulated_fields = {"slug": ("title",)}
    readonly_fields = ("id",)
    fieldsets = (
        (
            "Product",
            {
                "fields": (
                    "id",
                    "title",
                    "slug",
                    "tagline",
                    "description",
                    "system",
                    "item_type",
                    "badge",
                    "featured",
                    "sort_order",
                )
            },
        ),
        (
            "Visual configuration",
            {
                "fields": ("visual_config",),
                "description": (
                    "Optional JSON palette/style embedded into built packages "
                    "(e.g. stoneBaseArgb, glyphArgb, glowArgb for 3D runes or backStyle / isIllustrated for decks)."
                ),
            },
        ),
        (
            "Credits & rights",
            {
                "fields": (
                    "artist",
                    "publisher",
                    "license",
                    "attribution",
                    "distribution_verified",
                    "commercial_rights",
                )
            },
        ),
        (
            "Pricing & listing",
            {
                "fields": ("price_minor", "currency", "published"),
            },
        ),
    )

    @admin.display(description="Price")
    def price_display(self, obj):
        if obj.price_minor == 0:
            return "FREE"
        return f"{obj.price_minor / 100:.2f} {obj.currency}"

    @admin.display(boolean=True, description="Promo image")
    def has_promo(self, obj):
        promo = getattr(obj, "promo", None)
        return bool(promo and promo.image)

    def has_delete_permission(self, request, obj=None):
        return False

    def get_urls(self):
        custom = [
            path(
                "<path:object_id>/upload-raw-package/",
                self.admin_site.admin_view(self.upload_raw_package_view),
                name="catalog_deck_upload_raw_package",
            ),
        ]
        return custom + super().get_urls()

    def upload_raw_package_view(self, request, object_id):
        if not self.has_change_permission(request):
            raise PermissionDenied
        deck = get_object_or_404(Deck, pk=object_id)
        if request.method == "POST":
            form = RawPackageUploadForm(request.POST, request.FILES)
            if form.is_valid():
                try:
                    ver = build_package_from_raw_zip(
                        deck,
                        form.cleaned_data["version"],
                        form.cleaned_data["min_app_version"],
                        form.cleaned_data["raw_zip"],
                        published=form.cleaned_data["published"],
                    )
                except (PackageError, ValidationError) as exc:
                    form.add_error("raw_zip", str(exc))
                else:
                    messages.success(
                        request,
                        f"Built and saved {deck.title} v{ver.version} ({ver.card_count} cards/runes, {ver.size_bytes} bytes).",
                    )
                    return redirect(reverse("admin:catalog_deckversion_change", args=[ver.pk]))
        else:
            form = RawPackageUploadForm()

        context = {
            **self.admin_site.each_context(request),
            "opts": self.model._meta,
            "deck": deck,
            "form": form,
            "title": f"Build & upload package for {deck.title}",
        }
        return render(request, "admin/catalog/deck/upload_raw_package.html", context)


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
