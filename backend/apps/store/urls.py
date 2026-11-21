from django.urls import path

from . import api

urlpatterns = [
    path("decks/", api.Decks.as_view()),
    path("library/", api.Library.as_view()),
    path("previews/<int:asset_id>/", api.preview, name="deck-preview"),
    path("decks/<uuid:deck_id>/ownership/", api.ownership),
    path("decks/<uuid:deck_id>/acquire-free/", api.acquire),
    path("decks/<uuid:deck_id>/download/", api.download),
    path("decks/<uuid:deck_id>/packages/<str:version>/", api.package, name="deck-package"),
    path("decks/<slug:slug>/", api.detail),
]
