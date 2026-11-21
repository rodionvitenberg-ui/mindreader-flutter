import re
from pathlib import PurePosixPath
from zipfile import BadZipFile, ZipFile

from django.db import transaction
from django.db.models import Prefetch
from django.http import FileResponse, HttpResponse
from django.shortcuts import get_object_or_404
from django.urls import reverse
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import generics, serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.catalog.models import VERSION, Deck, DeckAsset, DeckVersion
from apps.catalog.packages import MIME
from apps.core.api import Problem, checked, finish, operation, replay
from apps.core.cards import SYSTEM_SIZES
from apps.entitlements.models import Grant, active_grants
from apps.oracle.api import IDEMPOTENCY


class Filters(serializers.Serializer):
    system = serializers.ChoiceField(SYSTEM_SIZES, required=False)
    pricing = serializers.ChoiceField(("free", "paid"), required=False)


class VersionFilter(serializers.Serializer):
    appVersion = serializers.RegexField(VERSION, required=False)
    version = serializers.RegexField(VERSION, required=False)


class VersionInfo(serializers.Serializer):
    version = serializers.CharField()
    minAppVersion = serializers.CharField()
    incomplete = serializers.BooleanField()
    cardCount = serializers.IntegerField()
    sizeBytes = serializers.IntegerField()
    sha256 = serializers.CharField()


class DeckInfo(serializers.Serializer):
    id = serializers.UUIDField()
    slug = serializers.SlugField()
    title = serializers.CharField()
    description = serializers.CharField()
    system = serializers.CharField()
    artist = serializers.CharField()
    publisher = serializers.CharField()
    license = serializers.CharField()
    attribution = serializers.CharField()
    commercialRights = serializers.BooleanField()
    free = serializers.BooleanField()
    priceMinor = serializers.IntegerField()
    currency = serializers.CharField()
    published = serializers.BooleanField()
    version = VersionInfo(allow_null=True)


class AssetInfo(serializers.Serializer):
    kind = serializers.ChoiceField(("cover", "preview"))
    url = serializers.CharField()


class DeckDetail(DeckInfo):
    versions = VersionInfo(many=True)
    previews = AssetInfo(many=True)


class Ownership(serializers.Serializer):
    owned = serializers.BooleanField()


class DownloadInfo(VersionInfo):
    url = serializers.CharField()


def versions_by_release(versions):
    return sorted(versions, key=lambda item: version_number(item.version), reverse=True)


def version_number(version):
    return tuple(map(int, version.split(".")))


def version_data(version):
    return {
        "version": version.version, "minAppVersion": version.min_app_version, "incomplete": version.incomplete,
        "cardCount": version.card_count, "sizeBytes": version.size_bytes, "sha256": version.sha256,
    }


def deck_data(deck, *, details=False):
    versions = versions_by_release(deck.released_versions)
    result = {
        "id": str(deck.pk), "slug": deck.slug, "title": deck.title, "description": deck.description,
        "system": deck.system, "artist": deck.artist, "publisher": deck.publisher, "license": deck.license,
        "attribution": deck.attribution, "commercialRights": deck.commercial_rights, "free": deck.price_minor == 0,
        "priceMinor": deck.price_minor, "currency": deck.currency, "published": deck.published,
        "version": version_data(versions[0]) if versions else None,
    }
    if details:
        result.update(versions=[version_data(v) for v in versions], previews=[
            {"kind": asset.kind, "url": reverse("deck-preview", args=[asset.pk])}
            for asset in versions[0].assets.filter(kind__in=["cover", "preview"])
        ] if versions else [])
    return result


def with_versions(queryset):
    versions = DeckVersion.objects.filter(published=True)
    return queryset.prefetch_related(Prefetch("versions", queryset=versions, to_attr="released_versions"))


class Decks(generics.GenericAPIView):
    permission_classes = [AllowAny]
    serializer_class = DeckInfo

    @extend_schema(parameters=[Filters], responses=DeckInfo(many=True))
    def get(self, request):
        filters = checked(Filters, request.query_params)
        decks = Deck.objects.filter(published=True)
        if "system" in filters:
            decks = decks.filter(system=filters["system"])
        if filters.get("pricing") == "free":
            decks = decks.filter(price_minor=0)
        elif filters.get("pricing") == "paid":
            decks = decks.filter(price_minor__gt=0)
        page = self.paginate_queryset(with_versions(decks))
        return self.get_paginated_response([deck_data(deck) for deck in page])


class Library(generics.GenericAPIView):
    serializer_class = DeckInfo

    @extend_schema(responses=DeckInfo(many=True))
    def get(self, request):
        grants = active_grants(request.auth.principal).values("deck_id")
        page = self.paginate_queryset(with_versions(Deck.objects.filter(id__in=grants)))
        return self.get_paginated_response([deck_data(deck) for deck in page])


@extend_schema(responses=DeckDetail)
@api_view(["GET"])
@permission_classes([AllowAny])
def detail(request, slug):
    return Response(deck_data(get_object_or_404(with_versions(Deck.objects.filter(published=True)), slug=slug), details=True))


@extend_schema(responses=OpenApiTypes.BINARY)
@api_view(["GET"])
@permission_classes([AllowAny])
def preview(request, asset_id):
    asset = get_object_or_404(
        DeckAsset.objects.select_related("version"),
        pk=asset_id, kind__in=["cover", "preview"], version__published=True, version__deck__published=True,
    )
    try:
        with asset.version.package.open("rb") as file, ZipFile(file) as archive:
            data = archive.read(asset.path)
    except (FileNotFoundError, BadZipFile, KeyError):
        raise Problem("asset_unavailable", 503, "Preview is unavailable.") from None
    response = HttpResponse(data, content_type=MIME[PurePosixPath(asset.path).suffix[1:]])
    response["Cache-Control"] = "public, max-age=300"
    return response


@extend_schema(responses=Ownership)
@api_view(["GET"])
def ownership(request, deck_id):
    grants = active_grants(request.auth.principal).filter(deck_id=deck_id)
    if not Deck.objects.filter(pk=deck_id, published=True).exists() and not grants.exists():
        raise Problem("not_found", 404, "Deck could not be found.")
    return Response({"owned": grants.exists()})


@extend_schema(request=None, responses=Ownership, parameters=[IDEMPOTENCY])
@api_view(["POST"])
def acquire(request, deck_id):
    with transaction.atomic():
        deck = get_object_or_404(Deck.objects.select_for_update(), pk=deck_id, published=True)
        op, fresh = operation(request, f"free:{deck_id}", {})
        if not fresh:
            return replay(op)
        if deck.price_minor != 0:
            raise Problem("payment_required", 403, "This deck is paid.")
        Grant.objects.get_or_create(
            deck=deck, owner=request.auth.principal, source=Grant.Source.FREE, revoked_at__isnull=True,
        )
        return finish(op, {"owned": True})


def authorized_versions(request, deck_id):
    if not active_grants(request.auth.principal).filter(deck_id=deck_id).exists():
        raise Problem("deck_access_denied", 403, "Acquire this deck before downloading.")
    return DeckVersion.objects.filter(deck_id=deck_id, published=True, deck__distribution_verified=True).exclude(package="")


@extend_schema(responses=DownloadInfo, parameters=[VersionFilter])
@api_view(["GET"])
def download(request, deck_id):
    filters = checked(VersionFilter, request.query_params)
    versions = authorized_versions(request, deck_id)
    if "version" in filters:
        versions = versions.filter(version=filters["version"])
    candidates = versions_by_release(versions)
    if "appVersion" in filters:
        app = version_number(filters["appVersion"])
        candidates = [v for v in candidates if version_number(v.min_app_version) <= app]
    if not candidates:
        raise Problem("compatible_version_unavailable", 404, "No compatible deck package is available.")
    version = candidates[0]
    return Response(dict(version_data(version), url=reverse("deck-package", args=[deck_id, version.version])))


@extend_schema(responses=OpenApiTypes.BINARY)
@api_view(["GET"])
def package(request, deck_id, version):
    release = get_object_or_404(authorized_versions(request, deck_id), version=version)
    try:
        file = release.package.open("rb")
    except FileNotFoundError:
        raise Problem("asset_unavailable", 503, "Deck package is unavailable.") from None
    response = FileResponse(file, as_attachment=True, filename=f"{deck_id}-{version}.zip", content_type="application/zip")
    response["Cache-Control"] = "private, no-store"
    return response
