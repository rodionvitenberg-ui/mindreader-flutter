from django.urls import path

from . import api

urlpatterns = [
    path("recognize/", api.recognize),
    path("recognize-batch/", api.recognize_batch),
    path("results/<uuid:request_id>/", api.result),
    path("confirm/", api.confirm),
]
