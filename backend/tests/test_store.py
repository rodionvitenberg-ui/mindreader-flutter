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

from apps.catalog.models import Deck, DeckPromo, DeckVersion
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

    def test_builtin_and_shop_deck_promo_images(self):
        buf = io.BytesIO()
        Image.new("RGB", (120, 60), color=(24, 32, 64)).save(buf, "WEBP")
        promo_file = SimpleUploadedFile("promo.webp", buf.getvalue(), content_type="image/webp")

        # Built-in deck/rune packs are pre-seeded by migration 0002.
        builtin = DeckPromo.objects.get(system="tarot", pack_id="rider_waite")
        builtin.image = promo_file
        builtin.full_clean()
        builtin.save()

        # Draft shop deck promo stays hidden until published.
        shop_deck = deck_fixture(slug="celestial-shop")
        shop_buf = io.BytesIO()
        Image.new("RGB", (120, 60), color=(90, 40, 110)).save(shop_buf, "PNG")
        shop_promo = DeckPromo(
            deck=shop_deck,
            image=SimpleUploadedFile("shop.png", shop_buf.getvalue(), content_type="image/png"),
        )
        shop_promo.full_clean()
        shop_promo.save()

        anonymous = APIClient()
        before = anonymous.get("/api/v1/store/promos/").json()
        self.assertEqual(before["count"], 1)
        self.assertEqual(before["results"][0]["packId"], "rider_waite")
        self.assertEqual(
            anonymous.get(before["results"][0]["url"]).headers["Content-Type"],
            "image/webp",
        )
        self.assertEqual(
            anonymous.get("/api/v1/store/promos/lenormand/celestial-shop/image/").status_code,
            404,
        )

        # Publish shop deck -> promo image appears in both /store/promos/ and /store/decks/.
        self.publish(shop_deck)
        after = anonymous.get("/api/v1/store/promos/?system=lenormand").json()
        self.assertEqual(after["count"], 1)
        self.assertEqual(after["results"][0]["packId"], "celestial-shop")
        self.assertEqual(after["results"][0]["deckId"], str(shop_deck.pk))
        self.assertEqual(
            anonymous.get(after["results"][0]["url"]).headers["Content-Type"],
            "image/png",
        )
        listing = anonymous.get("/api/v1/store/decks/?system=lenormand").json()
        self.assertEqual(listing["results"][0]["promoImageUrl"], after["results"][0]["url"])

    def test_seed_test_store_handoff_and_guest_gift_migration(self):
        from django.core.management import call_command

        call_command("seed_test_store")
        anonymous = APIClient()
        catalog = anonymous.get("/api/v1/store/decks/").json()
        slugs = [item["slug"] for item in catalog["results"]]
        self.assertEqual(slugs, ["soimoi", "charred_birch"])
        # Built-in decks are never listed in the store.
        self.assertNotIn("rider_waite", slugs)
        self.assertNotIn("nordic_bone", slugs)

        soimoi = next(i for i in catalog["results"] if i["slug"] == "soimoi")
        birch = next(i for i in catalog["results"] if i["slug"] == "charred_birch")
        self.assertFalse(soimoi["free"])
        self.assertEqual(soimoi["priceMinor"], 499)
        self.assertTrue(soimoi["featured"])
        self.assertIsNotNone(soimoi["coverUrl"])
        self.assertEqual(soimoi["version"]["cardCount"], 78)

        self.assertTrue(birch["free"])
        self.assertEqual(birch["priceMinor"], 0)
        self.assertEqual(birch["itemType"], "rune_set")
        self.assertEqual(birch["version"]["cardCount"], 24)
        self.assertIsNotNone(birch["coverUrl"])
        self.assertEqual(anonymous.get(birch["coverUrl"]).status_code, 200)

        # Guest claims the free wooden runes gift.
        guest_client = guest()
        self.assertEqual(
            guest_client.post(
                f"/api/v1/store/decks/{birch['id']}/acquire-free/",
                HTTP_IDEMPOTENCY_KEY="gift-1",
            ).status_code,
            200,
        )
        guest_catalog = guest_client.get("/api/v1/store/decks/").json()
        birch_after = next(i for i in guest_catalog["results"] if i["slug"] == "charred_birch")
        self.assertTrue(birch_after["owned"])

        # Guest upgrades to a verified email account -> free gift migrates automatically.
        with override_settings(EMAIL_VERIFICATION_ENABLED=True, AUTH_DEV_SHOW_CODE=True):
            start = guest_client.post(
                "/api/v1/auth/email/start/",
                {"email": "reader@example.org"},
                format="json",
            )
            self.assertEqual(start.status_code, 202)
            code = start.json()["devCode"]
            verify = guest_client.post(
                "/api/v1/auth/email/verify/",
                {"token": code},
                format="json",
            )
            self.assertEqual(verify.status_code, 200)
            verified_data = verify.json()
            self.assertTrue(verified_data["verified"])
            self.assertEqual(verified_data["email"], "reader@example.org")

        verified_client = APIClient()
        verified_client.credentials(HTTP_AUTHORIZATION=f"Bearer {verified_data['token']}")
        lib = verified_client.get("/api/v1/store/library/").json()
        self.assertEqual([i["slug"] for i in lib["results"]], ["charred_birch"])

        # One-time handoff from Flutter app to promo website.
        handoff = verified_client.post("/api/v1/auth/handoff/")
        self.assertEqual(handoff.status_code, 201)
        handoff_code = handoff.json()["code"]
        exchanged = anonymous.post("/api/v1/auth/handoff/exchange/", {"code": handoff_code}, format="json")
        self.assertEqual(exchanged.status_code, 200)
        self.assertEqual(exchanged.json()["email"], "reader@example.org")
        # Replay must fail.
        self.assertEqual(
            anonymous.post("/api/v1/auth/handoff/exchange/", {"code": handoff_code}, format="json").status_code,
            400,
        )
