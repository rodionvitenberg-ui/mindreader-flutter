import hashlib
import io
import json
from tempfile import TemporaryDirectory
from zipfile import ZipFile

from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from PIL import Image
from rest_framework.test import APIClient

from apps.catalog.models import Deck, DeckVersion
from apps.catalog.packages import save_validated_version
from apps.entitlements.models import Grant

from .test_readings import guest


def deck_fixture(slug="test-lenormand", price=0):
    return Deck.objects.create(
        slug=slug, title=slug, system="lenormand", description="A test deck",
        artist="Artist", publisher="Publisher", license="Test license",
        distribution_verified=True, commercial_rights=True, price_minor=price,
    )


def package_fixture(deck, version="1.0.0", min_app="1.0.0", *, extras=None):
    item = DeckVersion(deck=deck, version=version, min_app_version=min_app, incomplete=True, published=True)
    img = io.BytesIO()
    Image.new("RGB", (64, 64)).save(img, "WEBP")
    pixels = img.getvalue()
    sha = hashlib.sha256(pixels).hexdigest()
    cover = {"path": "cover.webp", "sha256": sha}
    card = {"path": "cards/rider.webp", "sha256": sha}
    manifest = {
        "schemaVersion": 1, "deckId": str(deck.pk), "system": "lenormand",
        "version": version, "minAppVersion": min_app, "incomplete": True,
        "cover": cover, "previews": [], "cards": {"lenormand:0": card},
    }
    binary = io.BytesIO()
    with ZipFile(binary, "w") as archive:
        archive.writestr(cover["path"], pixels)
        archive.writestr(card["path"], pixels)
        archive.writestr("deck_manifest.json", json.dumps(manifest))
        for name, content in (extras or {}).items():
            archive.writestr(name, content)
    item.package = SimpleUploadedFile("deck.zip", binary.getvalue())
    return item


class StoreTests(TestCase):
    def setUp(self):
        root = self.enterContext(TemporaryDirectory())
        self.enterContext(override_settings(MEDIA_ROOT=root))
        self.client = guest()

    def publish(self, deck, **kwargs):
        release = package_fixture(deck, **kwargs)
        save_validated_version(release)
        deck.published = True
        deck.full_clean()
        deck.save()
        return release

    def test_public_catalog_preview_download_and_versions(self):
        deck = deck_fixture()
        self.publish(deck)
        self.publish(deck, version="1.10.0", min_app="2.0.0")
        deck_fixture("draft")
        anonymous = APIClient()
        catalog = anonymous.get("/api/v1/store/decks/?system=lenormand&pricing=free").json()
        self.assertEqual(catalog["count"], 1)
        details = anonymous.get(f"/api/v1/store/decks/{deck.slug}/").json()
        self.assertEqual(details["version"]["version"], "1.10.0")
        self.assertEqual(details["license"], "Test license")
        self.assertEqual(anonymous.get(details["previews"][0]["url"]).headers["Content-Type"], "image/webp")
        url = f"/api/v1/store/decks/{deck.pk}/"
        self.assertEqual(self.client.get(url + "download/").status_code, 403)
        for key in ("a", "a", "b"):
            self.assertEqual(self.client.post(url + "acquire-free/", HTTP_IDEMPOTENCY_KEY=key).status_code, 200)
        self.assertEqual(Grant.objects.count(), 1)
        self.assertEqual(self.client.get("/api/v1/store/library/").json()["count"], 1)
        result = self.client.get(url + "download/?appVersion=1.0.0").json()
        self.assertEqual(result["version"], "1.0.0")
        self.assertEqual(guest().get(result["url"]).status_code, 403)
        download = self.client.get(result["url"])
        self.assertEqual(hashlib.sha256(b"".join(download.streaming_content)).hexdigest(), result["sha256"])
        self.assertEqual(self.client.get(url + "download/?appVersion=invalid").status_code, 400)

    def test_rejects_zip_undeclared_paths_and_paid_free_grant(self):
        deck = deck_fixture(price=100)
        invalid = package_fixture(deck, extras={"../outside": b"bad"})
        with self.assertRaises(ValidationError):
            save_validated_version(invalid)
        self.publish(deck)
        self.assertEqual(self.client.post(f"/api/v1/store/decks/{deck.pk}/acquire-free/",
                                          HTTP_IDEMPOTENCY_KEY="try").status_code, 403)
        self.assertEqual(Grant.objects.count(), 0)
