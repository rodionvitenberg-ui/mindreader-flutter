from django.urls import path

from . import api

urlpatterns = [
    path("scan-spread/", api.scan_spread),
    path("recognize/", api.recognize),
    path("recognize-batch/", api.recognize_batch),
    path("results/<uuid:request_id>/", api.result),
    path("confirm/", api.confirm),
]
