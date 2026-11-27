from django.urls import path

from . import api

urlpatterns = [
    path("webhook/", api.webhook),
    path("checkin/", api.schedule_checkin),
]
