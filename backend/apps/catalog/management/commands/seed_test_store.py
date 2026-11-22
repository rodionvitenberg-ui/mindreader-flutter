from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.catalog.models import Deck
from apps.catalog.packages import build_package_from_directory


TEST_PRODUCTS = (
    {
        "slug": "soimoi",
        "title": "SOMOI Tarot",
        "tagline": "Japanese-style illustrated 78-card deck by Mike Koz",
        "description": (
            "A distinctive illustrated 78-card Tarot deck blending contemporary Japanese ink aesthetics "
            "with classical Rider-Waite symbolism, complete with a matching card back."
        ),
        "system": "tarot",
        "item_type": Deck.ItemType.TAROT_DECK,
        "badge": "FEATURED",
        "featured": True,
        "sort_order": 1,
        "artist": "Mike Koz",
        "publisher": "koz.tv",
        "license": "CC BY 4.0 · Mike Koz (koz.tv)",
        "attribution": "Artwork by Mike Koz (koz.tv), licensed under CC BY 4.0.",
        "price_minor": 499,
        "currency": "USD",
        "visual_config": {
            "backStyle": "cyber",
            "backAccentArgb": 0xFF7DD3FC,
            "backSecondaryArgb": 0xFFF472B6,
            "faceAccentArgb": 0xFF7DD3FC,
            "faceSecondaryArgb": 0xFFF472B6,
            "isIllustrated": True,
        },
        "source_rel": "tarot/soimoi",
    },
    {
        "slug": "charred_birch",
        "title": "Charred Nordic Birch & Frost",
        "tagline": "Scorched dark timber rune tokens with pale frost-blue engravings — Free Gift",
        "description": (
            "Hand-scorched northern birch tokens carved with pale frost-blue Elder Futhark glyphs. "
            "Claim this volumetric 3D rune set as a free welcome gift for your Digital Table and Almanac."
        ),
        "system": "runes",
        "item_type": Deck.ItemType.RUNE_SET,
        "badge": "GIFT",
        "featured": False,
        "sort_order": 10,
        "artist": "Tarot Tree Atelier",
        "publisher": "Tarot Tree",
        "license": "Tarot Tree Digital Edition",
        "attribution": "Original volumetric timber rune set by Tarot Tree.",
        "price_minor": 0,
        "currency": "USD",
        "visual_config": {
            "stoneBaseArgb": 0xFF3A2B22,
            "stoneDarkArgb": 0xFF140D09,
            "stoneRimArgb": 0xFF7DD3FC,
            "glyphArgb": 0xFFE0F2FE,
            "glowArgb": 0xFF38BDF8,
            "specularArgb": 0xFFEFF8FF,
            "carveShadowArgb": 0xDF070402,
            "stoneVariantCount": 5,
        },
        "source_rel": "runes/charred_birch",
    },
)


class Command(BaseCommand):
    help = "Seed and publish the two test store items: SOMOI Tarot (paid) and Charred Birch Wooden Runes (free gift)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--assets-root",
            default=str(Path(settings.BASE_DIR) / "store_seed_assets"),
            help="Root directory containing tarot/soimoi and runes/charred_birch folders.",
        )

    def handle(self, *args, **options):
        root = Path(options["assets_root"])
        if not root.is_dir():
            raise CommandError(f"Seed assets directory does not exist: {root}")

        for spec in TEST_PRODUCTS:
            source_dir = root / spec["source_rel"]
            if not source_dir.is_dir():
                raise CommandError(f"Missing seed asset folder: {source_dir}")

            deck, created = Deck.objects.update_or_create(
                slug=spec["slug"],
                defaults={
                    "title": spec["title"],
                    "tagline": spec["tagline"],
                    "description": spec["description"],
                    "system": spec["system"],
                    "item_type": spec["item_type"],
                    "badge": spec["badge"],
                    "featured": spec["featured"],
                    "sort_order": spec["sort_order"],
                    "artist": spec["artist"],
                    "publisher": spec["publisher"],
                    "license": spec["license"],
                    "attribution": spec["attribution"],
                    "price_minor": spec["price_minor"],
                    "currency": spec["currency"],
                    "visual_config": spec["visual_config"],
                    "distribution_verified": True,
                    "commercial_rights": True,
                },
            )
            if not deck.versions.filter(published=True).exists():
                build_package_from_directory(
                    deck,
                    "1.0.0",
                    "0.0.0",
                    source_dir,
                    published=True,
                )
            if not deck.published:
                deck.published = True
                deck.full_clean()
                deck.save()

            action = "Created" if created else "Updated"
            price_label = "FREE GIFT" if deck.price_minor == 0 else f"${deck.price_minor / 100:.2f} {deck.currency}"
            self.stdout.write(self.style.SUCCESS(f"{action} & published {deck.title} ({deck.slug}) — {price_label}"))
