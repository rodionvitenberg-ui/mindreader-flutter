from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from apps.accounts import api as accounts
from apps.core import api as core

urlpatterns = [
    path("api/v1/oracle/", include("apps.oracle.urls")),
    path("api/v1/vision/", include("apps.vision.urls")),
    path("api/v1/store/", include("apps.store.urls")),
    path("api/v1/payments/", include("apps.payments.urls")),
    path("admin/", admin.site.urls),
    path("api/v1/health/", core.health),
    path("api/v1/config/public/", core.public_config),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/v1/docs/", SpectacularSwaggerView.as_view(url_name="schema")),
    path("api/v1/auth/guest/", accounts.guest),
    path("api/v1/auth/email/start/", accounts.email_start),
    path("api/v1/auth/email/verify/", accounts.email_verify),
    path("api/v1/auth/logout/", accounts.logout),
    path("api/v1/account/me/", accounts.me),
]
