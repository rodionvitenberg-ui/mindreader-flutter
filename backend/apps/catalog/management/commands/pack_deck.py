from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.models import Deck
from apps.catalog.packages import PackageError, build_package_from_directory


class Command(BaseCommand):
    help = "Build and publish a validated DeckVersion package from a local folder of raw artwork."

    def add_arguments(self, parser):
        parser.add_argument("--slug", required=True, help="Existing Deck slug")
        parser.add_argument("--source", required=True, help="Directory with raw images")
        parser.add_argument("--version", default="1.0.0", help="Package semantic version")
        parser.add_argument("--min-app", default="0.0.0", help="Minimum app semantic version")
        parser.add_argument("--publish", action="store_true", help="Mark both version and deck published")

    def handle(self, *args, **options):
        deck = Deck.objects.filter(slug=options["slug"]).first()
        if deck is None:
            raise CommandError(f"Deck with slug '{options['slug']}' not found.")
        source = Path(options["source"])
        try:
            ver = build_package_from_directory(
                deck,
                options["version"],
                options["min_app"],
                source,
                published=options["publish"],
            )
        except PackageError as exc:
            raise CommandError(str(exc)) from None
        if options["publish"] and not deck.published:
            deck.published = True
            deck.full_clean()
            deck.save()
        self.stdout.write(
            self.style.SUCCESS(
                f"Packed {deck.slug} v{ver.version} ({ver.card_count} items, {ver.size_bytes} bytes, sha256={ver.sha256[:12]}…)"
            )
        )
