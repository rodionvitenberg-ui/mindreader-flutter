import uuid
from pathlib import PurePosixPath

from django.core.exceptions import ValidationError
from django.core.files.storage import FileSystemStorage, storages
from django.core.validators import RegexValidator
from django.db import models
from django.db.models import Q

from apps.core.cards import SYSTEM_SIZES

VERSION = r"^(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\.(0|[1-9]\d{0,5})\Z"


class PrivateFileStorage(FileSystemStorage):
    def url(self, name):
        raise NotImplementedError("Private content has no direct URL.")


def package_storage():
    return storages["deck_packages"]


def package_path(instance, filename):
    return str(PurePosixPath("decks", str(instance.deck_id), str(instance.pk), str(uuid.uuid4()) + ".zip"))


class Deck(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField(max_length=80, unique=True)
    title = models.CharField(max_length=180)
    description = models.TextField()
    system = models.CharField(max_length=10, choices=[(system, system.title()) for system in SYSTEM_SIZES])
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
        ordering = ("title", "id")
        constraints = [
            models.CheckConstraint(
                condition=Q(published=False) | (Q(distribution_verified=True) & (Q(price_minor=0) | Q(commercial_rights=True))),
                name="published_deck_requires_rights",
            )
        ]

    def __str__(self):
        return self.title

    def clean(self):
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
        ("cover", "Cover"), ("preview", "Preview"), ("card", "Card"), ("back", "Back"),
    ])
    card_id = models.CharField(max_length=20, blank=True)
    sha256 = models.CharField(max_length=64)

    class Meta:
        ordering = ("kind", "path")
        constraints = [
            models.UniqueConstraint(fields=("version", "path"), name="unique_deck_asset_path"),
            models.UniqueConstraint(fields=("version", "card_id"), condition=~Q(card_id=""), name="unique_deck_card_asset"),
        ]
