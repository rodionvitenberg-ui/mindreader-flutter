import hashlib
import json
import re
from pathlib import PurePosixPath
from zipfile import BadZipFile, ZipFile

from django.db import transaction
from PIL import Image, UnidentifiedImageError

from apps.core.cards import CARDS, SYSTEM_SIZES

MAX_PACKAGE_BYTES = 100 * 1024 * 1024
MAX_EXPANDED_BYTES = 200 * 1024 * 1024
MAX_ASSET_BYTES = 8 * 1024 * 1024
MANIFEST = "deck_manifest.json"
MIME = {"jpg": "image/jpeg", "png": "image/png", "webp": "image/webp"}
IMAGE_FORMAT = {"jpg": "JPEG", "png": "PNG", "webp": "WEBP"}
FILE = r"[A-Za-z0-9_-]{1,100}\.(jpg|png|webp)"


class PackageError(ValueError):
    pass


def checksum(file):
    file.seek(0)
    digest = hashlib.sha256()
    while block := file.read(1024 * 1024):
        digest.update(block)
    file.seek(0)
    return digest.hexdigest()


def asset_data(path, kind, manifest_value, card_id=""):
    pattern = {"cover": r"cover\.webp", "preview": rf"previews/{FILE}",
               "card": rf"cards/{FILE}", "back": r"back\.(jpg|png|webp)"}[kind]
    if not isinstance(path, str) or not re.fullmatch(pattern, path):
        raise PackageError("Invalid asset path.")
    sha = manifest_value.get("sha256")
    if not isinstance(sha, str) or not re.fullmatch("[a-f0-9]{64}", sha):
        raise PackageError("Every asset requires a SHA-256 checksum.")
    return {"path": path, "kind": kind, "card_id": card_id, "sha256": sha}


def manifest_assets(version, data):
    deck = version.deck
    expected = {"schemaVersion": 1, "deckId": str(deck.pk), "system": deck.system,
                "version": version.version, "minAppVersion": version.min_app_version, "incomplete": version.incomplete}
    if not isinstance(data, dict) or any(data.get(k) != v for k, v in expected.items()):
        raise PackageError("Manifest header does not match the catalog version.")
    cards = data.get("cards")
    previews = data.get("previews")
    if not isinstance(cards, dict) or not cards or not isinstance(previews, list) or len(previews) > 12:
        raise PackageError("Supply the card map and at most twelve previews.")
    if any(key not in CARDS or key.split(":")[0] != deck.system for key in cards):
        raise PackageError("Invalid canonical card IDs.")
    size = SYSTEM_SIZES[deck.system]
    if (len(cards) < size) != version.incomplete:
        raise PackageError("Manifest completeness must match the canonical system size.")
    groups = [(data.get("cover"), "cover", "")]
    groups.extend((value, "preview", "") for value in previews)
    groups.extend((value, "card", key) for key, value in cards.items())
    if "back" in data:
        groups.append((data["back"], "back", ""))
    if any(not isinstance(value, dict) for value, _, _ in groups):
        raise PackageError("Each asset must be an object.")
    return [asset_data(value.get("path"), kind, value, key) for value, kind, key in groups], len(cards)


def inspect_package(version, file):
    if file.size > MAX_PACKAGE_BYTES:
        raise PackageError("The package exceeds 100 MiB.")
    try:
        file.seek(0)
        with ZipFile(file) as archive:
            infos = archive.infolist()
            if len(infos) > 100 or sum(info.file_size for info in infos) > MAX_EXPANDED_BYTES:
                raise PackageError("Package exceeds the expanded size or entry limit.")
            entries = {info.filename: info for info in infos}
            directories = {"cards/", "previews/"}
            manifest = entries.get(MANIFEST)
            if len(entries) != len(infos) or manifest is None or manifest.file_size > 128 * 1024:
                raise PackageError("Missing manifest, duplicate ZIP paths or oversized manifest.")
            data = json.loads(archive.read(MANIFEST), object_pairs_hook=no_duplicate_keys)
            assets, card_count = manifest_assets(version, data)
            paths = {asset["path"] for asset in assets}
            if len(paths) != len(assets) or set(entries) - directories != {MANIFEST, *paths}:
                raise PackageError("The ZIP must contain exactly the declared assets.")
            if any(name in entries and entries[name].file_size for name in directories):
                raise PackageError("ZIP directory entries must be empty.")
            for asset in assets:
                validate_asset(archive, entries[asset["path"]], asset)
        return assets, card_count, checksum(file), file.size
    except PackageError:
        raise
    except (BadZipFile, OSError, ValueError, RuntimeError, RecursionError, NotImplementedError, EOFError, KeyError):
        raise PackageError("Invalid ZIP package or manifest.") from None
    finally:
        file.seek(0)


def no_duplicate_keys(pairs):
    result = dict(pairs)
    if len(result) != len(pairs):
        raise PackageError("Duplicate JSON keys in manifest.")
    return result


def validate_asset(archive, info, asset):
    if not 0 < info.file_size <= MAX_ASSET_BYTES:
        raise PackageError("Each image must be at most 8 MiB.")
    data = archive.read(info)
    if hashlib.sha256(data).hexdigest() != asset["sha256"]:
        raise PackageError("Asset checksum mismatch.")
    from io import BytesIO

    image_format = IMAGE_FORMAT[PurePosixPath(asset["path"]).suffix[1:]]
    try:
        with Image.open(BytesIO(data), formats=[image_format]) as image:
            if not (1 <= image.width <= 4096 and 1 <= image.height <= 4096) or getattr(image, "is_animated", False):
                raise PackageError("Invalid image dimensions or animation.")
            image.load()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise PackageError("Invalid asset image.") from None


@transaction.atomic
def save_validated_version(version):
    from .models import DeckAsset, DeckVersion

    old = DeckVersion.objects.select_for_update().filter(pk=version.pk).first()
    if old and old.published:
        raise PackageError("Published versions are immutable.")
    version.full_clean()
    if version.package:
        assets, version.card_count, version.sha256, version.size_bytes = version._inspection
    else:
        assets, version.card_count, version.sha256, version.size_bytes = [], 0, "", 0
    version.save()
    version.assets.all().delete()
    DeckAsset.objects.bulk_create([DeckAsset(version=version, **item) for item in assets])
    if old and old.package and old.package.name != version.package.name:
        storage, name = old.package.storage, old.package.name
        transaction.on_commit(lambda: storage.delete(name))
