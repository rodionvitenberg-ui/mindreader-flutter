import uuid
from pathlib import PurePosixPath

from django.core.exceptions import ValidationError
from django.core.files.storage import FileSystemStorage, storages
from django.core.validators import RegexValidator
from django.db import models, transaction
from django.db.models import Q

from apps.core.cards import SYSTEM_SIZES

VERSION = r"^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\Z"

# Built-in decks and rune sets shipped inside the Flutter app so operators can
# attach promo artwork to them in Django Admin without uploading a ZIP package.
# Note: `soimoi` and `charred_birch` are store products, not built-in packs.
BUILTIN_PROMO_PACKS = (
    ("tarot", "rider_waite", "Rider-Waite"),
    ("tarot", "marseille", "Tarot de Marseille"),
    ("tarot", "oswald_wirth", "Oswald Wirth"),
    ("tarot", "etteilla", "Grand Etteilla"),
    ("tarot", "visconti_sforza", "Visconti-Sforza"),
    ("tarot", "vieville", "Jacques Viéville"),
    ("tarot", "obsidian_minimal", "Obsidian Minimal"),
    ("lenormand", "antique_petit", "Antique Petit Lenormand"),
    ("lenormand", "obsidian_gilded", "Obsidian Gilded Lenormand"),
    ("lenormand", "botanical_noir", "Botanical Noir Lenormand"),
    ("runes", "obsidian_lavender", "Obsidian & Lavender Quartz"),
    ("runes", "nordic_bone", "Nordic Carved Bone & Gold"),
    ("runes", "blood_jasper", "Blood Jasper & Runic Fire"),
    ("runes", "moss_agate", "Forest Moss Agate & Silver"),
)


class PrivateFileStorage(FileSystemStorage):
    def url(self, name):
        raise NotImplementedError("Private content has no direct URL.")


def package_storage():
    return storages["deck_packages"]


def promo_storage():
    return storages["default"]


def package_path(instance, filename):
    return str(PurePosixPath("decks", str(instance.deck_id), str(instance.pk), str(uuid.uuid4()) + ".zip"))


def promo_path(instance, filename):
    ext = PurePosixPath(filename).suffix.lower() or ".webp"
    return str(PurePosixPath("promos", instance.system, instance.pack_id, f"{uuid.uuid4()}{ext}"))


SYSTEM_DEFAULT_ITEM_TYPE = {
    "tarot": "tarot_deck",
    "lenormand": "lenormand_deck",
    "runes": "rune_set",
}


class Deck(models.Model):
    class ItemType(models.TextChoices):
        TAROT_DECK = "tarot_deck", "Tarot deck"
        LENORMAND_DECK = "lenormand_deck", "Lenormand deck"
        RUNE_SET = "rune_set", "Rune set"
        CARD_BACK = "card_back", "Card back"
        TABLE_THEME = "table_theme", "Table theme"
        SPREAD_PACK = "spread_pack", "Spread pack"
        BUNDLE = "bundle", "Bundle"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField(max_length=80, unique=True)
    title = models.CharField(max_length=180)
    tagline = models.CharField(max_length=200, blank=True)
    description = models.TextField()
    system = models.CharField(max_length=10, choices=[(system, system.title()) for system in SYSTEM_SIZES])
    item_type = models.CharField(max_length=24, choices=ItemType.choices, blank=True, default="")
    badge = models.CharField(max_length=32, blank=True)
    featured = models.BooleanField(default=False)
    sort_order = models.IntegerField(default=100)
    visual_config = models.JSONField(default=dict, blank=True)
    artist = models.CharField(max_length=180, blank=True)
    publisher = models.CharField(max_length=180, blank=True)
    license = models.TextField()
    attribution = models.TextField(blank=True)
    distribution_verified = models.BooleanField(default=False)
    commercial_rights = models.BooleanField(default=False)
    price_minor = models.PositiveIntegerField(default=0)
    currency = models.CharField(max_length=3, default="USD", validators=[RegexValidator(r"^[A-Z]{3}\Z")])
    published = models.BooleanField(default=False)

    class Meta:
        ordering = ("-featured", "sort_order", "title", "id")
        constraints = [
            models.CheckConstraint(
                condition=Q(published=False) | (Q(distribution_verified=True) & (Q(price_minor=0) | Q(commercial_rights=True))),
                name="published_deck_requires_rights",
            )
        ]

    def __str__(self):
        return self.title

    @property
    def resolved_item_type(self):
        return self.item_type or SYSTEM_DEFAULT_ITEM_TYPE.get(self.system, self.ItemType.TAROT_DECK)

    def save(self, *args, **kwargs):
        if not self.item_type:
            self.item_type = SYSTEM_DEFAULT_ITEM_TYPE.get(self.system, self.ItemType.TAROT_DECK)
        super().save(*args, **kwargs)

    def clean(self):
        if not self.item_type:
            self.item_type = SYSTEM_DEFAULT_ITEM_TYPE.get(self.system, self.ItemType.TAROT_DECK)
        if self.visual_config is None:
            self.visual_config = {}
        if not isinstance(self.visual_config, dict):
            raise ValidationError({"visual_config": "Visual config must be a JSON object."})
        if self.published and (
            not self.distribution_verified or (self.price_minor > 0 and not self.commercial_rights)
        ):
            raise ValidationError("Verify distribution rights and commercial rights for paid decks.")
        if self.published and (not self.pk or not self.versions.filter(published=True).exists()):
            raise ValidationError("Publish a validated deck version before listing the product.")
        if self.versions.exists():
            old = Deck.objects.filter(pk=self.pk).values("slug", "system").first()
            if old and (old["slug"] != self.slug or old["system"] != self.system):
                raise ValidationError("The slug and system are fixed once a version exists.")


class DeckVersion(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    deck = models.ForeignKey(Deck, on_delete=models.CASCADE, related_name="versions")
    version = models.CharField(max_length=24, validators=[RegexValidator(VERSION)])
    min_app_version = models.CharField(max_length=24, default="0.0.0", validators=[RegexValidator(VERSION)])
    incomplete = models.BooleanField(default=False)
    package = models.FileField(upload_to=package_path, storage=package_storage, blank=True)
    sha256 = models.CharField(max_length=64, editable=False, blank=True)
    size_bytes = models.PositiveBigIntegerField(default=0, editable=False)
    card_count = models.PositiveSmallIntegerField(default=0, editable=False)
    published = models.BooleanField(default=False)

    class Meta:
        constraints = [models.UniqueConstraint(fields=("deck", "version"), name="unique_deck_version")]

    def __str__(self):
        return f"{self.deck} {self.version}"

    def clean(self):
        from .packages import PackageError, inspect_package

        if self.published and not self.package:
            raise ValidationError({"package": "Upload a validated deck package."})
        if self.package:
            try:
                self._inspection = inspect_package(self, self.package)
            except PackageError as exc:
                raise ValidationError({"package": str(exc)}) from None


class DeckAsset(models.Model):
    version = models.ForeignKey(DeckVersion, on_delete=models.CASCADE, related_name="assets")
    path = models.CharField(max_length=150)
    kind = models.CharField(max_length=8, choices=[
        ("cover", "Cover"), ("preview", "Preview"), ("card", "Card"), ("back", "Back"), ("stone", "Stone"),
    ])
    card_id = models.CharField(max_length=20, blank=True)
    sha256 = models.CharField(max_length=64)

    class Meta:
        ordering = ("kind", "path")
        constraints = [
            models.UniqueConstraint(fields=("version", "path"), name="unique_deck_asset_path"),
            models.UniqueConstraint(fields=("version", "card_id"), condition=~Q(card_id=""), name="unique_deck_card_asset"),
        ]


class DeckPromo(models.Model):
    """Backend-managed promo artwork for a built-in pack or digital shop Deck."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    deck = models.OneToOneField(Deck, on_delete=models.CASCADE, null=True, blank=True, related_name="promo")
    system = models.CharField(max_length=10, choices=[(system, system.title()) for system in SYSTEM_SIZES])
    pack_id = models.SlugField(max_length=80)
    title = models.CharField(max_length=180, blank=True)
    image = models.FileField(upload_to=promo_path, storage=promo_storage, blank=True)
    sha256 = models.CharField(max_length=64, editable=False, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("system", "pack_id")
        constraints = [
            models.UniqueConstraint(fields=("system", "pack_id"), name="unique_deck_promo_pack"),
        ]

    def __str__(self):
        label = self.title or self.pack_id
        return f"{label} ({self.system})"

    def _sync_from_deck(self):
        if self.deck_id:
            self.system = self.deck.system
            self.pack_id = self.deck.slug
            if not self.title:
                self.title = self.deck.title

    def clean_fields(self, exclude=None):
        self._sync_from_deck()
        super().clean_fields(exclude=exclude)

    def clean(self):
        from .packages import PackageError, validate_promo_image

        self._sync_from_deck()
        if self.image and not self.image._committed:
            try:
                self._validated_sha256 = validate_promo_image(self.image)
            except PackageError as exc:
                raise ValidationError({"image": str(exc)}) from None

    def save(self, *args, **kwargs):
        from .packages import PackageError, validate_promo_image

        self._sync_from_deck()
        old = DeckPromo.objects.filter(pk=self.pk).only("image").first() if self.pk else None
        old_name = old.image.name if old and old.image else ""
        if self.image:
            if not self.image._committed:
                try:
                    self.sha256 = getattr(self, "_validated_sha256", None) or validate_promo_image(self.image)
                except PackageError as exc:
                    raise ValidationError({"image": str(exc)}) from None
            elif not self.sha256:
                try:
                    with self.image.open("rb") as file:
                        self.sha256 = validate_promo_image(file)
                except (FileNotFoundError, PackageError):
                    pass
        else:
            self.sha256 = ""
        super().save(*args, **kwargs)
        new_name = self.image.name if self.image else ""
        if old_name and old_name != new_name:
            storage = self.image.storage
            transaction.on_commit(lambda: storage.delete(old_name))
