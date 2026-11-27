from django.urls import path

from . import api

urlpatterns = [
    path("checkout/", api.checkout),
    path("orders/<uuid:order_id>/", api.order),
    path("webhooks/<slug:provider>/", api.webhook),
    path("pro/offer/", api.pro_offer),
    path("pro/checkout/", api.pro_checkout),
    path("pro/solana/verify/", api.pro_solana_verify),
    path("pro/dev/confirm/", api.pro_dev_confirm),
    path("pro/orders/<uuid:order_id>/", api.pro_order_detail),
]
