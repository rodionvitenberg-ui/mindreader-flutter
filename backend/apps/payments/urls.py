from django.urls import path

from . import api

urlpatterns = [
    path("checkout/", api.checkout),
    path("orders/<uuid:order_id>/", api.order),
    path("webhooks/<slug:provider>/", api.webhook),
]
