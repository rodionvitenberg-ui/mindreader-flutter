import hashlib
import io
import json
import re
from pathlib import Path, PurePosixPath
from zipfile import BadZipFile, ZIP_DEFLATED, ZipFile

from django.core.files.base import ContentFile
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
STONE_FILE = r"stone_[0-9]\.(jpg|png|webp)"


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
    pattern = {
        "cover": r"cover\.webp",
        "preview": rf"previews/{FILE}",
        "card": rf"cards/{FILE}",
        "back": r"back\.(jpg|png|webp)",
        "stone": rf"stones/{STONE_FILE}",
    }[kind]
    if not isinstance(path, str) or not re.fullmatch(pattern, path):
        raise PackageError("Invalid asset path.")
    sha = manifest_value.get("sha256")
    if not isinstance(sha, str) or not re.fullmatch("[a-f0-9]{64}", sha):
        raise PackageError("Every asset requires a SHA-256 checksum.")
    return {"path": path, "kind": kind, "card_id": card_id, "sha256": sha}


def manifest_assets(version, data):
    deck = version.deck
    expected = {
        "schemaVersion": 1,
        "deckId": str(deck.pk),
        "system": deck.system,
        "version": version.version,
        "minAppVersion": version.min_app_version,
        "incomplete": version.incomplete,
    }
    if not isinstance(data, dict) or any(data.get(k) != v for k, v in expected.items()):
        raise PackageError("Manifest header does not match the catalog version.")
    cards = data.get("cards")
    previews = data.get("previews")
    stones = data.get("stones", [])
    style = data.get("style")
    if style is not None and not isinstance(style, dict):
        raise PackageError("Manifest style must be an object.")
    if not isinstance(cards, dict) or not isinstance(previews, list) or len(previews) > 12:
        raise PackageError("Supply the card map and at most twelve previews.")
    if not isinstance(stones, list) or len(stones) > 10:
        raise PackageError("Supply at most ten blank stone sprites.")
    if stones and deck.system != "runes":
        raise PackageError("Blank stone sprites are only valid for rune sets.")
    if not cards and not stones:
        raise PackageError("Supply either card assets or blank rune stone sprites.")
    if any(key not in CARDS or key.split(":")[0] != deck.system for key in cards):
        raise PackageError("Invalid canonical card IDs.")
    size = SYSTEM_SIZES[deck.system]
    if stones and not cards:
        # Volumetric 3D rune sets render all 24 Elder Futhark glyphs procedurally
        # across the supplied blank stone sprites.
        if version.incomplete:
            raise PackageError("Stone-based rune sets cover all 24 runes and must not be marked incomplete.")
        card_count = size
    else:
        if (len(cards) < size) != version.incomplete:
            raise PackageError("Manifest completeness must match the canonical system size.")
        card_count = len(cards)
    groups = [(data.get("cover"), "cover", "")]
    groups.extend((value, "preview", "") for value in previews)
    groups.extend((value, "stone", "") for value in stones)
    groups.extend((value, "card", key) for key, value in cards.items())
    if "back" in data:
        groups.append((data["back"], "back", ""))
    if any(not isinstance(value, dict) for value, _, _ in groups):
        raise PackageError("Each asset must be an object.")
    return [asset_data(value.get("path"), kind, value, key) for value, kind, key in groups], card_count


def inspect_package(version, file):
    if file.size > MAX_PACKAGE_BYTES:
        raise PackageError("The package exceeds 100 MiB.")
    try:
        file.seek(0)
        with ZipFile(file) as archive:
            infos = archive.infolist()
            if len(infos) > 120 or sum(info.file_size for info in infos) > MAX_EXPANDED_BYTES:
                raise PackageError("Package exceeds the expanded size or entry limit.")
            entries = {info.filename: info for info in infos}
            directories = {"cards/", "previews/", "stones/"}
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
    image_format = IMAGE_FORMAT[PurePosixPath(asset["path"]).suffix[1:]]
    try:
        with Image.open(io.BytesIO(data), formats=[image_format]) as image:
            if not (1 <= image.width <= 4096 and 1 <= image.height <= 4096) or getattr(image, "is_animated", False):
                raise PackageError("Invalid image dimensions or animation.")
            image.load()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise PackageError("Invalid asset image.") from None


def validate_promo_image(file):
    if not file:
        return ""
    ext = PurePosixPath(file.name).suffix.lower().lstrip(".")
    if ext not in IMAGE_FORMAT:
        raise PackageError("Promo image must be a JPG, PNG, or WebP file.")
    if not 0 < file.size <= MAX_ASSET_BYTES:
        raise PackageError("Promo image must be at most 8 MiB.")
    file.seek(0)
    data = file.read()
    file.seek(0)
    try:
        with Image.open(io.BytesIO(data), formats=[IMAGE_FORMAT[ext]]) as image:
            if not (1 <= image.width <= 4096 and 1 <= image.height <= 4096) or getattr(image, "is_animated", False):
                raise PackageError("Invalid promo image dimensions or animation.")
            image.load()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise PackageError("Invalid promo image.") from None
    return hashlib.sha256(data).hexdigest()


def _to_webp_bytes(raw_bytes):
    try:
        with Image.open(io.BytesIO(raw_bytes)) as img:
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGBA")
            buf = io.BytesIO()
            img.save(buf, format="WEBP", quality=88)
            return buf.getvalue()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise PackageError("Could not convert cover image to WebP.") from None


def _normalize_ext(name):
    ext = PurePosixPath(name).suffix.lower().lstrip(".")
    if ext == "jpeg":
        return "jpg"
    return ext


def _canonical_card_key(system, stem):
    if not re.fullmatch(r"\d{1,3}", stem):
        return None
    idx = int(stem)
    if system == "lenormand":
        # Lenormand files are commonly named 01..36 (Rider..Cross), while canonical IDs are 0..35.
        if 1 <= idx <= 36:
            idx -= 1
    key = f"{system}:{idx}"
    return key if key in CARDS else None


def _collect_raw_files_from_zip(raw_zip_file):
    raw_zip_file.seek(0)
    files = {}
    with ZipFile(raw_zip_file) as archive:
        infos = [i for i in archive.infolist() if not i.is_dir()]
        if len(infos) > 150:
            raise PackageError("Raw archive has too many files.")
        # Strip a single common top-level directory (e.g. `soimoi/00.jpg` -> `00.jpg`).
        parts_list = [PurePosixPath(i.filename).parts for i in infos if not PurePosixPath(i.filename).name.startswith(".") and "__MACOSX" not in PurePosixPath(i.filename).parts]
        strip_root = None
        if parts_list and all(len(p) > 1 and p[0] == parts_list[0][0] for p in parts_list):
            strip_root = parts_list[0][0]
        for info in infos:
            p = PurePosixPath(info.filename)
            if p.name.startswith(".") or "__MACOSX" in p.parts:
                continue
            parts = p.parts[1:] if strip_root and p.parts[0] == strip_root else p.parts
            if not parts:
                continue
            rel = "/".join(parts)
            files[rel] = archive.read(info)
    return files


def _collect_raw_files_from_dir(source_dir):
    root = Path(source_dir)
    if not root.is_dir():
        raise PackageError(f"Source directory not found: {source_dir}")
    files = {}
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.name.startswith("."):
            continue
        rel = path.relative_to(root).as_posix()
        files[rel] = path.read_bytes()
    return files


def build_package_from_files(deck, version_str, min_app_version, raw_files, *, published=False):
    """Builds and validates a canonical DeckVersion ZIP from plain asset files.

    Accepted layouts inside raw_files:
    - Tarot: `00.jpg..77.jpg` (or inside `cards/`), optional `back.*`, `cover.*`, `previews/*`.
    - Lenormand: `01.jpg..36.jpg` (or `00..35`), optional `back.*`, `cover.*`, `previews/*`.
    - Runes: `stone_0.webp..stone_4.webp` (or inside `stones/`) OR `00..23.*` cards, optional `cover.*`, `previews/*`.
    """
    from .models import DeckVersion

    cards_bin = {}   # canonical_id -> (zip_path, bytes)
    stones_bin = []  # list of (zip_path, bytes) sorted by filename
    previews_bin = []
    back_bin = None
    cover_bytes = None

    for rel, data in sorted(raw_files.items()):
        p = PurePosixPath(rel)
        ext = _normalize_ext(p.name)
        if ext not in IMAGE_FORMAT:
            continue
        stem = p.stem
        lower_stem = stem.lower()
        parent = p.parts[0].lower() if len(p.parts) > 1 else ""

        if parent == "previews":
            safe_name = re.sub(r"[^A-Za-z0-9_-]", "_", stem)[:80] or f"preview_{len(previews_bin)}"
            previews_bin.append((f"previews/{safe_name}.{ext}", data))
        elif lower_stem == "cover":
            cover_bytes = _to_webp_bytes(data)
        elif lower_stem == "back":
            back_bin = (f"back.{ext}", data)
        elif deck.system == "runes" and re.fullmatch(r"stone_[0-9]", lower_stem):
            stones_bin.append((f"stones/{lower_stem}.{ext}", data))
        else:
            card_key = _canonical_card_key(deck.system, stem)
            if card_key is not None:
                idx = card_key.split(":")[1].zfill(2)
                cards_bin[card_key] = (f"cards/{idx}.{ext}", data)

    if not cards_bin and not stones_bin:
        raise PackageError(
            "No recognized card or rune stone images found. Use 00..77 for Tarot, 01..36 for Lenormand, or stone_0..4 for Runes."
        )

    # Auto-pick cover if none supplied.
    if cover_bytes is None:
        if f"{deck.system}:17" in cards_bin:
            cover_bytes = _to_webp_bytes(cards_bin[f"{deck.system}:17"][1])
        elif cards_bin:
            first_key = sorted(cards_bin.keys(), key=lambda k: int(k.split(":")[1]))[0]
            cover_bytes = _to_webp_bytes(cards_bin[first_key][1])
        else:
            cover_bytes = _to_webp_bytes(stones_bin[0][1])

    # Auto-pick up to 6 preview samples when explicit previews are absent.
    if not previews_bin:
        if deck.system == "tarot" and cards_bin:
            sample_ids = [0, 1, 17, 18, 19, 21]
            chosen = [f"tarot:{i}" for i in sample_ids if f"tarot:{i}" in cards_bin]
            if not chosen:
                chosen = sorted(cards_bin.keys(), key=lambda k: int(k.split(":")[1]))[:6]
            for idx, cid in enumerate(chosen):
                src_path, src_bytes = cards_bin[cid]
                ext = _normalize_ext(src_path)
                previews_bin.append((f"previews/sample_{idx}.{ext}", src_bytes))
        elif deck.system == "lenormand" and cards_bin:
            chosen = sorted(cards_bin.keys(), key=lambda k: int(k.split(":")[1]))[:6]
            for idx, cid in enumerate(chosen):
                src_path, src_bytes = cards_bin[cid]
                ext = _normalize_ext(src_path)
                previews_bin.append((f"previews/sample_{idx}.{ext}", src_bytes))
        elif stones_bin:
            for idx, (src_path, src_bytes) in enumerate(stones_bin[:5]):
                ext = _normalize_ext(src_path)
                previews_bin.append((f"previews/stone_{idx}.{ext}", src_bytes))

    previews_bin = previews_bin[:12]
    size = SYSTEM_SIZES[deck.system]
    incomplete = False if (stones_bin and not cards_bin) else (len(cards_bin) < size)

    manifest = {
        "schemaVersion": 1,
        "deckId": str(deck.pk),
        "system": deck.system,
        "version": version_str,
        "minAppVersion": min_app_version,
        "incomplete": incomplete,
        "cover": {"path": "cover.webp", "sha256": hashlib.sha256(cover_bytes).hexdigest()},
        "previews": [
            {"path": path, "sha256": hashlib.sha256(data).hexdigest()}
            for path, data in previews_bin
        ],
        "cards": {
            cid: {"path": path, "sha256": hashlib.sha256(data).hexdigest()}
            for cid, (path, data) in sorted(cards_bin.items(), key=lambda kv: int(kv[0].split(":")[1]))
        },
    }
    if stones_bin:
        manifest["stones"] = [
            {"path": path, "sha256": hashlib.sha256(data).hexdigest()}
            for path, data in sorted(stones_bin, key=lambda pair: pair[0])
        ]
    if back_bin is not None:
        manifest["back"] = {"path": back_bin[0], "sha256": hashlib.sha256(back_bin[1]).hexdigest()}
    if deck.visual_config:
        manifest["style"] = deck.visual_config

    buf = io.BytesIO()
    with ZipFile(buf, "w", compression=ZIP_DEFLATED) as archive:
        archive.writestr("cover.webp", cover_bytes)
        for path, data in previews_bin:
            archive.writestr(path, data)
        for path, data in stones_bin:
            archive.writestr(path, data)
        for _, (path, data) in sorted(cards_bin.items(), key=lambda kv: int(kv[0].split(":")[1])):
            archive.writestr(path, data)
        if back_bin is not None:
            archive.writestr(back_bin[0], back_bin[1])
        archive.writestr(MANIFEST, json.dumps(manifest, separators=(",", ":")))

    version_obj = DeckVersion(
        deck=deck,
        version=version_str,
        min_app_version=min_app_version,
        incomplete=incomplete,
        published=published,
    )
    version_obj.package = ContentFile(buf.getvalue(), name=f"{deck.slug}-{version_str}.zip")
    save_validated_version(version_obj)
    return version_obj


def build_package_from_raw_zip(deck, version_str, min_app_version, raw_zip_file, *, published=False):
    files = _collect_raw_files_from_zip(raw_zip_file)
    return build_package_from_files(deck, version_str, min_app_version, files, published=published)


def build_package_from_directory(deck, version_str, min_app_version, source_dir, *, published=False):
    files = _collect_raw_files_from_dir(source_dir)
    return build_package_from_files(deck, version_str, min_app_version, files, published=published)


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
