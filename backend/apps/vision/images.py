import io

from PIL import Image, ImageOps, UnidentifiedImageError
from rest_framework import serializers

MAX_IMAGE_BYTES = 4 * 1024 * 1024
MAX_BATCH_BYTES = 20 * 1024 * 1024
MIME = {"JPEG": "image/jpeg", "PNG": "image/png", "WEBP": "image/webp"}


def normalize_image(upload, rotation):
    if upload.size > MAX_IMAGE_BYTES:
        raise serializers.ValidationError({"images": "Each image must be at most 4 MiB."})
    try:
        with Image.open(upload, formats=list(MIME)) as image:
            expected_mime = MIME[image.format]
            if (
                upload.content_type not in {expected_mime, "application/octet-stream", None, ""}
                or getattr(image, "is_animated", False)
            ):
                raise ValueError
            if not (32 <= image.width <= 4096 and 32 <= image.height <= 4096):
                raise ValueError
            image.load()
            pixels = ImageOps.exif_transpose(image) if rotation == 0 else image.rotate(-rotation, expand=True)
            pixels.thumbnail((1536, 1536))
            pixels = pixels.convert("RGB")
            output = io.BytesIO()
            pixels.save(output, format="JPEG", quality=87, exif=b"")
            return output.getvalue()
    except (UnidentifiedImageError, Image.DecompressionBombError, OSError, ValueError, KeyError):
        raise serializers.ValidationError({"images": "Invalid JPEG, PNG, or WebP image."}) from None
